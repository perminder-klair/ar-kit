# Screen 4: Depth Capture

**File:** `Views/DamageDetection/DepthCaptureView.swift`

## Purpose

The Depth Capture screen allows users to manually capture high-quality photos of damage with LiDAR depth data. This provides accurate 3D positioning of damage within the scanned room.

## Role in Flow

```
Dimensions ──► [DEPTH_CAPTURE] ──► Damage Analysis
                     │
                     └──► Dimensions (if cancelled)
```

## UI Elements

| Element | Description |
|---------|-------------|
| AR Camera View | Live camera feed with depth overlay |
| Instructions Overlay | Initial guidance (dismissible) |
| Distance Indicator | Real-time distance to target surface |
| Status Bar | Photo count, "LiDAR Active" indicator |
| Camera Button | Bottom-center, captures current frame |
| Done Button | Bottom-right, proceeds to analysis |
| Cancel Button (X) | Top-right, cancels with confirmation |

## User Actions

### View Instructions
- **Display:** Overlay explains optimal capture technique
- **Dismiss:** Tap anywhere to dismiss

### Monitor Distance
- **Indicator:** Shows distance to surface being pointed at
- **Color Coding:**
  - Green (0.5-1.5m): Optimal range for accurate measurements
  - Yellow (1.5-2.5m): Acceptable but reduced accuracy
  - Red (<0.5m or >2.5m): Too close or too far

### Capture Photo
- **Trigger:** Tap camera button
- **Haptic:** Feedback confirms capture
- **Data Captured:**
  - High-resolution image
  - LiDAR depth map
  - Camera position/orientation
  - Surface normal at target point
- **Counter:** Status bar updates with photo count

### Complete Capture
- **Trigger:** Tap "Done" button
- **Result:** `appState.startDamageAnalysis()`
- **Navigation:** Proceeds to Damage Analysis with captured frames

### Cancel Capture
- **Trigger:** Tap X button
- **Confirmation:** Alert asks to confirm
- **Result:** `appState.navigateTo(.dimensions)`, discards captured frames

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Depth Capture | Damage Analysis | "Done" button |
| Depth Capture | Dimensions | Cancel button (confirmed) |

## Technical Details

### Frame Capture
- Uses `ARFrameCaptureService` to capture ARFrames
- Each frame includes:
  - `CVPixelBuffer` for image
  - Depth data from LiDAR
  - Transform matrix for 3D positioning
  - Timestamp

### Depth Data Usage
- Enables accurate placement of damage markers in 3D space
- Allows calculation of damage dimensions
- Maps damage to specific walls/surfaces

## Related Files

- `Services/ARFrameCapture/ARFrameCaptureService.swift` - Frame capture logic
- `Views/DamageDetection/DistanceIndicator.swift` - Distance UI component
- `App/AppState.swift` - `startDepthCapture()`, `startDamageAnalysis()`
