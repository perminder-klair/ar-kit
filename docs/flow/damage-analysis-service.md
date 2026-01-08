# DamageAnalysisService & Gemini Integration

This document explains how the DamageAnalysisService works with Google's Gemini AI to detect and analyze damage in captured room images.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DamageAnalysisService                               │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │ ImageCapture    │  │ GeminiService   │  │ DamageSizeCalculator        │ │
│  │ Helper          │  │                 │  │ (LiDAR depth → real size)   │ │
│  └────────┬────────┘  └────────┬────────┘  └─────────────┬───────────────┘ │
│           │                    │                          │                 │
│           └────────────────────┼──────────────────────────┘                 │
│                                ▼                                            │
│                    DamageAnalysisResult                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | File | Purpose |
|-----------|------|---------|
| DamageAnalysisService | `Services/DamageDetection/DamageAnalysisService.swift` | Orchestrates analysis workflow |
| GeminiService | `Services/DamageDetection/GeminiService.swift` | Handles Gemini API communication |
| DamageSizeCalculator | `Services/DamageDetection/DamageSizeCalculator.swift` | Converts 2D bbox to real-world dimensions |
| ImageCaptureHelper | `Services/DamageDetection/ImageCaptureHelper.swift` | Image preprocessing |
| GeminiConfig | `Config/GeminiConfig.swift` | API key management |

---

## Data Flow Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. IMAGE COLLECTION                                                         │
│    Input: UIImage, Data, or CapturedFrame (with depth)                     │
│    Metadata: SurfaceType (wall/floor/ceiling), optional surfaceId          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. IMAGE PREPROCESSING (ImageCaptureHelper)                                 │
│    • Resize to max 2048px dimension                                         │
│    • Compress to JPEG (quality: 0.8)                                        │
│    • Wrap in CapturedImageData struct                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. GEMINI API CALL (GeminiService)                                          │
│    • Base64 encode image                                                    │
│    • Detect MIME type (PNG/JPEG/WebP)                                       │
│    • Build damage detection prompt                                          │
│    • POST to: generativelanguage.googleapis.com/v1beta                     │
│    • Model: gemini-3-flash-preview                                          │
│    • Rate limiting: 0.5s delay between images                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. RESPONSE PARSING                                                         │
│    • Clean markdown code blocks (```json...```)                             │
│    • Decode JSON to DamageAnalysisResponse                                  │
│    • Extract damages array with bounding boxes                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. SIZE CALCULATION (if depth data available)                               │
│    • Get corresponding ARFrame with LiDAR depth                             │
│    • Sample depth buffer at bbox center (3x3 grid, median filter)          │
│    • Apply pinhole camera model:                                            │
│      realWidth = depth × (pixelWidth / focalLength_x)                      │
│      realHeight = depth × (pixelHeight / focalLength_y)                    │
│    • Calculate measurement confidence                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 6. DEDUPLICATION                                                            │
│    • Compare bounding boxes across frames                                   │
│    • IOU (Intersection over Union) > 0.3 = same damage                     │
│    • Keep highest confidence or closest distance                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 7. FINAL RESULT                                                             │
│    DamageAnalysisResult with [DetectedDamage] array                        │
│    → Stored in AppState.damageAnalysisResult                               │
│    → Passed to ReportView for export                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Gemini Integration Details

### API Configuration

```swift
// GeminiService.swift
private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
private let model = "gemini-3-flash-preview"
private let maxImageSizeBytes = 20 * 1024 * 1024  // 20MB limit
```

### Prompt Structure

The prompt sent to Gemini is dynamically built based on surface type:

```
Analyze this image of a room [wall/floor/ceiling] for any visible damage or deterioration.

Look for these damage types:
- Cracks (hairline, structural, settlement)
- Water damage (stains, bubbling, warping)
- Holes (nail holes, damage holes, missing material)
- Weathering (sun damage, fading, discoloration)
- Mold (visible mold, mildew, fungal growth)
- Peeling (paint, wallpaper, surface coating)
- Stains (discoloration, marks)
- Structural damage (warping, buckling, sagging)

IMPORTANT - Bounding Box Instructions:
For each damage found, provide a PRECISE bounding box that tightly fits ONLY the damaged area:
- x: left edge position as fraction of image width (0.0-1.0)
- y: top edge position as fraction of image height (0.0-1.0)
- width: damage width as fraction of image width (0.0-1.0)
- height: damage height as fraction of image height (0.0-1.0)

Respond with a JSON object in this exact format:
{
    "damages": [
        {
            "type": "crack|water_damage|hole|weathering|mold|peeling|stain|structural_damage|other",
            "description": "Brief description of the damage",
            "confidence": 0.0 to 1.0,
            "boundingBox": {"x": 0.0-1.0, "y": 0.0-1.0, "width": 0.0-1.0, "height": 0.0-1.0},
            "recommendation": "Suggested action"
        }
    ],
    "summary": "Brief overall assessment"
}
```

### Expected Response Format

```json
{
    "damages": [
        {
            "type": "crack",
            "description": "Hairline crack running diagonally across wall surface",
            "confidence": 0.85,
            "boundingBox": {
                "x": 0.25,
                "y": 0.30,
                "width": 0.15,
                "height": 0.40
            },
            "recommendation": "Monitor for progression. Fill with flexible caulk if stable."
        }
    ],
    "summary": "One minor crack detected. Overall wall condition is good."
}
```

---

## Data Models

### DetectedDamage (Primary Output)

```swift
struct DetectedDamage: Identifiable, Codable {
    let id: UUID
    let type: DamageType              // crack, water_damage, hole, etc.
    let severity: DamageSeverity      // low, moderate, high, critical
    let description: String
    let surfaceType: SurfaceType      // wall, floor, ceiling
    let surfaceId: UUID?              // Links to CapturedRoom.Surface
    let wallName: String?             // "Wall A", "Wall B", etc.
    let confidence: Float             // 0.0-1.0
    let boundingBox: DamageBoundingBox?
    let recommendation: String?
    let imageIndex: Int               // Which captured image

    // Real-world measurements (from LiDAR depth)
    let realWidth: Float?             // meters
    let realHeight: Float?            // meters
    let realArea: Float?              // square meters
    let distanceFromCamera: Float?    // meters
    let measurementConfidence: Float? // 0.0-1.0
}
```

### DamageAnalysisResult (Container)

```swift
struct DamageAnalysisResult: Identifiable, Codable {
    let id: UUID
    let analysisDate: Date
    let roomScanId: UUID?
    let detectedDamages: [DetectedDamage]
    let overallCondition: OverallCondition  // excellent, good, fair, poor, critical
    let analyzedImageCount: Int
    let processingTimeSeconds: Double

    // Computed groupings
    var damagesBySeverity: [DamageSeverity: [DetectedDamage]]
    var damagesBySurface: [SurfaceType: [DetectedDamage]]
    var damagesByType: [DamageType: [DetectedDamage]]
}
```

### Supporting Enums

```swift
enum DamageType: String, Codable {
    case crack, waterDamage, hole, weathering
    case mold, peeling, stain, structuralDamage, other
}

enum DamageSeverity: String, Codable, Comparable {
    case low, moderate, high, critical
}

enum SurfaceType: String, Codable {
    case wall, floor, ceiling, door, window, unknown
}

enum OverallCondition: String, Codable {
    case excellent, good, fair, poor, critical
}
```

---

## Size Calculation with LiDAR Depth

When images are captured with ARFrames (containing depth data), the service calculates real-world damage dimensions:

### Pinhole Camera Model

```swift
// DamageSizeCalculator.swift
realWidth = depth × (pixelWidth / focalLength_x)
realHeight = depth × (pixelHeight / focalLength_y)

// Where:
// - depth: Distance to surface in meters (from LiDAR)
// - pixelWidth/Height: Bounding box size in pixels
// - focalLength: From ARFrame.camera.intrinsics matrix
```

### Confidence Scoring

Measurement confidence is reduced when:
- Distance > 3m from camera
- Bounding box is very small (< 5% of image)
- Bounding box is very large (> 80% of image)
- Depth values are inconsistent (high variance)

---

## Data Passed to Report Screen

### AppState Integration

```swift
// AppState.swift
@Published var damageAnalysisResult: DamageAnalysisResult?
```

### Flow to ReportView

1. **DamageAnalysisView** completes analysis:
   ```swift
   let result = try await damageAnalysisService.analyzeWithFrames(frames)
   appState.damageAnalysisResult = result
   appState.navigateTo(.report)
   ```

2. **ReportView** accesses result:
   ```swift
   if let damageResult = appState.damageAnalysisResult {
       // Display damage summary
       // Include in PDF export
       // Include in JSON export
   }
   ```

### Data Included in Exports

| Export Format | Damage Data Included |
|---------------|---------------------|
| **PDF** | Summary, damage list with photos, severity colors, recommendations |
| **JSON** | Full DetectedDamage array with all properties |
| **USDZ** | 3D model with damage marker positions |

---

## API Key Configuration

API keys are loaded in priority order:

1. Environment variable: `GEMINI_API_KEY`
2. Plist file: `GeminiAPIKey.plist` in bundle
3. UserDefaults: `"GeminiAPIKey"` key

```swift
// GeminiConfig.swift
var isConfigured: Bool { apiKey != nil }

func setAPIKey(_ key: String) {
    UserDefaults.standard.set(key, forKey: "GeminiAPIKey")
}
```

---

## Error Handling

### Analysis Errors

| Error | Cause |
|-------|-------|
| `notConfigured` | No Gemini API key set |
| `noImagesProvided` | No images to analyze |
| `analysisTimeout` | API request timed out |
| `allImagesFailed` | All image analyses failed |
| `partialFailure` | Some images failed, some succeeded |

### Gemini Errors

| Error | Cause |
|-------|-------|
| `invalidAPIKey` | API key rejected |
| `rateLimited` | Too many requests |
| `quotaExceeded` | API quota exhausted |
| `imageTooLarge` | Image exceeds 20MB |
| `parsingError` | Response not valid JSON |

---

## Related Files

| File | Purpose |
|------|---------|
| `Services/DamageDetection/DamageAnalysisService.swift` | Main orchestrator |
| `Services/DamageDetection/GeminiService.swift` | API communication |
| `Services/DamageDetection/DamageSizeCalculator.swift` | Depth-to-size conversion |
| `Services/DamageDetection/ImageCaptureHelper.swift` | Image preprocessing |
| `Models/DamageModel.swift` | Data structures |
| `Config/GeminiConfig.swift` | API key management |
| `Views/DamageDetection/DamageAnalysisView.swift` | UI for analysis |
| `Views/Report/ReportView.swift` | Consumes results for export |
