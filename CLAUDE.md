# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS room scanning app using Apple's RoomPlan API with LiDAR. Captures 3D room data and extracts accurate dimensions (floor area, wall area, ceiling height, volume). Exports to USDZ, JSON, and PDF formats.

**Requirements:** iPhone 12 Pro+ with LiDAR, iOS 17+, Xcode 15+

## Build & Run

This is a standard Xcode project. Open in Xcode and run on a physical device (LiDAR hardware required - Simulator not supported for RoomPlan).

```bash
# Project location
RoomScanner/
```

No package manager dependencies - uses only Apple frameworks (RoomPlan, ARKit, RealityKit, PDFKit, CoreML, Vision).

## Architecture

**Pattern:** MVVM with centralized AppState

```
Views (SwiftUI) → AppState (@MainActor ObservableObject) → Services
```

**Navigation Flow:**
```
HomeView → RoomScanView → DimensionsView → ReportView
```

**Key Services:**
- `RoomCaptureService` - Wraps RoomPlan session, handles LiDAR scanning lifecycle
- `CapturedRoomProcessor` - Extracts dimensions from CapturedRoom (uses Shoelace formula for polygon areas)
- `RoomExporter` - Generates USDZ/JSON/PDF exports to `Documents/RoomScans/`

**Thread Safety Pattern:**
- AppState marked with `@MainActor`
- RoomCapture delegates use `nonisolated` + `Task { @MainActor in }` for UI updates

## Key Files

| File | Purpose |
|------|---------|
| `App/AppState.swift` | Global state, navigation, scan lifecycle |
| `Services/RoomCapture/RoomCaptureService.swift` | RoomPlan session management |
| `Services/RoomCapture/CapturedRoomProcessor.swift` | Dimension extraction logic |
| `Services/Export/RoomExporter.swift` | Multi-format export (USDZ/JSON/PDF) |
| `Views/Scanning/RoomCaptureViewRepresentable.swift` | UIViewRepresentable wrapper for RoomCaptureView |
| `Models/RoomModel.swift` | Data structures (RoomScanResult, ScanStatus, RoomDimensions) |

## Unit System

Base unit is meters. Conversion multipliers:
- Length: 1m = 3.28084ft = 39.3701in
- Area: squared multipliers
- Volume: cubed multipliers

## Planned Features (Phase 5-6)

AI damage detection using CoreML - see `docs/PROJECT_STRUCTURE.md` for planned directory structure.
