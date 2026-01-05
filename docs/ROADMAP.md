# Development Roadmap

## Current Status: Phase 4 Complete ✅

Room scanning with dimensions and export functionality is fully implemented.

---

## Timeline

```
Phase 1-4: ██████████████████████████████████████ COMPLETE
Phase 5:   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ PENDING
Phase 6:   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ FUTURE
```

---

## Phase 5: AI Damage Detection (Placeholder Model)

### Goals
- Integrate CoreML + Vision for image classification
- Detect damage in real-time during/after room scan
- Map 2D detections to 3D locations on room surfaces

### Files to Create

| File | Purpose |
|------|---------|
| `Models/DamageType.swift` | Damage type enum with severity levels |
| `Models/DamageDetection.swift` | Detection result with 3D location |
| `Services/DamageDetection/DamageDetectionService.swift` | Orchestrates detection pipeline |
| `Services/DamageDetection/VisionProcessor.swift` | CoreML/Vision integration |
| `Services/DamageDetection/DamageLocalizer.swift` | 2D→3D coordinate mapping |
| `Views/DamageDetection/DamageAnalysisView.swift` | AR overlay for scanning damage |
| `Views/DamageDetection/DamageListView.swift` | List of detected damages |
| `ML/DamageClassifier.mlmodel` | Placeholder binary classifier |

### Implementation Steps

1. **Add Frameworks**
   ```swift
   import CoreML
   import Vision
   ```

2. **Create Placeholder Model**
   - Option A: Use MobileNetV2 as base (pre-trained on ImageNet)
   - Option B: Train minimal model with Create ML
   - Classes: `damage`, `no_damage`

3. **VisionProcessor Implementation**
   ```swift
   // Load model
   let model = try VNCoreMLModel(for: DamageClassifier().model)

   // Create request
   let request = VNCoreMLRequest(model: model) { request, error in
       // Handle results
   }

   // Process frame
   let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
   try handler.perform([request])
   ```

4. **3D Localization**
   - Use ARKit raycast from screen point
   - Find intersection with scene mesh
   - Map to nearest CapturedRoom surface

5. **Integration Points**
   - Add damage analysis button to DimensionsView
   - Create DamageAnalysisView with ARSession
   - Update ReportView with damage findings

### Estimated Effort
- Basic integration: 2-3 days
- AR overlay: 1-2 days
- Testing & refinement: 1-2 days

---

## Phase 6: Full Damage Detection Model

### Goals
- Train production-quality multi-class model
- Add damage severity scoring
- Measure damage dimensions
- Enhanced reporting

### Prerequisites
- Phase 5 working with placeholder
- Training dataset prepared
- GPU access for training (or Cloud ML)

### Training Dataset Options

| Dataset | Images | Classes | Source |
|---------|--------|---------|--------|
| SDNET2018 | 56,000+ | Crack/No Crack | [USU Digital Commons](https://digitalcommons.usu.edu/all_datasets/48/) |
| Wall Crack | 5,882 | 6 damage types | IEEE DataPort |
| CCIC | 40,000 | Crack/No Crack | METU |
| Custom | Variable | Custom | Your images |

### Model Classes

```swift
enum DamageType: String, CaseIterable {
    case crack           // Line fractures
    case waterDamage     // Stains, discoloration
    case weathering      // Surface degradation
    case spalling        // Flaking concrete
    case hole            // Physical openings
    case delamination    // Layer separation
    case rust            // Metal corrosion
    case exposedSteel    // Visible rebar
    case noDamage        // Clean surface
}
```

### Severity Scoring

```swift
enum DamageSeverity: Int {
    case low = 1       // Cosmetic only
    case moderate = 2  // Monitor
    case high = 3      // Repair soon
    case critical = 4  // Immediate attention
}
```

### Training with Create ML

1. **Prepare Dataset**
   ```
   TrainingData/
   ├── crack/
   │   ├── crack_001.jpg
   │   └── ...
   ├── water_damage/
   ├── spalling/
   └── no_damage/
   ```

2. **Create Project**
   - Open Create ML
   - New → Image Classifier
   - Drop training folder
   - Configure augmentations

3. **Train**
   - Training iterations: 50-100
   - Validation: 10% holdout
   - Export as .mlmodel

4. **Integrate**
   - Replace placeholder model
   - Update VisionProcessor class mapping

### Enhanced Features

- **Damage Measurement**
  - Calculate crack length from mesh
  - Estimate hole diameter
  - Report area affected

- **AR Visualization**
  - Color-coded severity markers
  - Tap to view damage details
  - Before/after comparison

- **Reports**
  - Damage photos with annotations
  - Location on floor plan
  - Recommended actions

---

## Future Ideas (Post Phase 6)

### Cloud Integration
- Sync scans to cloud storage
- Share reports via link
- Team collaboration

### Historical Tracking
- Compare scans over time
- Track damage progression
- Maintenance scheduling

### AI Enhancements
- Automatic repair cost estimation
- Material identification
- Structural analysis integration

### Platform Expansion
- iPad optimization
- visionOS support (Apple Vision Pro)
- Web viewer for reports

---

## Resources

### Apple Documentation
- [RoomPlan](https://developer.apple.com/documentation/roomplan)
- [ARKit](https://developer.apple.com/documentation/arkit)
- [Create ML](https://developer.apple.com/documentation/createml)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [Vision](https://developer.apple.com/documentation/vision)

### WWDC Sessions
- [WWDC22: Create parametric 3D room scans](https://developer.apple.com/videos/play/wwdc2022/10127/)
- [WWDC23: RoomPlan enhancements](https://developer.apple.com/videos/play/wwdc2023/10192/)
- [WWDC19: Training Object Detection Models](https://developer.apple.com/videos/play/wwdc2019/424/)

### Datasets
- [SDNET2018](https://digitalcommons.usu.edu/all_datasets/48/) - Concrete cracks
- [Awesome Crack Detection](https://github.com/nantonzhang/Awesome-Crack-Detection) - Paper list
