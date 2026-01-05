import SwiftUI
import RoomPlan
import Combine

// MARK: - Top-level Delegate Class

final class RoomCaptureDelegate: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    var appState: AppState?
    var configuration: RoomCaptureSession.Configuration?
    private var isSessionActive = false

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

    // MARK: - Session Control

    func startSession(_ captureView: RoomCaptureView) {
        guard !isSessionActive, let config = configuration else { return }
        isSessionActive = true
        captureView.captureSession.run(configuration: config)
    }

    func stopSession(_ captureView: RoomCaptureView) {
        guard isSessionActive else { return }
        isSessionActive = false
        captureView.captureSession.stop()
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
        return true
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

// MARK: - UIViewRepresentable

struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let configuration: RoomCaptureSession.Configuration
    let delegate: RoomCaptureDelegate

    init(configuration: RoomCaptureSession.Configuration, delegate: RoomCaptureDelegate) {
        self.configuration = configuration
        self.delegate = delegate
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        delegate.appState = appState
        delegate.configuration = configuration

        let roomCaptureView = RoomCaptureView(frame: .zero)
        roomCaptureView.captureSession.delegate = delegate
        roomCaptureView.delegate = delegate
        return roomCaptureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        delegate.appState = appState
        delegate.configuration = configuration
    }

    func makeCoordinator() -> Void {
        // No coordinator needed - using external delegate
    }
}

// MARK: - Session Controller

final class RoomCaptureSessionController: ObservableObject {
    weak var captureView: RoomCaptureView?
    var delegate: RoomCaptureDelegate?

    func startScanning() {
        guard let view = captureView, let del = delegate else { return }
        del.startSession(view)
    }

    func stopScanning() {
        guard let view = captureView, let del = delegate else { return }
        del.stopSession(view)
    }
}
