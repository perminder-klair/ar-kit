# Screen 2: Scanning

**File:** `Views/Scanning/RoomScanView.swift`

## Purpose

The Scanning screen provides the AR camera interface powered by Apple's RoomPlan API. Users walk around the room while the LiDAR sensor captures walls, floors, ceilings, doors, and windows.

## Role in Flow

```
Home ──► [SCANNING] ──► Dimensions
              │
              └──► Home (if cancelled)
```

## UI Elements

| Element | Description |
|---------|-------------|
| AR Camera View | Full-screen RoomPlan capture view |
| Instructions Overlay | Initial guidance on how to scan (dismissible) |
| Status Bar | Shows scan progress and feedback |
| Cancel Button (X) | Top-right, cancels scan with confirmation |
| Stop Button | Red circle, ends capture session |

## User Actions

### Scan the Room
- **Action:** Walk around the room pointing the device at surfaces
- **Feedback:** RoomPlan shows real-time visualization of detected surfaces
- **Guidance:** Instructions overlay shows tips (point at walls, move slowly, etc.)

### Dismiss Instructions
- **Trigger:** Tap anywhere or wait for auto-dismiss
- **Result:** Instructions overlay fades out, full AR view visible

### Cancel Scan
- **Trigger:** Tap X button
- **Result:** Confirmation alert appears
- **Confirm:** Calls `appState.cancelScan()`, returns to Home
- **Cancel:** Resumes scanning

### Complete Scan
- **Trigger:** Tap Stop button
- **Validation:** Completeness check (enough surfaces captured)
- **Result:** RoomPlan processes the captured data
- **Callback:** `captureView(didPresent:error:)` fires with `CapturedRoom`
- **Navigation:** Calls `appState.completeScan(with:)`, navigates to Dimensions

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Scanning | Dimensions | Stop button (successful capture) |
| Scanning | Home | Cancel button (confirmed) |

## Technical Details

### RoomPlan Integration
- Uses `RoomCaptureView` wrapped in `RoomCaptureViewRepresentable`
- `RoomCaptureContainerDelegate` handles session callbacks
- Thread safety: delegates use `nonisolated` + `Task { @MainActor in }`

### Session Lifecycle
1. Session starts when view appears
2. User captures room data
3. Stop triggers `captureSession.stop()`
4. RoomPlan processes and returns `CapturedRoom`
5. Delegate calls `appState.completeScan(with:)`

## Related Files

- `Views/Scanning/RoomCaptureViewRepresentable.swift` - UIViewRepresentable wrapper
- `Services/RoomCapture/RoomCaptureService.swift` - Session management
- `App/AppState.swift` - `completeScan(with:)`, `cancelScan()`
