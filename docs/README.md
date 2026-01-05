# Room Scanner App

iOS app using Apple's **RoomPlan API** with LiDAR for room scanning and dimensions, plus **CoreML** for damage detection.

## Quick Links

- [Project Structure](./PROJECT_STRUCTURE.md)
- [Implementation Status](./IMPLEMENTATION_STATUS.md)
- [API Reference](./API_REFERENCE.md)
- [Setup Guide](./SETUP_GUIDE.md)

## Features

### Completed (Phase 1-4)
- Room scanning with LiDAR using RoomPlan API
- Real-time scan progress (walls, doors, windows detected)
- Dimension extraction (floor area, wall area, ceiling height, volume)
- 2D floor plan visualization
- Unit conversion (meters/feet)
- Export to USDZ (3D model for AR Quick Look)
- Export to JSON (machine-readable data)
- Export to PDF (printable report)

### Planned (Phase 5-6)
- AI damage detection (cracks, water damage, holes)
- 3D damage localization
- Damage severity scoring
- Enhanced reports with damage findings

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
