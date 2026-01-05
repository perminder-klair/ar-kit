# Project Structure

## Directory Layout

```
ar-kit/
├── docs/                              # Documentation
│   ├── README.md                      # Overview
│   ├── IMPLEMENTATION_STATUS.md       # What's done/pending
│   ├── PROJECT_STRUCTURE.md           # This file
│   ├── API_REFERENCE.md               # Code reference
│   └── SETUP_GUIDE.md                 # How to run
│
└── RoomScanner/                       # Source code
    ├── App/                           # App lifecycle
    │   ├── RoomScannerApp.swift       # @main entry point
    │   ├── AppState.swift             # Global ObservableObject
    │   └── ContentView.swift          # Navigation controller
    │
    ├── Models/                        # Data models
    │   ├── RoomModel.swift            # Room & measurement types
    │   ├── DamageType.swift           # (Phase 5) Damage enum
    │   └── DamageDetection.swift      # (Phase 5) Detection result
    │
    ├── Services/                      # Business logic
    │   ├── RoomCapture/
    │   │   ├── RoomCaptureService.swift    # RoomPlan session
    │   │   └── CapturedRoomProcessor.swift # Dimension extraction
    │   ├── DamageDetection/           # (Phase 5)
    │   │   ├── DamageDetectionService.swift
    │   │   ├── VisionProcessor.swift
    │   │   └── DamageLocalizer.swift
    │   └── Export/
    │       └── RoomExporter.swift     # USDZ/JSON/PDF export
    │
    ├── Views/                         # SwiftUI views
    │   ├── Common/
    │   │   ├── HomeView.swift         # Landing screen
    │   │   └── CommonViews.swift      # Shared components
    │   ├── Scanning/
    │   │   ├── RoomScanView.swift     # Scanning UI
    │   │   └── RoomCaptureViewRepresentable.swift
    │   ├── Dimensions/
    │   │   └── DimensionsView.swift   # Measurements display
    │   ├── DamageDetection/           # (Phase 5)
    │   │   ├── DamageAnalysisView.swift
    │   │   └── DamageListView.swift
    │   └── Report/
    │       └── ReportView.swift       # Export options
    │
    ├── ML/                            # (Phase 5-6)
    │   └── DamageClassifier.mlmodel   # CoreML model
    │
    ├── Extensions/
    │   └── simd+Extensions.swift      # Math helpers
    │
    └── Info.plist                     # App configuration
```

## Architecture

### MVVM Pattern

```
┌─────────────────────────────────────────────────────────┐
│                        Views                            │
│  HomeView → RoomScanView → DimensionsView → ReportView  │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      AppState                           │
│           (Global ObservableObject)                     │
│  - currentScreen: Screen                                │
│  - capturedRoom: CapturedRoom?                          │
│  - roomCaptureService: RoomCaptureService               │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      Services                           │
│  RoomCaptureService  │  CapturedRoomProcessor           │
│  RoomExporter        │  DamageDetectionService (Phase 5)│
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. User taps "Start Scanning"
   └── AppState.startNewScan()
       └── Navigate to RoomScanView

2. RoomScanView displays RoomCaptureViewContainer
   └── RoomCaptureSession runs with LiDAR
       └── Delegate receives CapturedRoom updates
           └── RoomCaptureService.updateRoom()

3. User stops scan
   └── RoomCaptureView processes final results
       └── captureView(didPresent:) callback
           └── AppState.completeScan(with: room)
               └── Navigate to DimensionsView

4. DimensionsView loads
   └── CapturedRoomProcessor.extractDimensions()
       └── Display formatted measurements

5. User exports
   └── ReportView → RoomExporter
       └── Generate USDZ/JSON/PDF
           └── ShareSheet
```

## Key Dependencies

| Framework | Usage |
|-----------|-------|
| SwiftUI | UI framework |
| RoomPlan | LiDAR room scanning |
| ARKit | AR session, raycasting |
| RealityKit | 3D visualization |
| CoreML | Damage classification (Phase 5) |
| Vision | Image analysis (Phase 5) |
| PDFKit | PDF generation |

## Navigation Flow

```
┌──────────┐     ┌─────────────┐     ┌────────────────┐     ┌────────────┐
│ HomeView │ ──▶ │ RoomScanView│ ──▶ │ DimensionsView │ ──▶ │ ReportView │
└──────────┘     └─────────────┘     └────────────────┘     └────────────┘
     │                 │                     │                    │
     │                 │                     │                    │
     ▼                 ▼                     ▼                    ▼
  Start Scan     Live Scanning          View Results          Export
                 (RoomPlan UI)          (Measurements)        (Share)
```
