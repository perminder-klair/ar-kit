import SwiftUI
import RoomPlan
import AVFoundation

// MARK: - RoomCaptureViewController

/// Room capture controller using Apple's RoomCaptureView for AR visualization
/// Uses parallel ARSession to capture frames with LiDAR depth data for damage size measurement
final class RoomCaptureViewController: UIViewController {

    // MARK: - Properties

    private var roomCaptureView: RoomCaptureView!
    private let sessionConfig: RoomCaptureSession.Configuration
    private var isSessionRunning = false

    // MARK: - Frame Capture (Screenshots during scan)

    weak var frameCaptureService: ARFrameCaptureService?

    // MARK: - Screenshot Capture (Fallback for non-LiDAR devices)

    private var screenshotTimer: Timer?
    private let screenshotInterval: TimeInterval = 2.0

    weak var delegate: RoomCaptureContainerDelegate? {
        didSet {
            if roomCaptureView != nil {
                roomCaptureView.captureSession.delegate = delegate
                roomCaptureView.delegate = delegate
            }
        }
    }

    init(configuration: RoomCaptureSession.Configuration, frameCaptureService: ARFrameCaptureService?) {
        self.sessionConfig = configuration
        self.frameCaptureService = frameCaptureService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRoomCaptureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    // MARK: - Setup

    private func setupRoomCaptureView() {
        // Create RoomCaptureView - Apple's polished AR scanning UI
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Set delegates
        roomCaptureView.captureSession.delegate = delegate
        roomCaptureView.delegate = delegate

        view.addSubview(roomCaptureView)
    }

    func startSession() {
        guard !isSessionRunning else { return }
        isSessionRunning = true

        // Start room capture
        roomCaptureView.captureSession.run(configuration: sessionConfig)

        // Start screenshot capture for damage analysis
        startScreenshotCapture()

        print("RoomCaptureViewController: Session started with screenshot capture")
    }

    func stopSession() {
        guard isSessionRunning else { return }
        isSessionRunning = false

        // Stop screenshot capture
        stopScreenshotCapture()

        // Stop room capture
        roomCaptureView.captureSession.stop()

        print("RoomCaptureViewController: Session stopped, captured \(frameCaptureService?.frameCount ?? 0) screenshots")
    }

    // MARK: - Screenshot Capture

    private func startScreenshotCapture() {
        frameCaptureService?.startCapturing()

        screenshotTimer = Timer.scheduledTimer(withTimeInterval: screenshotInterval, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
    }

    private func stopScreenshotCapture() {
        screenshotTimer?.invalidate()
        screenshotTimer = nil
        frameCaptureService?.stopCapturing()
    }

    private func captureScreenshot() {
        guard isSessionRunning else { return }

        // Capture the RoomCaptureView content
        let renderer = UIGraphicsImageRenderer(bounds: roomCaptureView.bounds)
        let image = renderer.image { _ in
            roomCaptureView.drawHierarchy(in: roomCaptureView.bounds, afterScreenUpdates: false)
        }

        // Send to frame capture service
        frameCaptureService?.addScreenshot(image)
    }
}

// MARK: - UIViewControllerRepresentable Wrapper

struct RoomCaptureViewControllerRepresentable: UIViewControllerRepresentable {
    let configuration: RoomCaptureSession.Configuration
    let delegate: RoomCaptureContainerDelegate
    let frameCaptureService: ARFrameCaptureService?
    var onViewControllerCreated: ((RoomCaptureViewController) -> Void)?

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        let viewController = RoomCaptureViewController(
            configuration: configuration,
            frameCaptureService: frameCaptureService
        )
        viewController.delegate = delegate

        // Provide reference back to SwiftUI
        DispatchQueue.main.async {
            onViewControllerCreated?(viewController)
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: RoomCaptureViewController, context: Context) {
        uiViewController.delegate = delegate
    }
}

// MARK: - Delegate Class

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
    @State private var delegate = RoomCaptureContainerDelegate()
    @State private var viewController: RoomCaptureViewController?
    @State private var cameraPermissionGranted = false
    @State private var permissionChecked = false

    var body: some View {
        ZStack {
            // RoomCaptureView with AR scanning lines and coaching UI
            RoomCaptureViewControllerRepresentable(
                configuration: appState.roomCaptureService.createConfiguration(),
                delegate: delegate,
                frameCaptureService: appState.frameCaptureService,
                onViewControllerCreated: { vc in
                    viewController = vc
                }
            )
            .ignoresSafeArea()

            // Permission overlay (shown on top when permission not granted)
            if !cameraPermissionGranted && permissionChecked {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Room scanning requires camera access to capture your space using LiDAR.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 40)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)

                    Button("Check Again") {
                        checkCameraPermission()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding()
            }

            // Loading overlay
            if !permissionChecked {
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                ProgressView("Checking camera access...")
                    .tint(.white)
                    .foregroundColor(.white)
            }

            // Controls overlay (shown when permission granted)
            if cameraPermissionGranted {
                VStack {
                    // Top status bar
                    ScanStatusBar(
                        detectedItems: appState.roomCaptureService.detectedItems,
                        capturedFrames: appState.capturedFrameCount
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
        }
        .navigationBarHidden(true)
        .alert("Cancel Scan?", isPresented: $showCancelAlert) {
            Button("Continue Scanning", role: .cancel) { }
            Button("Cancel", role: .destructive) {
                viewController?.stopSession()
                appState.cancelScan()
            }
        } message: {
            Text("Your scan progress will be lost.")
        }
        .onAppear {
            delegate.appState = appState
            // Clear any previous frames for a fresh scan
            appState.frameCaptureService.clearFrames()
            checkCameraPermission()
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            permissionChecked = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionGranted = granted
                    permissionChecked = true
                    if !granted {
                        appState.scanError = "Camera access is required for room scanning"
                    }
                }
            }
        case .denied, .restricted:
            cameraPermissionGranted = false
            permissionChecked = true
        @unknown default:
            permissionChecked = true
        }
    }

    private func startScanning() {
        guard RoomCaptureService.isSupported else {
            appState.scanError = "RoomPlan not supported on this device"
            return
        }
        viewController?.startSession()
    }

    private func stopScanning() {
        viewController?.stopSession()
    }
}

// MARK: - Status Bar

struct ScanStatusBar: View {
    let detectedItems: RoomCaptureService.DetectedItems
    var capturedFrames: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            StatusItem(icon: "rectangle.portrait", count: detectedItems.wallCount, label: "Walls")
            StatusItem(icon: "door.left.hand.closed", count: detectedItems.doorCount, label: "Doors")
            StatusItem(icon: "window.vertical.closed", count: detectedItems.windowCount, label: "Windows")
            StatusItem(icon: "camera.fill", count: capturedFrames, label: "Photos")
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
