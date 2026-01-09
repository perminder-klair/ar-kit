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
        navigateTo(.scanning)
    }

    func completeScan(with room: CapturedRoom) {
        capturedRoom = room
        isScanning = false
        navigateTo(.dimensions)
    }

    func cancelScan() {
        isScanning = false
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
        }

        navigateTo(.damageAnalysis)
    }

    func cancelDamageAnalysis() {
        damageAnalysisService.reset()
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
        navigateTo(.home)
    }
}
