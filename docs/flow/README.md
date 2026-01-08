# User Flow Documentation

This directory documents the complete user flow of the Fixzy Room Scanner app from start to export.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   HOME ──────► SCANNING ──────► DIMENSIONS ──────► REPORT                   │
│                                      │                 ▲                    │
│                                      │                 │                    │
│                                      ▼                 │                    │
│                               DEPTH_CAPTURE ──► DAMAGE_ANALYSIS             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Screen Sequence

| # | Screen | Purpose | File |
|---|--------|---------|------|
| 1 | [Home](01-home.md) | Entry point, start scanning | `Views/Common/HomeView.swift` |
| 2 | [Scanning](02-scanning.md) | AR room capture with LiDAR | `Views/Scanning/RoomScanView.swift` |
| 3 | [Dimensions](03-dimensions.md) | View results & 3D model | `Views/Dimensions/DimensionsView.swift` |
| 4 | [Depth Capture](04-depth-capture.md) | Capture damage photos (optional) | `Views/DamageDetection/DepthCaptureView.swift` |
| 5 | [Damage Analysis](05-damage-analysis.md) | AI damage detection (optional) | `Views/DamageDetection/DamageAnalysisView.swift` |
| 6 | [Report](06-report.md) | Export in multiple formats | `Views/Report/ReportView.swift` |

## Navigation Architecture

### Centralized State Management

All navigation is managed through `AppState` (`App/AppState.swift`):

```swift
enum Screen: Equatable {
    case home
    case scanning
    case processing
    case dimensions
    case depthCapture
    case damageAnalysis
    case report
}
```

### How Navigation Works

1. `AppState` holds `@Published var currentScreen: Screen`
2. `ContentView` uses a `NavigationStack` with a switch statement to render the active screen
3. Navigation occurs via `appState.navigateTo(.screenName)`

### Key Navigation Methods

| Method | Action |
|--------|--------|
| `startNewScan()` | Clears state, navigates to scanning |
| `completeScan(with:)` | Stores room data, navigates to dimensions |
| `cancelScan()` | Aborts scan, returns to home |
| `startDepthCapture()` | Clears frames, navigates to depth capture |
| `startDamageAnalysis()` | Prepares analysis, navigates to damage analysis |
| `reset()` | Clears all state, returns to home |

## Primary vs Optional Paths

**Primary Path (Room Scan Only):**
```
Home → Scanning → Dimensions → Report
```

**Extended Path (With Damage Detection):**
```
Home → Scanning → Dimensions → Depth Capture → Damage Analysis → Report
```

Users can skip damage detection and go directly from Dimensions to Report.

## Service Documentation

| Document | Description |
|----------|-------------|
| [DamageAnalysisService & Gemini](damage-analysis-service.md) | How AI damage detection works with Gemini API |
