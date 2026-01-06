# Damage Detection with LiDAR Size Measurement

This document explains how the damage detection system works, including AI-powered damage identification and real-world size measurement using LiDAR depth data.

## Overview

The damage detection system combines:
1. **Gemini Vision AI** - Identifies damage types (cracks, water damage, mold, etc.) and provides bounding boxes
2. **LiDAR Depth Capture** - Captures depth maps during manual AR frame capture
3. **Size Calculation** - Converts 2D bounding boxes to real-world measurements using depth data and camera intrinsics
4. **Deduplication** - Removes duplicate detections across multiple frames using IoU (Intersection over Union)

## User Flow

```
┌─────────────────┐
│    Home View    │
└────────┬────────┘
         │ Start Scan
         ▼
┌─────────────────┐
│  Room Scan View │  ← RoomCaptureSession
└────────┬────────┘
         │ Complete Scan
         ▼
┌─────────────────┐
│ Dimensions View │  ← View room measurements
└────────┬────────┘
         │ "Analyze Damage" button
         ▼
┌─────────────────┐
│ Depth Capture   │  ← ARSession with LiDAR depth
│     View        │     User MANUALLY taps to capture frames
│                 │     (point at damage, tap capture button)
└────────┬────────┘
         │ "Done" (1-15 frames captured)
         ▼
┌─────────────────┐
│ Damage Analysis │  ← Review captures or select manual images
│     View        │     Start Gemini AI analysis
└────────┬────────┘
         │ Analysis Complete
         ▼
┌─────────────────┐
│ Damage Results  │  ← Filterable/sortable damage list
│     View        │     Filter by severity, surface type
└────────┬────────┘
         │ Tap damage item
         ▼
┌─────────────────┐
│ Damage Detail   │  ← Single damage deep-dive
│     View        │     Shows size, recommendations, confidence
└─────────────────┘
```

## Why Sequential Capture?

Running `RoomCaptureSession` and `ARSession` simultaneously causes camera resource conflicts:
- `FigCaptureSourceRemote err=-12784` - Camera already in use
- Both sessions fight for exclusive camera access

**Solution**: Sequential capture separates the two AR sessions:
1. Room scan uses `RoomCaptureSession` alone
2. Depth capture uses `ARSession` alone after scan completes

## Architecture

### Key Components

| Component | File | Purpose |
|-----------|------|---------|
| `ARFrameCaptureService` | `Services/DamageDetection/ARFrameCaptureService.swift` | Captures and stores frames with depth data |
| `DamageSizeCalculator` | `Services/DamageDetection/DamageSizeCalculator.swift` | Converts bounding boxes to real measurements using 3x3 median sampling |
| `GeminiService` | `Services/DamageDetection/GeminiService.swift` | AI damage detection via Gemini Vision API (`gemini-3-flash-preview`) |
| `DamageAnalysisService` | `Services/DamageDetection/DamageAnalysisService.swift` | Orchestrates analysis pipeline with deduplication |
| `ImageCaptureHelper` | `Services/DamageDetection/ImageCaptureHelper.swift` | Image compression and surface association |
| `GeminiConfig` | `Config/GeminiConfig.swift` | API key management (3-tier priority) |
| `DepthCaptureView` | `Views/DamageDetection/DepthCaptureView.swift` | UI for manual depth frame capture |
| `DamageAnalysisView` | `Views/DamageDetection/DamageAnalysisView.swift` | Review captures, start analysis |
| `DamageResultsView` | `Views/DamageDetection/DamageResultsView.swift` | Filterable/sortable results list |
| `DamageDetailView` | `Views/DamageDetection/DamageDetailView.swift` | Single damage detail view |
| `DamageComponents` | `Views/DamageDetection/DamageComponents.swift` | Reusable UI components (badges, cards) |

### Data Flow

```
                    ┌──────────────────┐
                    │   ARFrame        │
                    │  (from ARKit)    │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ ARFrameCapture   │
                    │    Service       │
                    │                  │
                    │ Extracts:        │
                    │ - RGB image      │
                    │ - Depth map      │
                    │ - Intrinsics     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  CapturedFrame   │
                    │                  │
                    │ - imageData      │
                    │ - depthData      │
                    │ - depthWidth/H   │
                    │ - intrinsics     │
                    │ - imageWidth/H   │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
     ┌────────────────┐           ┌────────────────┐
     │ GeminiService  │           │ DamageSize     │
     │                │           │ Calculator     │
     │ Input: image   │           │                │
     │ Output:        │           │ Input:         │
     │ - damage type  │           │ - bounding box │
     │ - severity     │           │ - depth data   │
     │ - bounding box │           │ - intrinsics   │
     │ - confidence   │           │                │
     └───────┬────────┘           │ Output:        │
             │                    │ - realWidth    │
             │                    │ - realHeight   │
             │                    │ - realArea     │
             └──────────┬─────────┘
                        │
                        ▼
               ┌────────────────┐
               │ Damage Analysis│
               │    Service     │
               │                │
               │ - Combines     │
               │ - Deduplicates │
               │ - Ranks        │
               └───────┬────────┘
                       │
                       ▼
               ┌────────────────┐
               │ DetectedDamage │
               │                │
               │ - type         │
               │ - severity     │
               │ - description  │
               │ - realWidth    │  ← Real measurements!
               │ - realHeight   │
               │ - realArea     │
               │ - confidence   │
               └────────────────┘
```

## API Configuration

The Gemini API key is loaded with 3-tier priority:

```swift
// GeminiConfig.swift
static var apiKey: String? {
    // 1. Environment variable (CI/CD)
    if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
        return envKey
    }

    // 2. GeminiAPIKey.plist in bundle
    if let plistKey = loadFromPlist() {
        return plistKey
    }

    // 3. UserDefaults (user-entered)
    return UserDefaults.standard.string(forKey: "GeminiAPIKey")
}
```

**Setup Options:**
- Set `GEMINI_API_KEY` environment variable
- Create `GeminiAPIKey.plist` with `API_KEY` entry
- Enter key in app settings (stored in UserDefaults)

## CapturedFrame Structure

Each captured frame contains all data needed for size calculation:

```swift
struct CapturedFrame: Identifiable {
    let id: UUID
    let imageData: Data           // JPEG compressed RGB image
    let timestamp: Date
    let cameraTransform: simd_float4x4

    // Depth data for size calculation
    let depthData: Data?          // Float32 depth values (meters)
    let depthWidth: Int           // Depth map width (e.g., 256)
    let depthHeight: Int          // Depth map height (e.g., 192)
    let cameraIntrinsics: simd_float3x3?  // Focal length, principal point
    let imageWidth: Int           // RGB image width (e.g., 1920)
    let imageHeight: Int          // RGB image height (e.g., 1440)

    var hasDepthData: Bool {
        depthData != nil && depthWidth > 0 && depthHeight > 0 && cameraIntrinsics != nil
    }
}
```

## Size Calculation: Pinhole Camera Model

The core math converts 2D pixel coordinates to real-world measurements using the pinhole camera model.

### The Formula

```
real_width  = depth × (pixel_width / focal_length_x)
real_height = depth × (pixel_height / focal_length_y)
real_area   = real_width × real_height
```

### Variables Explained

| Variable | Source | Description |
|----------|--------|-------------|
| `depth` | LiDAR depth map | Distance from camera to damage (meters) |
| `pixel_width` | Gemini bounding box | Damage width in pixels |
| `pixel_height` | Gemini bounding box | Damage height in pixels |
| `focal_length_x` | Camera intrinsics | fx from intrinsics matrix |
| `focal_length_y` | Camera intrinsics | fy from intrinsics matrix |

### Camera Intrinsics Matrix

```
┌                     ┐
│  fx    0    cx      │
│  0     fy   cy      │
│  0     0    1       │
└                     ┘

fx, fy = focal lengths (pixels)
cx, cy = principal point (image center)
```

### Implementation with 3x3 Median Sampling

The size calculator uses robust depth sampling to handle noise:

```swift
func calculateSize(
    boundingBox: DamageBoundingBox,  // Normalized 0-1 coordinates
    depthData: Data,
    depthWidth: Int,
    depthHeight: Int,
    cameraIntrinsics: simd_float3x3,
    imageWidth: Int,
    imageHeight: Int
) -> DamageRealDimensions? {

    // 1. Convert normalized bbox (0-1) to pixel coordinates
    let pixelX = Int(boundingBox.x * Float(imageWidth))
    let pixelY = Int(boundingBox.y * Float(imageHeight))
    let pixelW = Int(boundingBox.width * Float(imageWidth))
    let pixelH = Int(boundingBox.height * Float(imageHeight))

    // 2. Map pixel coordinates to depth buffer coordinates
    let scaleX = Float(depthWidth) / Float(imageWidth)
    let scaleY = Float(depthHeight) / Float(imageHeight)
    let depthCenterX = Int(Float(pixelX + pixelW/2) * scaleX)
    let depthCenterY = Int(Float(pixelY + pixelH/2) * scaleY)

    // 3. Sample depth using 3x3 grid with median filtering
    //    (more robust than single center point)
    var depthSamples: [Float] = []
    for dy in -1...1 {
        for dx in -1...1 {
            let sampleX = clamp(depthCenterX + dx, 0, depthWidth - 1)
            let sampleY = clamp(depthCenterY + dy, 0, depthHeight - 1)
            let depth = getDepthAt(x: sampleX, y: sampleY)
            if depth.isFinite && depth > 0.1 && depth < 5.0 {
                depthSamples.append(depth)
            }
        }
    }

    // Use median of valid samples
    guard !depthSamples.isEmpty else { return nil }
    depthSamples.sort()
    let centerDepth = depthSamples[depthSamples.count / 2]

    // 4. Extract focal lengths from intrinsics
    let fx = cameraIntrinsics[0][0]
    let fy = cameraIntrinsics[1][1]

    // 5. Apply pinhole camera model
    let realWidth = centerDepth * Float(pixelW) / fx
    let realHeight = centerDepth * Float(pixelH) / fy

    return DamageRealDimensions(
        width: realWidth,
        height: realHeight,
        area: realWidth * realHeight,
        depth: centerDepth,
        confidence: calculateConfidence(depth: centerDepth, bboxSize: boundingBox.area)
    )
}
```

### Confidence Calculation

Measurement confidence is reduced for:
- **Distance > 2m**: 0.9× multiplier
- **Distance > 3m**: 0.8× multiplier
- **Small bbox (< 1% of image)**: 0.7× multiplier
- **Small bbox (< 5% of image)**: 0.85× multiplier
- **Large bbox (> 50% of image)**: 0.8× multiplier

## Deduplication Logic

When the user captures the same damage from multiple angles, duplicates are removed:

```swift
// IoU (Intersection over Union) calculation
func calculateIoU(_ box1: DamageBoundingBox, _ box2: DamageBoundingBox) -> Float {
    let x1 = max(box1.x, box2.x)
    let y1 = max(box1.y, box2.y)
    let x2 = min(box1.x + box1.width, box2.x + box2.width)
    let y2 = min(box1.y + box1.height, box2.y + box2.height)

    let intersection = max(0, x2 - x1) * max(0, y2 - y1)
    let union = box1.area + box2.area - intersection

    return intersection / union
}

// Deduplication threshold: IoU > 0.3 = same damage
// When duplicates found, keep the one with:
// 1. Highest confidence, or
// 2. Closest distance (better depth accuracy)
```

## Gemini API Integration

### Model & Configuration

- **Model**: `gemini-3-flash-preview`
- **Base URL**: `https://generativelanguage.googleapis.com/v1beta`
- **Max image size**: 20MB
- **Timeout**: 60s request, 120s resource
- **Rate limiting**: 0.5s delay between requests

### Prompt for Bounding Boxes

```
Analyze this image for visible damage to room surfaces.

IMPORTANT: For each damage found, provide a PRECISE bounding box
that tightly fits the damage area.
- x, y: top-left corner as fraction of image (0.0-1.0)
- width, height: size as fraction of image (0.0-1.0)
- The box should closely outline ONLY the damaged area

Damage types to look for:
- crack, water_damage, hole, weathering, mold, peeling, stain, structural_damage, other

Response format (JSON only, no markdown):
{
    "damages": [
        {
            "type": "crack|water_damage|hole|weathering|mold|peeling|stain|structural_damage|other",
            "severity": "low|moderate|high|critical",
            "description": "Brief description",
            "confidence": 0.0-1.0,
            "boundingBox": {
                "x": 0.0-1.0,
                "y": 0.0-1.0,
                "width": 0.0-1.0,
                "height": 0.0-1.0
            },
            "recommendation": "Suggested action"
        }
    ],
    "overallCondition": "excellent|good|fair|poor|critical",
    "summary": "Brief overall assessment"
}
```

## DetectedDamage Model

The final damage model includes real-world measurements:

```swift
struct DetectedDamage: Identifiable, Codable {
    let id: UUID
    let type: DamageType
    let severity: DamageSeverity
    let description: String
    let surfaceType: SurfaceType
    let surfaceId: String?        // Links to CapturedRoom surface
    let confidence: Float
    let boundingBox: DamageBoundingBox?
    let recommendation: String?

    // Real-world dimensions (from LiDAR)
    let realWidth: Float?           // meters
    let realHeight: Float?          // meters
    let realArea: Float?            // square meters
    let distanceFromCamera: Float?  // meters
    let measurementConfidence: Float?

    var hasMeasurements: Bool {
        realWidth != nil && realHeight != nil
    }

    // Formatted output with automatic unit selection
    var formattedDimensions: String? {
        guard let w = realWidth, let h = realHeight else { return nil }
        if w < 0.01 || h < 0.01 {
            return String(format: "%.1f × %.1f mm", w * 1000, h * 1000)
        }
        return String(format: "%.1f × %.1f cm", w * 100, h * 100)
    }

    var formattedArea: String? {
        guard let area = realArea else { return nil }
        if area < 0.0001 {
            return String(format: "%.1f mm²", area * 1_000_000)
        } else if area < 0.01 {
            return String(format: "%.1f cm²", area * 10_000)
        } else {
            return String(format: "%.2f m²", area)
        }
    }
}
```

## Error Handling

The system handles errors gracefully:

### Partial Success
If some images fail analysis, results from successful images are still returned:
```swift
// Collects all successful detections even if some frames fail
var allDetections: [DetectedDamage] = []
for frame in frames {
    do {
        let result = try await geminiService.analyzeImage(frame.imageData)
        allDetections.append(contentsOf: result.damages)
    } catch {
        // Log error, continue with other frames
        print("Frame analysis failed: \(error)")
    }
}
```

### API Error Types
- `invalidAPIKey` - Check GeminiConfig setup
- `rateLimited` (429) - Automatic 0.5s delay between requests
- `quotaExceeded` (403) - Daily limit reached
- `imageTooLarge` - Compress image before retry
- `networkError` - Check connectivity

### Fallback Without Depth
When depth data is unavailable, size estimation falls back to surface-based calculation with lower confidence (0.7×).

## Exports

Damage size data is included in exports:

### JSON Export

```json
{
  "damages": [
    {
      "type": "crack",
      "severity": "high",
      "description": "Diagonal crack across wall",
      "confidence": 0.92,
      "widthM": 0.32,
      "heightM": 0.18,
      "areaM2": 0.0576,
      "distanceM": 2.1
    }
  ]
}
```

### PDF Export

The PDF report includes a "Size Measurements" section showing:
- Area (e.g., "576 cm²")
- Dimensions (e.g., "32 × 18 cm")
- Distance from camera
- Measurement confidence

## Accuracy Considerations

### Factors Affecting Accuracy

1. **Distance from surface** - Optimal: 1-3 meters
2. **Angle of capture** - Best: perpendicular to surface
3. **Lighting conditions** - Good lighting improves AI detection
4. **Surface texture** - Flat surfaces are more accurate
5. **Depth map resolution** - LiDAR provides ~256×192 depth pixels

### Measurement Confidence

Based on:
- Depth variance within bounding box (lower = better)
- Distance from camera (1-3m optimal)
- Bounding box size (not too small/large)

## Requirements

- **Device**: iPhone 12 Pro or later (LiDAR required)
- **iOS**: 17.0+
- **Frameworks**: ARKit, RealityKit, RoomPlan
- **API**: Gemini Vision API key

## Troubleshooting

### No Depth Data Captured

- Ensure device has LiDAR (iPhone 12 Pro+)
- Check ARWorldTrackingConfiguration supports `.sceneDepth`
- Verify `ARFrame.sceneDepth` is not nil

### Inaccurate Measurements

- Capture from 1-3 meters distance
- Point camera perpendicular to surface
- Ensure good lighting
- Check if bounding box from Gemini is accurate

### Camera Conflict Errors

If you see `FigCaptureSourceRemote err=-12784`:
- This means two AR sessions are fighting for camera
- Ensure sequential capture flow is being used
- Room scan and depth capture should not run simultaneously

### API Errors

- **401 Unauthorized**: Check API key configuration
- **429 Rate Limited**: Reduce capture frequency, wait before retry
- **403 Quota Exceeded**: Check Gemini API usage limits
