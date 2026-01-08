# Screen 1: Home

**File:** `Views/Common/HomeView.swift`

## Purpose

The Home screen is the entry point of the app. It introduces the app's features and provides the primary call-to-action to start a room scan.

## Role in Flow

```
[HOME] ──► Scanning
   ▲
   │
   └── Reset from any screen returns here
```

## UI Elements

| Element | Description |
|---------|-------------|
| App Logo | "Fixzy Scanner" branding |
| Feature List | Highlights key capabilities (accurate dimensions, 3D export, PDF reports) |
| Device Requirements | Shows LiDAR requirement (iPhone 12 Pro+) |
| Start Button | Primary CTA to begin scanning |

## User Actions

### Start Scanning
- **Trigger:** Tap "Start Scanning" button
- **Validation:** Checks `RoomCaptureService.isSupported` for LiDAR availability
- **Result:** Calls `appState.startNewScan()` which:
  - Clears any previous `capturedRoom` data
  - Clears `scanError`
  - Navigates to `.scanning`

### Device Not Supported
- If LiDAR is not available, displays an alert explaining the hardware requirement
- User cannot proceed to scanning

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Home | Scanning | "Start Scanning" button (if LiDAR supported) |

## Related Files

- `App/AppState.swift` - `startNewScan()` method
- `Services/RoomCapture/RoomCaptureService.swift` - `isSupported` check
