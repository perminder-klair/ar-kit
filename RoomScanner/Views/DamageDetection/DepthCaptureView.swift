import SwiftUI
import ARKit
import RealityKit

/// View for capturing depth frames with LiDAR after room scanning
/// Used to capture accurate depth data for damage size measurement
struct DepthCaptureView: View {
    @EnvironmentObject var appState: AppState
    @State private var capturedCount = 0
    @State private var isCapturing = false
    @State private var showInstructions = true

    private let targetFrameCount = 15

    var body: some View {
        ZStack {
            // AR View with depth capture
            DepthCaptureARViewContainer(
                frameCaptureService: appState.frameCaptureService,
                onFrameCaptured: {
                    capturedCount = appState.frameCaptureService.frameCount
                },
                isCapturing: $isCapturing
            )
            .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top status bar
                captureStatusBar
                    .padding(.top, 60)
                    .padding(.horizontal)

                Spacer()

                // Instructions overlay (shown initially)
                if showInstructions {
                    instructionsOverlay
                        .transition(.opacity)
                }

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.bottom, 40)
                    .padding(.horizontal)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Clear previous frames and start fresh
            appState.frameCaptureService.clearFrames()
            capturedCount = 0
        }
    }

    private var captureStatusBar: some View {
        HStack(spacing: 16) {
            // Capture progress
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .foregroundColor(isCapturing ? .green : .white)
                Text("\(capturedCount)/\(targetFrameCount)")
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()

            // Depth indicator
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("LiDAR Active")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var instructionsOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 50))
                .foregroundColor(.white)

            Text("Capture Photos for Damage Analysis")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                InstructionItem(icon: "arrow.left.and.right", text: "Walk slowly around the room")
                InstructionItem(icon: "camera", text: "Point at walls, floors, ceilings")
                InstructionItem(icon: "ruler", text: "Stay 1-3 meters from surfaces")
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)

            Button("Start Capturing") {
                withAnimation {
                    showInstructions = false
                    isCapturing = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 40)
    }

    private var bottomControls: some View {
        HStack(spacing: 30) {
            // Skip button
            Button {
                appState.startDamageAnalysis()
            } label: {
                Text("Skip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            // Progress ring / capture button
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(capturedCount) / CGFloat(targetFrameCount))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                // Inner circle with count
                Circle()
                    .fill(capturedCount >= targetFrameCount ? Color.green : Color.white)
                    .frame(width: 64, height: 64)

                Text("\(capturedCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(capturedCount >= targetFrameCount ? .white : .black)
            }

            // Done button
            Button {
                isCapturing = false
                appState.startDamageAnalysis()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(capturedCount > 0 ? .white : .white.opacity(0.5))
                    .frame(width: 70, height: 50)
                    .background(capturedCount > 0 ? Color.green : Color.gray)
                    .clipShape(Capsule())
            }
            .disabled(capturedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(40)
    }
}

// MARK: - Instruction Item

private struct InstructionItem: View {
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

// MARK: - AR View Container

struct DepthCaptureARViewContainer: UIViewControllerRepresentable {
    let frameCaptureService: ARFrameCaptureService
    let onFrameCaptured: () -> Void
    @Binding var isCapturing: Bool

    func makeUIViewController(context: Context) -> DepthCaptureARViewController {
        let controller = DepthCaptureARViewController()
        controller.frameCaptureService = frameCaptureService
        controller.onFrameCaptured = onFrameCaptured
        return controller
    }

    func updateUIViewController(_ uiViewController: DepthCaptureARViewController, context: Context) {
        if isCapturing {
            uiViewController.startCapturing()
        } else {
            uiViewController.stopCapturing()
        }
    }
}

// MARK: - AR View Controller

final class DepthCaptureARViewController: UIViewController {
    private var arView: ARView!
    private var arSession: ARSession { arView.session }

    weak var frameCaptureService: ARFrameCaptureService?
    var onFrameCaptured: (() -> Void)?

    private var isSessionRunning = false
    private var lastCaptureTime: Date = .distantPast
    private let captureInterval: TimeInterval = 2.0
    private let maxFrames = 15

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        // Set session delegate
        arView.session.delegate = self
    }

    private func startSession() {
        guard !isSessionRunning else { return }

        // Check for LiDAR support
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            print("DepthCaptureARViewController: Device does not support LiDAR depth")
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth

        arView.session.run(config)
        isSessionRunning = true
        print("DepthCaptureARViewController: ARSession started with depth capture")
    }

    private func stopSession() {
        guard isSessionRunning else { return }
        arView.session.pause()
        isSessionRunning = false
        print("DepthCaptureARViewController: ARSession stopped")
    }

    func startCapturing() {
        frameCaptureService?.startCapturing()
    }

    func stopCapturing() {
        frameCaptureService?.stopCapturing()
    }
}

// MARK: - ARSessionDelegate

extension DepthCaptureARViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let service = frameCaptureService,
              service.isCapturing,
              service.frameCount < maxFrames else { return }

        // Throttle captures
        let now = Date()
        guard now.timeIntervalSince(lastCaptureTime) >= captureInterval else { return }
        lastCaptureTime = now

        // Capture frame with depth
        service.captureFrame(from: frame)

        // Notify UI
        DispatchQueue.main.async {
            self.onFrameCaptured?()
        }

        print("DepthCaptureARViewController: Captured frame \(service.frameCount) with depth")
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("DepthCaptureARViewController: ARSession failed: \(error.localizedDescription)")
    }
}

#Preview {
    DepthCaptureView()
        .environmentObject(AppState())
}
