# API Reference

## Core Classes

### AppState

Global application state managing navigation and scan data.

```swift
@MainActor
final class AppState: ObservableObject {
    // Navigation
    @Published var currentScreen: Screen

    // Scan State
    @Published var capturedRoom: CapturedRoom?
    @Published var isScanning: Bool
    @Published var scanError: String?

    // Services
    let roomCaptureService: RoomCaptureService

    // Methods
    func startNewScan()
    func completeScan(with room: CapturedRoom)
    func cancelScan()
    func reset()
}

enum Screen {
    case home
    case scanning
    case processing
    case dimensions
    case report
}
```

---

### RoomCaptureService

Manages RoomPlan scanning sessions.

```swift
@MainActor
final class RoomCaptureService: ObservableObject {
    // State
    @Published var currentRoom: CapturedRoom?
    @Published var scanState: ScanState
    @Published var detectedItems: DetectedItems

    // Methods
    static var isSupported: Bool  // Check LiDAR availability
    func createConfiguration() -> RoomCaptureSession.Configuration
    func updateRoom(_ room: CapturedRoom)
    func handleSessionEnd(data: CapturedRoomData?, error: Error?)
    func processResults() async throws -> CapturedRoom
    func reset()
}

enum ScanState {
    case idle
    case preparing
    case scanning
    case processing
    case completed(CapturedRoom)
    case failed(String)
}

struct DetectedItems {
    var wallCount: Int
    var doorCount: Int
    var windowCount: Int
    var objectCount: Int
}
```

---

### CapturedRoomProcessor

Extracts dimensions from RoomPlan's CapturedRoom.

```swift
final class CapturedRoomProcessor {
    // Main method
    func extractDimensions(from room: CapturedRoom) -> RoomDimensions

    // Geometry
    func calculateBoundingBox(_ corners: [simd_float3]) -> (min: simd_float3, max: simd_float3)?
}

struct RoomDimensions {
    let walls: [WallDimension]
    let floor: FloorDimension
    let ceiling: CeilingDimension
    let doors: [OpeningDimension]
    let windows: [OpeningDimension]
    let totalFloorArea: Float      // m²
    let totalWallArea: Float       // m²
    let ceilingHeight: Float       // m
    let roomVolume: Float          // m³

    // Formatting
    func format(_ meters: Float, unit: MeasurementUnit) -> String
    func formatArea(_ m2: Float, unit: MeasurementUnit) -> String
    func formatVolume(_ m3: Float, unit: MeasurementUnit) -> String
}

struct WallDimension: Identifiable {
    let id: UUID
    let width: Float
    let height: Float
    let area: Float
    let transform: simd_float4x4
    let confidence: CapturedRoom.Confidence
    let isCurved: Bool
    let polygonCorners: [simd_float3]
}

struct FloorDimension {
    let area: Float
    let boundingWidth: Float
    let boundingLength: Float
    let polygonCorners: [simd_float3]
    let center: simd_float3
}

struct OpeningDimension: Identifiable {
    let id: UUID
    let type: OpeningType  // .door, .window, .opening
    let width: Float
    let height: Float
    let area: Float
    let transform: simd_float4x4
    let parentWallID: UUID?
}
```

---

### RoomExporter

Handles exporting room data to various formats.

```swift
final class RoomExporter {
    // Export Methods
    func exportUSDZ(capturedRoom: CapturedRoom) async throws -> URL
    func exportUSDZWithMetadata(capturedRoom: CapturedRoom) async throws -> (modelURL: URL, metadataURL: URL)
    func exportJSON(dimensions: RoomDimensions) throws -> URL
    func exportPDF(dimensions: RoomDimensions, capturedRoom: CapturedRoom) throws -> URL
}

struct RoomExportData: Codable {
    let exportDate: Date
    let roomDimensions: RoomDimensionsData
    let surfaces: SurfacesData
}
```

---

## SwiftUI Views

### HomeView
Landing screen with scan button and feature list.

### RoomScanView
Main scanning interface with RoomCaptureView.

```swift
struct RoomScanView: View {
    // Components
    - RoomCaptureViewContainer  // RoomPlan camera view
    - ScanStatusBar             // Detection counts
    - ScanControlsView          // Start/Stop/Cancel
}
```

### DimensionsView
Displays extracted room measurements.

```swift
struct DimensionsView: View {
    // Components
    - SummaryCard        // Floor area, volume, height
    - FloorPlanPreview   // 2D Canvas visualization
    - DetailedMeasurements  // Wall-by-wall list
}
```

### ReportView
Export options and room summary.

```swift
struct ReportView: View {
    // Components
    - ReportSummaryHeader  // Scan complete status
    - ExportOptionsSection // USDZ/JSON/PDF buttons
    - QuickStatsSection    // Room details
    - ShareSheet           // iOS share integration
}
```

---

## Measurement Units

```swift
enum MeasurementUnit {
    case meters    // "m"
    case feet      // "ft"

    var conversionFromMeters: Float
    var abbreviation: String
}
```

**Conversion Examples:**
```swift
let dims = processor.extractDimensions(from: room)

// Meters (default)
dims.format(2.5, unit: .meters)        // "2.50 m"
dims.formatArea(15.0, unit: .meters)   // "15.00 m²"

// Feet
dims.format(2.5, unit: .feet)          // "8.20 ft"
dims.formatArea(15.0, unit: .feet)     // "161.46 ft²"
```

---

## RoomPlan Integration

### Starting a Scan

```swift
// Create configuration
let config = RoomCaptureSession.Configuration()
config.isCoachingEnabled = true

// Start scanning
captureView.captureSession.run(configuration: config)
```

### Receiving Updates

```swift
// RoomCaptureSessionDelegate
func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
    // Live room data during scanning
    let wallCount = room.walls.count
    let doorCount = room.doors.count
}

func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
    // Raw data when scanning ends
}

// RoomCaptureViewDelegate
func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
    // Final processed room after user confirms
}
```

### Accessing Dimensions

```swift
// Wall dimensions
for wall in capturedRoom.walls {
    let width = wall.dimensions.x   // meters
    let height = wall.dimensions.y  // meters
    let transform = wall.transform  // 4x4 matrix
    let corners = wall.polygonCorners  // iOS 17+
}

// Floor dimensions
if let floor = capturedRoom.floors.first {
    let area = calculatePolygonArea(floor.polygonCorners)
}
```

---

## Phase 5 API (Planned)

### DamageDetectionService

```swift
@MainActor
final class DamageDetectionService: ObservableObject {
    @Published var detections: [DamageDetection]
    @Published var isAnalyzing: Bool

    func analyzeFrame(_ frame: ARFrame, capturedRoom: CapturedRoom) async throws -> [DamageDetection]
    func startContinuousAnalysis(arSession: ARSession, capturedRoom: CapturedRoom)
    func stopAnalysis()
}
```

### VisionProcessor

```swift
final class VisionProcessor {
    func classifyDamage(pixelBuffer: CVPixelBuffer) async throws -> [ClassificationResult]

    struct ClassificationResult {
        let damageType: DamageType
        let confidence: Float
        let boundingBox: CGRect
    }
}
```

### DamageType

```swift
enum DamageType: String, Codable {
    case crack
    case waterDamage
    case hole
    case weathering
    case delamination
    case spalling

    var displayName: String
    var severity: Severity
    var iconName: String
}
```
