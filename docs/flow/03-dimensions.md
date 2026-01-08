# Screen 3: Dimensions

**File:** `Views/Dimensions/DimensionsView.swift`

## Purpose

The Dimensions screen displays the scan results including calculated measurements and a 3D model of the captured room. It serves as the central hub for viewing results and choosing next steps.

## Role in Flow

```
Scanning ──► [DIMENSIONS] ──► Report
                  │
                  ├──► Depth Capture (optional path)
                  │
                  └──► Home (reset)
```

## UI Elements

| Element | Description |
|---------|-------------|
| Summary Card | Key metrics: floor area, volume, ceiling height, wall area |
| 3D Room Model | Interactive `RoomModelViewer` with damage markers (if any) |
| Detailed Measurements | List of walls, doors, windows with individual dimensions |
| Home Icon | Top-left, resets app and returns to Home |
| Report Icon | Top-right, navigates to Report screen |
| Capture Damage Button | Bottom, starts damage photo capture flow |

## User Actions

### View Summary
- **Display:** Automatically shows calculated dimensions from `CapturedRoomProcessor`
- **Metrics:** Floor area, total wall area, ceiling height, room volume

### Interact with 3D Model
- **Rotate:** Drag to rotate the model
- **Zoom:** Pinch to zoom in/out
- **Damage Markers:** If damage was detected, markers appear on surfaces

### Go to Report
- **Trigger:** Tap document icon (top-right)
- **Result:** `appState.navigateTo(.report)`
- **Use Case:** User wants to export without damage detection

### Start Damage Capture
- **Trigger:** Tap "Capture Damage Photos" button
- **Result:** `appState.startDepthCapture()`
- **Use Case:** User wants to document damage before generating report

### Reset / Go Home
- **Trigger:** Tap home icon (top-left)
- **Result:** `appState.reset()` clears all data, returns to Home

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Dimensions | Report | Report icon |
| Dimensions | Depth Capture | "Capture Damage Photos" button |
| Dimensions | Home | Home icon |

## Data Displayed

### Summary Metrics
- **Floor Area:** Calculated using Shoelace formula on floor polygon
- **Wall Area:** Sum of all wall surface areas
- **Ceiling Height:** Average height from `CapturedRoom` surfaces
- **Volume:** Floor area × ceiling height

### Detailed List
- Individual walls with dimensions (width × height)
- Doors with dimensions and type
- Windows with dimensions
- Wall names (A, B, C...) based on scan order

## Related Files

- `Services/RoomCapture/CapturedRoomProcessor.swift` - Dimension extraction
- `Views/Dimensions/RoomModelViewer.swift` - 3D model display
- `Models/RoomModel.swift` - `RoomDimensions` data structure
- `App/AppState.swift` - Navigation methods
