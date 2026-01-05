# Damage Detection with LiDAR Size Measurement

This document explains how the damage detection system works, including AI-powered damage identification and real-world size measurement using LiDAR depth data.

## Overview

The damage detection system combines:
1. **Gemini Vision AI** - Identifies damage types (cracks, water damage, mold, etc.) and provides bounding boxes
2. **LiDAR Depth Capture** - Captures depth maps during AR scanning
3. **Size Calculation** - Converts 2D bounding boxes to real-world measurements using depth data and camera intrinsics

## User Flow

```
┌─────────────────┐
│    Home View    │
└────────┬────────┘
         │ Start Scan
         ▼
┌─────────────────┐
│  Room Scan View │  ← RoomCaptureSession (screenshots captured)
└────────┬────────┘
         │ Complete Scan
         ▼
┌─────────────────┐
│ Dimensions View │  ← View room measurements
└────────┬────────┘
         │ "Capture for Damage Analysis"
         ▼
┌─────────────────┐
│ Depth Capture   │  ← ARSession with LiDAR depth
│     View        │     User walks around capturing frames
└────────┬────────┘
         │ "Done" (10-15 frames captured)
         ▼
┌─────────────────┐
│ Damage Analysis │  ← Gemini AI analyzes images
│     View        │
└────────┬────────┘
         │ Analysis Complete
         ▼
┌─────────────────┐
│ Damage Results  │  ← Shows damage with real sizes
│     View        │     e.g., "32cm × 18cm (576 cm²)"
└─────────────────┘
```

## Why Sequential Capture?

Running `RoomCaptureSession` and `ARSession` simultaneously causes camera resource conflicts:
- `FigCaptureSourceRemote err=-12784` - Camera already in use
- Both sessions fight for exclusive camera access

**Solution**: Sequential capture separates the two AR sessions:
1. Room scan uses `RoomCaptureSession` alone (with screenshot fallback)
2. Depth capture uses `ARSession` alone after scan completes

## Architecture

### Key Components

| Component | File | Purpose |
|-----------|------|---------|
| `ARFrameCaptureService` | `Services/DamageDetection/ARFrameCaptureService.swift` | Captures and stores frames with depth data |
| `DamageSizeCalculator` | `Services/DamageDetection/DamageSizeCalculator.swift` | Converts bounding boxes to real measurements |
| `GeminiService` | `Services/DamageDetection/GeminiService.swift` | AI damage detection via Gemini Vision API |
| `DamageAnalysisService` | `Services/DamageDetection/DamageAnalysisService.swift` | Orchestrates the analysis pipeline |
| `DepthCaptureView` | `Views/DamageDetection/DepthCaptureView.swift` | UI for capturing depth frames |

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

### Implementation

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
    //    (depth map is typically lower resolution than RGB image)
    let scaleX = Float(depthWidth) / Float(imageWidth)
    let scaleY = Float(depthHeight) / Float(imageHeight)
    let depthCenterX = Int(Float(pixelX + pixelW/2) * scaleX)
    let depthCenterY = Int(Float(pixelY + pixelH/2) * scaleY)

    // 3. Sample depth at bounding box center
    let centerDepth = getDepthAt(x: depthCenterX, y: depthCenterY)

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
        confidence: calculateConfidence(...)
    )
}
```

## Gemini Prompt for Bounding Boxes

The Gemini prompt requests precise bounding boxes for accurate size calculation:

```
Analyze this image for visible damage.

IMPORTANT: For each damage found, provide a PRECISE bounding box
that tightly fits the damage area.
- x, y: top-left corner as fraction of image (0.0-1.0)
- width, height: size as fraction of image (0.0-1.0)
- The box should closely outline ONLY the damaged area

Response format:
{
    "damages": [
        {
            "type": "crack|water_damage|hole|mold|...",
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
    ]
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

    var formattedArea: String? {
        guard let area = realArea else { return nil }
        if area < 0.01 {
            return String(format: "%.1f cm²", area * 10000)
        } else {
            return String(format: "%.2f m²", area)
        }
    }

    var formattedDimensions: String? {
        guard let w = realWidth, let h = realHeight else { return nil }
        return String(format: "%.1f × %.1f cm", w * 100, h * 100)
    }
}
```

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

### Confidence Calculation

Measurement confidence is based on:
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
