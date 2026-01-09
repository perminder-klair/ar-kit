import SwiftUI
import RoomPlan
import Combine

/// Global application state managing room scanning workflow
@MainActor
final class AppState: ObservableObject {

    // MARK: - UserDefaults Keys

    private static let userNameKey = "userName"

    // MARK: - User Info

    @Published var userName: String = "" {
        didSet {
            UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        }
    }

    // MARK: - Session Telemetry

    @Published var sessionTelemetry: SessionTelemetry = SessionTelemetry()

    // MARK: - Initialization

    init() {
        userName = UserDefaults.standard.string(forKey: Self.userNameKey) ?? ""
    }

    // MARK: - Navigation

    enum Screen: Equatable {
        case home
        case scanning
        case processing
        case dimensions
        case depthCapture    // Capture depth frames for damage size measurement
        case damageAnalysis
        case report
    }

    @Published var currentScreen: Screen = .home

    // MARK: - Scan State

    @Published var capturedRoom: CapturedRoom?
    @Published var isScanning: Bool = false
    @Published var scanError: String?

    // MARK: - Damage Analysis State

    @Published var damageAnalysisResult: DamageAnalysisResult?

    // MARK: - Services

    let roomCaptureService = RoomCaptureService()
    let damageAnalysisService = DamageAnalysisService()
    let frameCaptureService = ARFrameCaptureService()

    // MARK: - Computed Properties

    var hasCapturedRoom: Bool {
        capturedRoom != nil
    }

    // MARK: - Navigation Methods

    func navigateTo(_ screen: Screen) {
        withAnimation {
            currentScreen = screen
        }
    }

    func startNewScan() {
        capturedRoom = nil
        scanError = nil
        // Reset telemetry for new session
        sessionTelemetry = SessionTelemetry()
        sessionTelemetry.timestamps.markScanStarted()
        navigateTo(.scanning)
    }

    func completeScan(with room: CapturedRoom) {
        capturedRoom = room
        isScanning = false
        sessionTelemetry.timestamps.markScanEnded()
        // Calculate scan duration
        if let start = sessionTelemetry.timestamps.scanStartedAt,
           let end = sessionTelemetry.timestamps.scanEndedAt {
            sessionTelemetry.scanMetrics.durationSeconds = end.timeIntervalSince(start)
        }
        // Update scan metrics from completeness check
        let completeness = roomCaptureService.checkScanCompleteness()
        sessionTelemetry.scanMetrics.update(from: completeness)
        sessionTelemetry.scanMetrics.finalState = .completed
        navigateTo(.dimensions)
    }

    func cancelScan() {
        isScanning = false
        sessionTelemetry.timestamps.markScanEnded()
        sessionTelemetry.scanMetrics.finalState = .cancelled
        navigateTo(.home)
    }

    // MARK: - Depth Capture Methods

    func startDepthCapture() {
        // Clear any previous frames for fresh capture
        frameCaptureService.clearFrames()
        navigateTo(.depthCapture)
    }

    // MARK: - Damage Analysis Methods

    func startDamageAnalysis() {
        if let room = capturedRoom {
            damageAnalysisService.setRoom(room)
        }
        damageAnalysisResult = nil
        sessionTelemetry.timestamps.markAnalysisStarted()

        // Auto-populate images from frame capture if available
        if hasCapturedFrames {
            damageAnalysisService.clearPendingImages()
            let images = frameCaptureService.getImagesForAnalysis()
            for image in images {
                damageAnalysisService.addImageData(
                    image.data,
                    surfaceType: image.surfaceType,
                    surfaceId: image.surfaceId
                )
            }
            // Update frame capture metrics
            sessionTelemetry.frameCapture.update(from: frameCaptureService.capturedFrames)
        }

        navigateTo(.damageAnalysis)
    }

    func completeDamageAnalysis(with result: DamageAnalysisResult) {
        damageAnalysisResult = result
        sessionTelemetry.timestamps.markAnalysisEnded()
        // Update confidence metrics from damage results
        sessionTelemetry.confidence.update(from: result.detectedDamages)
    }

    func cancelDamageAnalysis() {
        damageAnalysisService.reset()
        sessionTelemetry.timestamps.markAnalysisEnded()
        navigateTo(.dimensions)
    }

    var isDamageAnalysisConfigured: Bool {
        damageAnalysisService.isConfigured
    }

    var hasCapturedFrames: Bool {
        !frameCaptureService.capturedFrames.isEmpty
    }

    var capturedFrameCount: Int {
        frameCaptureService.frameCount
    }

    func reset() {
        capturedRoom = nil
        scanError = nil
        isScanning = false
        damageAnalysisResult = nil
        damageAnalysisService.reset()
        frameCaptureService.reset()
        sessionTelemetry = SessionTelemetry()
        navigateTo(.home)
    }

    /// Record a scan error in telemetry
    func recordScanError(code: String, message: String) {
        scanError = message
        sessionTelemetry.errors.addScanError(code: code, message: message)
        sessionTelemetry.scanMetrics.finalState = .failed
        sessionTelemetry.scanMetrics.failureReason = message
    }
}
