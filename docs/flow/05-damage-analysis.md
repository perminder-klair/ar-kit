# Screen 5: Damage Analysis

**File:** `Views/DamageDetection/DamageAnalysisView.swift`

## Purpose

The Damage Analysis screen processes captured photos using AI to detect and classify damage. It displays results with filtering options and allows users to review individual damage items.

## Role in Flow

```
Depth Capture ──► [DAMAGE_ANALYSIS] ──► Report
                        │
                        └──► Dimensions (done without report)
```

## UI Elements

| Element | Description |
|---------|-------------|
| Image Thumbnails | Grid of captured photos |
| Analyze Button | Starts AI analysis |
| Loading Overlay | Progress indicator during analysis |
| Summary Card | Total issues found |
| Filter Chips | All, Walls, Floors, Ceilings |
| Damage List | Tappable items with severity indicators |
| Generate Report Button | Proceeds to Report screen |
| Done Button | Returns to Dimensions |
| Refresh Icon | Clears results, allows re-analysis |

## Screen States

### Pre-Analysis State
- Shows thumbnail grid of captured images
- "Analyze [N] Images" button visible
- No results displayed yet

### Processing State
- Loading overlay with spinner
- Status text: "Analyzing image 1 of 5..."
- Progress updates from `damageAnalysisService.status`

### Results State
- Summary card with issue count
- Filter chips for surface type
- Scrollable list of detected damage
- Action buttons visible

## User Actions

### Start Analysis
- **Trigger:** Tap "Analyze [N] Images" button
- **Process:** `damageAnalysisService.analyzeWithFrames()`
- **Feedback:** Loading overlay with progress

### Filter Results
- **Trigger:** Tap filter chip (All, Walls, Floors, Ceilings)
- **Result:** List filters to show only matching damage types

### View Damage Details
- **Trigger:** Tap damage item in list
- **Navigation:** NavigationLink to `DamageDetailView`
- **Shows:** Full image, description, severity, dimensions, location

### Generate Report
- **Trigger:** Tap "Generate Report" button
- **Result:** `appState.navigateTo(.report)`
- **Data:** Damage results included in report

### Return to Dimensions
- **Trigger:** Tap "Done" button
- **Result:** `appState.navigateTo(.dimensions)`
- **Use Case:** User wants to review 3D model with damage markers

### Re-Analyze
- **Trigger:** Tap refresh icon
- **Result:** Clears results, returns to pre-analysis state
- **Use Case:** User captured more photos or wants fresh analysis

## Navigation Paths

| From | To | Trigger |
|------|-----|---------|
| Damage Analysis | Report | "Generate Report" button |
| Damage Analysis | Dimensions | "Done" button |
| Damage Analysis | Damage Detail | Tap damage item |

## Analysis Results

### Damage Item Properties
- **Type:** Crack, water damage, mold, hole, stain, etc.
- **Severity:** Low, Medium, High (color coded)
- **Surface:** Wall, Floor, Ceiling
- **Wall Name:** A, B, C... (if on named wall)
- **Dimensions:** Width × height (from depth data)
- **Position:** 3D coordinates for marker placement

### AI Service
- Uses `DamageAnalysisService` with Gemini API
- Processes images with depth context
- Returns structured damage classifications

**For detailed documentation on how the AI service works, see [DamageAnalysisService & Gemini Integration](damage-analysis-service.md).**

## Related Files

- `Services/DamageAnalysis/DamageAnalysisService.swift` - AI analysis logic
- `Views/DamageDetection/DamageDetailView.swift` - Detail view
- `Models/DamageModel.swift` - Damage data structures
- `App/AppState.swift` - Navigation methods
