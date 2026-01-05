# Setup Guide

## Prerequisites

- **Mac**: macOS 14.0+ with Xcode 15.0+
- **Device**: iPhone 12 Pro, 13 Pro, 14 Pro, 15 Pro (or iPad Pro with LiDAR)
- **iOS**: 17.0+
- **Apple Developer Account**: Required for device deployment

---

## Step 1: Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **iOS** → **App**
4. Configure:
   - **Product Name**: `RoomScanner`
   - **Team**: Your development team
   - **Organization Identifier**: `com.yourname`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None
   - **Include Tests**: Optional

5. Click **Create**

---

## Step 2: Configure Project Settings

### Deployment Target
1. Select project in navigator
2. Select target → General
3. Set **Minimum Deployments** → iOS 17.0

### Required Capabilities
1. Target → Signing & Capabilities
2. Add capability if not present:
   - (Capabilities are auto-configured via Info.plist)

---

## Step 3: Copy Source Files

### Option A: Manual Copy
1. In Finder, navigate to:
   ```
   /Users/klair/Projects/ar-kit/RoomScanner/
   ```

2. In Xcode, create folder groups:
   - Right-click project → New Group → `App`
   - Repeat for: `Models`, `Services`, `Views`, `Extensions`

3. Drag and drop files into corresponding groups:

   | Source Folder | Files |
   |---------------|-------|
   | `App/` | `RoomScannerApp.swift`, `AppState.swift`, `ContentView.swift` |
   | `Models/` | `RoomModel.swift` |
   | `Services/RoomCapture/` | `RoomCaptureService.swift`, `CapturedRoomProcessor.swift` |
   | `Services/Export/` | `RoomExporter.swift` |
   | `Views/Common/` | `HomeView.swift`, `CommonViews.swift` |
   | `Views/Scanning/` | `RoomScanView.swift`, `RoomCaptureViewRepresentable.swift` |
   | `Views/Dimensions/` | `DimensionsView.swift` |
   | `Views/Report/` | `ReportView.swift` |
   | `Extensions/` | `simd+Extensions.swift` |

4. When prompted, select:
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to target: RoomScanner

### Option B: Terminal Copy
```bash
# Copy entire source folder
cp -R /Users/klair/Projects/ar-kit/RoomScanner/* /path/to/your/xcode/project/
```

Then add files to Xcode project manually.

---

## Step 4: Configure Info.plist

Add these keys to your `Info.plist`:

```xml
<!-- Privacy Permissions -->
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan rooms using LiDAR and create 3D models.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Photo library access is needed to save exported room scans and reports.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to save and share room scan exports.</string>

<!-- Device Requirements -->
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>armv7</string>
    <string>arkit</string>
    <string>lidar</string>
</array>
```

Or copy the complete Info.plist:
```bash
cp /Users/klair/Projects/ar-kit/RoomScanner/Info.plist /path/to/your/project/
```

---

## Step 5: Build and Run

### Connect Device
1. Connect iPhone/iPad via USB
2. Trust the computer on device if prompted
3. Select device in Xcode toolbar (not Simulator)

### Build
1. Press `Cmd + B` to build
2. Fix any errors (usually import issues)

### Run
1. Press `Cmd + R` to run
2. Accept camera permission on device
3. App should launch to Home screen

---

## Troubleshooting

### "RoomPlan not available"
- **Cause**: Device doesn't have LiDAR
- **Solution**: Use iPhone 12 Pro or later

### "No such module 'RoomPlan'"
- **Cause**: Deployment target too low
- **Solution**: Set iOS deployment target to 16.0+

### Build errors in Swift files
- **Cause**: Files not added to target
- **Solution**: Select file → File Inspector → Check target membership

### Camera permission denied
- **Cause**: User denied or Info.plist missing key
- **Solution**: Add `NSCameraUsageDescription` to Info.plist

### App crashes on launch
- **Cause**: Running on Simulator
- **Solution**: Must run on physical device with LiDAR

---

## Verify Installation

After launching, you should see:

1. **Home Screen**
   - Room Scanner title
   - "Start Scanning" button
   - Feature list

2. **Scanning** (after tapping Start)
   - Camera view with RoomPlan overlays
   - Status bar showing detected items
   - Stop button

3. **Dimensions** (after scanning)
   - Room summary (area, volume, height)
   - Floor plan visualization
   - Wall measurements

4. **Export** (from Dimensions)
   - USDZ, JSON, PDF options
   - Share sheet

---

## Project Files Location

```
Source Code:
/Users/klair/Projects/ar-kit/RoomScanner/

Documentation:
/Users/klair/Projects/ar-kit/docs/

Exports (runtime):
~/Documents/RoomScans/
```

---

## Next Steps

After verifying the app works:

1. **Customize UI**: Modify colors, fonts, layout in Views
2. **Add Features**: Scan history, cloud sync, etc.
3. **Phase 5**: Add damage detection (see IMPLEMENTATION_STATUS.md)

---

## Support

- [RoomPlan Documentation](https://developer.apple.com/documentation/roomplan)
- [WWDC22: Create parametric 3D room scans](https://developer.apple.com/videos/play/wwdc2022/10127/)
- [WWDC23: RoomPlan enhancements](https://developer.apple.com/videos/play/wwdc2023/10192/)
