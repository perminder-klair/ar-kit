import SwiftUI
import RoomPlan
import Combine

/// Global application state managing room scanning workflow
@MainActor
final class AppState: ObservableObject {

    // MARK: - Navigation

    enum Screen: Equatable {
        case home
        case scanning
        case processing
        case dimensions
        case damageAnalysis
        case damageResults
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

    // MARK: - Damage Analysis Methods

    func startDamageAnalysis() {
        if let room = capturedRoom {
            damageAnalysisService.setRoom(room)
        }
        damageAnalysisResult = nil
        navigateTo(.damageAnalysis)
    }

    func completeDamageAnalysis(with result: DamageAnalysisResult) {
        damageAnalysisResult = result
        navigateTo(.damageResults)
    }

    func cancelDamageAnalysis() {
        damageAnalysisService.reset()
        navigateTo(.dimensions)
    }

    var isDamageAnalysisConfigured: Bool {
        damageAnalysisService.isConfigured
    }

    func reset() {
        capturedRoom = nil
        scanError = nil
        isScanning = false
        damageAnalysisResult = nil
        damageAnalysisService.reset()
        navigateTo(.home)
    }
}
