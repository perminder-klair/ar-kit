# Screen 6: Report

**File:** `Views/Report/ReportView.swift`

## Purpose

The Report screen is the final destination where users can export their scan data in multiple formats. It provides a summary of the room and any detected damage, with one-tap export options.

## Role in Flow

```
Dimensions ──► [REPORT]
                  │
Damage Analysis ──┘
                  │
                  ├──► Share Sheet (export)
                  ├──► Dimensions (back)
                  └──► Home (reset)
```

## UI Elements

| Element | Description |
|---------|-------------|
| Export Options | 4 format buttons (USDZ, JSON, PDF, Three.js) |
| Damage Assessment | Summary of detected issues (if any) |
| 3D Room Model | Interactive model with damage markers |
| Room Details | Quick stats (floor area, wall area, ceiling height, volume) |
| Back Button | Returns to Dimensions |
| Home Icon | Resets app, returns to Home |

## Export Options

### 3D Model (USDZ)
- **Format:** Universal Scene Description (Apple's AR format)
- **Use Case:** View in AR Quick Look, share to other apps
- **Method:** `exporter.exportUSDZ(capturedRoom:)`

### Web 3D (JSON)
- **Format:** Three.js compatible geometry
- **Use Case:** Web-based 3D viewers
- **Method:** `exporter.exportThreeJS(capturedRoom:)`

### Data (JSON)
- **Format:** Machine-readable dimension data
- **Use Case:** Integration with other systems
- **Contents:** Room dimensions, surfaces, damage data
- **Method:** `exporter.exportJSON(capturedRoom:)`

### Report (PDF)
- **Format:** Printable inspection report
- **Use Case:** Professional documentation, sharing
- **Contents:** Summary, measurements, damage photos, 3D views
- **Method:** `exporter.exportPDF(capturedRoom:)`

## User Actions

### Export File
- **Trigger:** Tap any export button
- **Process:**
  1. `isExporting = true` (shows loading)
  2. Async export method runs
  3. File saved to `Documents/RoomScans/`
  4. Share sheet opens with file
- **Share Sheet:** Standard iOS `UIActivityViewController`

### View Damage Details
- **Trigger:** Tap damage item in assessment section
- **Navigation:** NavigationLink to `DamageDetailView`

### Go Back
- **Trigger:** Tap back button
- **Result:** `appState.navigateTo(.dimensions)`

### Go Home
- **Trigger:** Tap home icon
- **Result:** `appState.reset()`, returns to Home

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Report | Share Sheet | Any export button |
| Report | Dimensions | Back button |
| Report | Home | Home icon |
| Report | Damage Detail | Tap damage item |

## Export Details

### File Location
All exports saved to: `Documents/RoomScans/`

### Export Flow
```swift
private func exportUSDZ() {
    Task {
        isExporting = true
        do {
            let url = try await exporter.exportUSDZ(capturedRoom: capturedRoom)
            exportedFileURL = url
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
    }
}
```

### Share Sheet
```swift
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
}
```

## Data Included in Reports

### Room Data
- Floor area (m² and ft²)
- Total wall area
- Ceiling height
- Room volume
- Individual wall dimensions
- Door and window details

### Damage Data (if captured)
- Total issue count
- List of damages with:
  - Type and severity
  - Location (surface, wall name)
  - Dimensions
  - Photo (in PDF)

## Related Files

- `Services/Export/RoomExporter.swift` - All export methods
- `Services/Export/PDFGenerator.swift` - PDF layout
- `Views/Report/ShareSheet.swift` - UIActivityViewController wrapper
- `App/AppState.swift` - Navigation methods
