import SwiftUI
import RoomPlan

// MARK: - Top-level Delegate Class

final class RoomCaptureContainerDelegate: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    var appState: AppState?

    override init() {
        super.init()
    }

    // MARK: - NSCoding (required by RoomCaptureView internals)

    required init?(coder: NSCoder) {
        super.init()
    }

    func encode(with coder: NSCoder) {
        // No persistent state to encode
    }

    // MARK: - RoomCaptureSessionDelegate

    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        guard let appState = appState else { return }
        Task { @MainActor in
            appState.roomCaptureService.updateRoom(room)
        }
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        guard let appState = appState else { return }
        Task { @MainActor in
            appState.roomCaptureService.handleSessionEnd(data: data, error: error)
        }
    }

    func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration) {
        guard let appState = appState else { return }
        Task { @MainActor in
            appState.isScanning = true
        }
    }

    // MARK: - RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard let appState = appState else { return }
        Task { @MainActor in
            if let error = error {
                appState.scanError = error.localizedDescription
                return
            }
            appState.completeScan(with: processedResult)
        }
    }
}

// MARK: - Main View

struct RoomScanView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCancelAlert = false
    @State private var captureView: RoomCaptureView?
    @State private var delegate = RoomCaptureContainerDelegate()

    var body: some View {
        ZStack {
            // RoomPlan Camera View
            RoomCaptureViewContainer(
                configuration: appState.roomCaptureService.createConfiguration(),
                delegate: delegate,
                onViewCreated: { view in
                    captureView = view
                }
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top status bar
                ScanStatusBar(
                    detectedItems: appState.roomCaptureService.detectedItems
                )
                .padding(.top, 60)
                .padding(.horizontal)

                Spacer()

                // Bottom controls
                ScanControlsView(
                    isScanning: appState.isScanning,
                    onStart: startScanning,
                    onStop: stopScanning,
                    onCancel: { showCancelAlert = true }
                )
                .padding(.bottom, 40)
                .padding(.horizontal)
            }
        }
        .navigationBarHidden(true)
        .alert("Cancel Scan?", isPresented: $showCancelAlert) {
            Button("Continue Scanning", role: .cancel) { }
            Button("Cancel", role: .destructive) {
                appState.cancelScan()
            }
        } message: {
            Text("Your scan progress will be lost.")
        }
        .onAppear {
            delegate.appState = appState
            // Don't auto-start - wait for view to be ready and user to press button
        }
    }

    private func startScanning() {
        guard RoomCaptureService.isSupported else {
            appState.scanError = "RoomPlan not supported on this device"
            return
        }
        guard let view = captureView else {
            // View not ready yet - will be called when user taps button
            return
        }
        view.captureSession.run(
            configuration: appState.roomCaptureService.createConfiguration()
        )
    }

    private func stopScanning() {
        captureView?.captureSession.stop()
    }
}

// MARK: - RoomCaptureViewContainer

struct RoomCaptureViewContainer: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let configuration: RoomCaptureSession.Configuration
    let delegate: RoomCaptureContainerDelegate
    var onViewCreated: ((RoomCaptureView) -> Void)?

    func makeUIView(context: Context) -> RoomCaptureView {
        delegate.appState = appState

        let view = RoomCaptureView(frame: .zero)
        view.captureSession.delegate = delegate
        view.delegate = delegate
        onViewCreated?(view)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        delegate.appState = appState
    }

    func makeCoordinator() -> Void {
        // No coordinator needed - using external delegate
    }
}

// MARK: - Status Bar

struct ScanStatusBar: View {
    let detectedItems: RoomCaptureService.DetectedItems

    var body: some View {
        HStack(spacing: 16) {
            StatusItem(icon: "rectangle.portrait", count: detectedItems.wallCount, label: "Walls")
            StatusItem(icon: "door.left.hand.closed", count: detectedItems.doorCount, label: "Doors")
            StatusItem(icon: "window.vertical.closed", count: detectedItems.windowCount, label: "Windows")
            StatusItem(icon: "cube", count: detectedItems.objectCount, label: "Objects")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

struct StatusItem: View {
    let icon: String
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
    }
}

// MARK: - Controls

struct ScanControlsView: View {
    let isScanning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            // Main action button
            Button(action: isScanning ? onStop : onStart) {
                ZStack {
                    Circle()
                        .fill(isScanning ? .red : .white)
                        .frame(width: 70, height: 70)

                    if isScanning {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Circle()
                            .stroke(.black, lineWidth: 3)
                            .frame(width: 60, height: 60)
                    }
                }
            }

            // Placeholder for symmetry
            Color.clear
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(40)
    }
}

#Preview {
    RoomScanView()
        .environmentObject(AppState())
}
