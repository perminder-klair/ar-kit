import SwiftUI
import ARKit
import RealityKit

/// View for capturing depth frames with LiDAR after room scanning
/// User manually captures photos when they see damage
struct DepthCaptureView: View {
    @EnvironmentObject var appState: AppState
    @State private var capturedCount = 0
    @State private var showInstructions = true
    @State private var viewController: DepthCaptureARViewController?
    @State private var showCaptureFlash = false

    var body: some View {
        ZStack {
            // AR View with depth capture
            DepthCaptureARViewContainer(
                frameCaptureService: appState.frameCaptureService,
                onFrameCaptured: {
                    capturedCount = appState.frameCaptureService.frameCount
                },
                onViewControllerCreated: { vc in
                    viewController = vc
                }
            )
            .ignoresSafeArea()

            // Capture flash effect
            if showCaptureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

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

                // Hint text when capturing
                if !showInstructions {
                    Text("Point at damage, then tap capture")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
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
            // Photo count
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .foregroundColor(capturedCount > 0 ? .green : .white)
                Text("Photos: \(capturedCount)")
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
        .foregroundColor(.white)
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

            Text("Capture Damage Photos")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                InstructionItem(icon: "eye", text: "Look for cracks, holes, stains, mold")
                InstructionItem(icon: "camera", text: "Point camera at damage (1-2m away)")
                InstructionItem(icon: "hand.tap", text: "Tap capture button for each damage")
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)

            Button("Start") {
                withAnimation {
                    showInstructions = false
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

            // Manual capture button
            Button(action: capturePhoto) {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 90, height: 90)

                    // Inner filled circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)

                    // Camera icon
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                }
            }
            .disabled(showInstructions)
            .opacity(showInstructions ? 0.5 : 1.0)

            // Done button
            Button {
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

    private func capturePhoto() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Flash effect
        withAnimation(.easeIn(duration: 0.1)) {
            showCaptureFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCaptureFlash = false
            }
        }

        // Capture current frame
        viewController?.captureCurrentFrame()
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
    var onViewControllerCreated: ((DepthCaptureARViewController) -> Void)?

    func makeUIViewController(context: Context) -> DepthCaptureARViewController {
        let controller = DepthCaptureARViewController()
        controller.frameCaptureService = frameCaptureService
        controller.onFrameCaptured = onFrameCaptured

        // Expose controller to SwiftUI
        DispatchQueue.main.async {
            onViewControllerCreated?(controller)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: DepthCaptureARViewController, context: Context) {
        // No longer need to update capturing state - manual capture only
    }
}

// MARK: - AR View Controller

final class DepthCaptureARViewController: UIViewController {
    private var arView: ARView!
    private var arSession: ARSession { arView.session }

    weak var frameCaptureService: ARFrameCaptureService?
    var onFrameCaptured: (() -> Void)?

    private var isSessionRunning = false
    private var currentFrame: ARFrame?  // Store latest frame for manual capture

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
        frameCaptureService?.startCapturing()
        print("DepthCaptureARViewController: ARSession started with depth capture")
    }

    private func stopSession() {
        guard isSessionRunning else { return }
        arView.session.pause()
        isSessionRunning = false
        frameCaptureService?.stopCapturing()
        print("DepthCaptureARViewController: ARSession stopped")
    }

    /// Called by SwiftUI when user taps capture button
    func captureCurrentFrame() {
        guard let frame = currentFrame,
              let service = frameCaptureService else {
            print("DepthCaptureARViewController: No frame available to capture")
            return
        }

        // Capture the current frame with depth
        service.captureFrame(from: frame)

        // Notify UI
        DispatchQueue.main.async {
            self.onFrameCaptured?()
        }

        print("DepthCaptureARViewController: Manually captured frame \(service.frameCount) with depth")
    }
}

// MARK: - ARSessionDelegate

extension DepthCaptureARViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Store the latest frame for manual capture
        // Don't auto-capture - user will tap button when they see damage
        currentFrame = frame
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("DepthCaptureARViewController: ARSession failed: \(error.localizedDescription)")
    }
}

#Preview {
    DepthCaptureView()
        .environmentObject(AppState())
}
