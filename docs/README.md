# Room Scanner App

iOS app using Apple's **RoomPlan API** with LiDAR for room scanning and dimensions, plus **Gemini Vision AI** for damage detection with real-world size measurement.

## Quick Links

- [Project Structure](./PROJECT_STRUCTURE.md)
- [Implementation Status](./IMPLEMENTATION_STATUS.md)
- [API Reference](./API_REFERENCE.md)
- [Setup Guide](./SETUP_GUIDE.md)
- [Damage Detection](./DAMAGE_DETECTION.md) - How AI damage detection and LiDAR size measurement works

## Features

### Completed
- Room scanning with LiDAR using RoomPlan API
- Real-time scan progress (walls, doors, windows detected)
- Dimension extraction (floor area, wall area, ceiling height, volume)
- 2D floor plan visualization
- Unit conversion (meters/feet)
- Export to USDZ (3D model for AR Quick Look)
- Export to JSON (machine-readable data)
- Export to PDF (printable report)
- **AI Damage Detection** (Gemini Vision API)
  - Detects cracks, water damage, mold, holes, weathering, stains
  - Severity scoring (low, moderate, high, critical)
  - Repair recommendations
- **LiDAR Size Measurement**
  - Real-world damage dimensions (width × height)
  - Area calculation (cm² or m²)
  - Uses depth data + pinhole camera model

## Requirements

- **Device**: iPhone 12 Pro or later (LiDAR required)
- **iOS**: 17.0+
- **Xcode**: 15.0+

## Getting Started

See [Setup Guide](./SETUP_GUIDE.md) for detailed instructions.

```bash
# Project location
/Users/klair/Projects/ar-kit/RoomScanner/
```
