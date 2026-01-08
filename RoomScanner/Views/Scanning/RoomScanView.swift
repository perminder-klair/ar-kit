import SwiftUI
import RoomPlan
import AVFoundation

// MARK: - RoomCaptureViewController

/// Room capture controller using Apple's RoomCaptureView for AR visualization
final class RoomCaptureViewController: UIViewController {

    // MARK: - Properties

    private var roomCaptureView: RoomCaptureView!
    private let sessionConfig: RoomCaptureSession.Configuration
    private var isSessionRunning = false

    weak var delegate: RoomCaptureContainerDelegate? {
        didSet {
            if roomCaptureView != nil {
                roomCaptureView.captureSession.delegate = delegate
                roomCaptureView.delegate = delegate
            }
        }
    }

    init(configuration: RoomCaptureSession.Configuration) {
        self.sessionConfig = configuration
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
        roomCaptureView.captureSession.run(configuration: sessionConfig)
        print("RoomCaptureViewController: Session started")
    }

    func stopSession() {
        guard isSessionRunning else { return }
        isSessionRunning = false
        roomCaptureView.captureSession.stop()
        print("RoomCaptureViewController: Session stopped")
    }
}

// MARK: - UIViewControllerRepresentable Wrapper

struct RoomCaptureViewControllerRepresentable: UIViewControllerRepresentable {
    let configuration: RoomCaptureSession.Configuration
    let delegate: RoomCaptureContainerDelegate
    var onViewControllerCreated: ((RoomCaptureViewController) -> Void)?

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        let viewController = RoomCaptureViewController(configuration: configuration)
        viewController.delegate = delegate

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
    @State private var showIncompleteScanAlert = false
    @State private var scanCompletenessResult: RoomCaptureService.ScanCompletenessResult?
    @State private var showInstructions = true

    var body: some View {
        ZStack {
            // RoomCaptureView with AR scanning lines and coaching UI
            RoomCaptureViewControllerRepresentable(
                configuration: appState.roomCaptureService.createConfiguration(),
                delegate: delegate,
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

            // Controls overlay (shown when permission granted and instructions dismissed)
            if cameraPermissionGranted && !showInstructions {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        // Vertical button stack - bottom right
                        VStack(spacing: 16) {
                            Button(action: { showCancelAlert = true }) {
                                Image(systemName: "xmark")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }

                            Button(action: stopScanning) {
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.red)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(40)
                        .padding(.trailing, 20)
                        .padding(.bottom, 40)
                    }
                }
            }

            // Instructions overlay (shown initially)
            if showInstructions && cameraPermissionGranted {
                instructionsOverlay
                    .transition(.opacity)
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
        .alert("Incomplete Scan", isPresented: $showIncompleteScanAlert) {
            Button("Continue Scanning", role: .cancel) { }
            Button("Complete Anyway", role: .destructive) {
                viewController?.stopSession()
            }
        } message: {
            if let result = scanCompletenessResult {
                Text(result.warningMessage + "\n\nYour room measurements may be inaccurate.")
            }
        }
        .onAppear {
            delegate.appState = appState
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

    private func stopScanning() {
        let result = appState.roomCaptureService.checkScanCompleteness()

        if result.isComplete {
            viewController?.stopSession()
        } else {
            scanCompletenessResult = result
            showIncompleteScanAlert = true
        }
    }

    private var instructionsOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 50))
                .foregroundColor(.white)

            Text("Scan Your Room")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                ScanInstructionItem(icon: "arrow.triangle.2.circlepath", text: "Walk slowly around the room")
                ScanInstructionItem(icon: "square.dashed", text: "Point at walls, floor, and ceiling")
                ScanInstructionItem(icon: "door.left.hand.open", text: "Include doors and windows")
                ScanInstructionItem(icon: "checkmark.circle", text: "Tap stop when complete")
            }

            Button {
                withAnimation {
                    showInstructions = false
                }
            } label: {
                Text("Start Scanning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 20)
    }
}

private struct ScanInstructionItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(text)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}

#Preview {
    RoomScanView()
        .environmentObject(AppState())
}
