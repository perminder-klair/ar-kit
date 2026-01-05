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
        case report
    }

    @Published var currentScreen: Screen = .home

    // MARK: - Scan State

    @Published var capturedRoom: CapturedRoom?
    @Published var isScanning: Bool = false
    @Published var scanError: String?

    // MARK: - Services

    let roomCaptureService = RoomCaptureService()

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

    func reset() {
        capturedRoom = nil
        scanError = nil
        isScanning = false
        navigateTo(.home)
    }
}
