# Damage Size Calculation

This document explains how the app converts 2D bounding boxes from AI damage detection into real-world measurements using LiDAR depth data.

## Overview

When Gemini detects damage in an image, it returns a normalized bounding box (0.0-1.0). The `DamageSizeCalculator` converts this to real-world dimensions (meters) using the **pinhole camera model** and **LiDAR depth data**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Size Calculation Pipeline                            │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │ Gemini       │    │ Coordinate   │    │ Depth        │    │ Pinhole   │ │
│  │ Bounding Box │ →  │ Mapping      │ →  │ Sampling     │ →  │ Camera    │ │
│  │ (0.0-1.0)    │    │ (pixels)     │    │ (meters)     │    │ Model     │ │
│  └──────────────┘    └──────────────┘    └──────────────┘    └───────────┘ │
│                                                                      │      │
│                                                                      ▼      │
│                                                          ┌───────────────┐  │
│                                                          │ Real-World    │  │
│                                                          │ Dimensions    │  │
│                                                          │ (meters)      │  │
│                                                          └───────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Required Input Data

The calculation requires data from a `CapturedFrame`:

| Data | Source | Description |
|------|--------|-------------|
| Bounding Box | Gemini API | Normalized coordinates (x, y, width, height) in range 0.0-1.0 |
| Depth Buffer | LiDAR/ARKit | Float32 array with distance values in meters |
| Camera Intrinsics | ARFrame | 3x3 matrix containing focal lengths |
| Image Dimensions | Captured image | Width and height in pixels |
| Depth Dimensions | Depth buffer | Width and height of depth map |

---

## Step 1: Coordinate Mapping

Convert normalized bounding box to pixel coordinates, then map to depth buffer coordinates.

```swift
// Normalized bbox (0-1) → Pixel coordinates
let pixelX = boundingBox.x * Float(imageWidth)
let pixelY = boundingBox.y * Float(imageHeight)
let pixelW = boundingBox.width * Float(imageWidth)
let pixelH = boundingBox.height * Float(imageHeight)

// Find center of bounding box
let centerPixelX = pixelX + pixelW / 2.0
let centerPixelY = pixelY + pixelH / 2.0

// Map to depth buffer coordinates (different resolution)
let scaleX = Float(depthWidth) / Float(imageWidth)
let scaleY = Float(depthHeight) / Float(imageHeight)
let depthCenterX = Int(centerPixelX * scaleX)
let depthCenterY = Int(centerPixelY * scaleY)
```

**Why mapping is needed:** The depth buffer from LiDAR typically has a different resolution than the captured image (e.g., 256×192 vs 1920×1440).

---

## Step 2: Depth Sampling

Instead of using a single depth value (which can be noisy), sample a 3×3 grid around the center and use the **median** value.

```
┌─────────────────────────────────────┐
│                                     │
│         Bounding Box                │
│    ┌─────────────────────┐          │
│    │                     │          │
│    │   ┌───┬───┬───┐     │          │
│    │   │ • │ • │ • │     │          │
│    │   ├───┼───┼───┤     │          │
│    │   │ • │ ✕ │ • │ ← Center       │
│    │   ├───┼───┼───┤     │          │
│    │   │ • │ • │ • │     │          │
│    │   └───┴───┴───┘     │          │
│    │     3×3 sample      │          │
│    │        grid         │          │
│    └─────────────────────┘          │
│                                     │
└─────────────────────────────────────┘
```

```swift
// Sample 3×3 grid around center
for dy in -1...1 {
    for dx in -1...1 {
        let x = centerX + dx
        let y = centerY + dy
        let depthValue = depthBuffer[y * width + x]

        // Filter invalid values
        if depthValue.isFinite && depthValue >= 0.1 && depthValue <= 5.0 {
            validSamples.append(depthValue)
        }
    }
}

// Use median for robustness against outliers
let sorted = validSamples.sorted()
let depth = sorted[sorted.count / 2]
```

**Valid depth range:** 0.1m to 5.0m (LiDAR accuracy limits)

---

## Step 3: Pinhole Camera Model

The core mathematical formula that converts pixel dimensions to real-world meters.

### The Math

```
                    Focal Length (f)
                         │
    Real Object    ◄─────┼─────►    Image Plane
         │               │               │
         │               │               │
         W               │               p (pixels)
         │               │               │
         │               │               │
         ◄───── d ───────┼───────────────┤
              (depth)    │
                    Camera
```

**Relationship:** An object of real width `W` at distance `d` projects to `p` pixels:

```
p = f × W / d
```

**Solving for real width:**

```
W = d × p / f
```

### Implementation

```swift
// Extract focal lengths from camera intrinsics matrix
// intrinsics[0][0] = fx (focal length in X direction, in pixels)
// intrinsics[1][1] = fy (focal length in Y direction, in pixels)
let fx = cameraIntrinsics[0][0]
let fy = cameraIntrinsics[1][1]

// Apply pinhole camera model
let realWidth = depth * pixelW / fx    // meters
let realHeight = depth * pixelH / fy   // meters
let realArea = realWidth * realHeight  // square meters
```

### Camera Intrinsics Matrix

The 3×3 intrinsics matrix from ARKit:

```
┌                    ┐
│  fx    0    cx     │
│   0   fy    cy     │
│   0    0     1     │
└                    ┘

Where:
  fx, fy = Focal lengths in pixels
  cx, cy = Principal point (image center)
```

---

## Step 4: Confidence Scoring

The measurement confidence is reduced based on conditions that affect accuracy:

| Condition | Confidence Multiplier | Reason |
|-----------|----------------------|--------|
| Distance > 3m | × 0.8 | LiDAR less accurate at range |
| Distance 2-3m | × 0.9 | Slightly reduced accuracy |
| Bbox area < 1% | × 0.7 | Small objects harder to measure |
| Bbox area < 5% | × 0.85 | Reduced precision |
| Bbox area > 50% | × 0.8 | May span multiple depth planes |

```swift
func calculateConfidence(depth: Float, bboxWidth: Float, bboxHeight: Float) -> Float {
    var confidence: Float = 1.0

    // Distance penalties
    if depth > 3.0 { confidence *= 0.8 }
    else if depth > 2.0 { confidence *= 0.9 }

    // Size penalties
    let bboxArea = bboxWidth * bboxHeight
    if bboxArea < 0.01 { confidence *= 0.7 }
    else if bboxArea < 0.05 { confidence *= 0.85 }
    else if bboxArea > 0.5 { confidence *= 0.8 }

    return confidence
}
```

---

## Fallback: Surface-Based Estimation

When depth data is unavailable, size can be estimated using known surface dimensions from RoomPlan:

```swift
func calculateSizeFromSurface(
    boundingBox: DamageBoundingBox,
    surfaceWidth: Float,   // Known wall width from RoomPlan
    surfaceHeight: Float   // Known wall height from RoomPlan
) -> DamageRealDimensions {
    let realWidth = boundingBox.width * surfaceWidth
    let realHeight = boundingBox.height * surfaceHeight

    return DamageRealDimensions(
        width: realWidth,
        height: realHeight,
        area: realWidth * realHeight,
        depth: 0,           // Unknown
        confidence: 0.7     // Lower confidence
    )
}
```

**Assumption:** The damage is flat against the known surface.

---

## Output: DamageRealDimensions

```swift
struct DamageRealDimensions {
    let width: Float       // meters
    let height: Float      // meters
    let area: Float        // square meters
    let depth: Float       // distance from camera in meters
    let confidence: Float  // 0.0-1.0

    // Formatted output helpers
    var formattedWidth: String      // "5.2 cm", "1.20 m"
    var formattedHeight: String     // "3.1 cm", "0.85 m"
    var formattedArea: String       // "16.1 cm²", "1.02 m²"
    var formattedDimensions: String // "5.2 cm × 3.1 cm"
}
```

### Unit Formatting Logic

| Value Range | Display Unit |
|-------------|--------------|
| < 1 cm | millimeters (mm) |
| 1 cm - 1 m | centimeters (cm) |
| > 1 m | meters (m) |

---

## Integration Point

Size calculation is called from `DamageAnalysisService.convertToDamageWithSize()`:

```swift
if let bbox = boundingBox,
   let frame = frame,
   frame.hasDepthData,
   let depthData = frame.depthData,
   let intrinsics = frame.cameraIntrinsics {

    if let dimensions = sizeCalculator.calculateSize(
        boundingBox: bbox,
        depthData: depthData,
        depthWidth: frame.depthWidth,
        depthHeight: frame.depthHeight,
        cameraIntrinsics: intrinsics,
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight
    ) {
        realWidth = dimensions.width
        realHeight = dimensions.height
        realArea = dimensions.area
        distanceFromCamera = dimensions.depth
        measurementConfidence = dimensions.confidence
    }
}
```

---

## Accuracy Considerations

### Optimal Conditions
- Distance: 0.5m - 2.0m from surface
- Damage covers 5-50% of frame
- Surface is perpendicular to camera
- Good lighting for depth sensor

### Limitations
- Reflective or transparent surfaces may have inaccurate depth
- Very small damage (< 1cm) may be below measurement precision
- Damage on curved surfaces assumes flat plane

---

## Related Files

| File | Purpose |
|------|---------|
| `Services/DamageDetection/DamageSizeCalculator.swift` | Size calculation implementation |
| `Services/DamageDetection/DamageAnalysisService.swift` | Orchestrates analysis and calls calculator |
| `Models/DamageModel.swift` | `DetectedDamage` struct with size fields |
| `Services/DamageDetection/CapturedFrame.swift` | Contains depth data and intrinsics |
