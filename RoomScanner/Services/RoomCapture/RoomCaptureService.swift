import Foundation
import RoomPlan
import Combine

/// Service managing RoomPlan scanning sessions
@MainActor
final class RoomCaptureService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentRoom: CapturedRoom?
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var detectedItems: DetectedItems = DetectedItems()

    // MARK: - Types

    enum ScanState {
        case idle
        case preparing
        case scanning
        case processing
        case completed(CapturedRoom)
        case failed(String)

        var isActive: Bool {
            switch self {
            case .scanning, .processing:
                return true
            default:
                return false
            }
        }
    }

    struct DetectedItems: Equatable {
        var wallCount: Int = 0
        var doorCount: Int = 0
        var windowCount: Int = 0
        var objectCount: Int = 0

        mutating func update(from room: CapturedRoom) {
            wallCount = room.walls.count
            doorCount = room.doors.count
            windowCount = room.windows.count
            objectCount = room.objects.count
        }
    }

    enum RoomCaptureError: LocalizedError {
        case noActiveSession
        case noDataCaptured
        case processingFailed(String)
        case deviceNotSupported

        var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No active scanning session"
            case .noDataCaptured:
                return "No room data was captured"
            case .processingFailed(let message):
                return "Processing failed: \(message)"
            case .deviceNotSupported:
                return "This device does not support RoomPlan (LiDAR required)"
            }
        }
    }

    // MARK: - Private Properties

    private var capturedRoomData: CapturedRoomData?

    // MARK: - Public Methods

    /// Check if device supports RoomPlan
    static var isSupported: Bool {
        RoomCaptureSession.isSupported
    }

    /// Create default scanning configuration
    func createConfiguration() -> RoomCaptureSession.Configuration {
        var config = RoomCaptureSession.Configuration()
        config.isCoachingEnabled = true
        return config
    }

    /// Update state when room data changes during scanning
    func updateRoom(_ room: CapturedRoom) {
        currentRoom = room
        detectedItems.update(from: room)
        scanState = .scanning
    }

    /// Handle scan session end
    func handleSessionEnd(data: CapturedRoomData?, error: Error?) {
        if let error = error {
            scanState = .failed(error.localizedDescription)
            return
        }
        capturedRoomData = data
    }

    /// Process final room data
    func processResults() async throws -> CapturedRoom {
        scanState = .processing

        guard let data = capturedRoomData else {
            throw RoomCaptureError.noDataCaptured
        }

        do {
            let builder = RoomBuilder(options: [.beautifyObjects])
            let finalRoom = try await builder.capturedRoom(from: data)

            currentRoom = finalRoom
            scanState = .completed(finalRoom)
            return finalRoom
        } catch {
            scanState = .failed(error.localizedDescription)
            throw RoomCaptureError.processingFailed(error.localizedDescription)
        }
    }

    /// Reset service state
    func reset() {
        currentRoom = nil
        capturedRoomData = nil
        detectedItems = DetectedItems()
        scanState = .idle
    }
}
