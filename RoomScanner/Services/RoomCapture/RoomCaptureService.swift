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

    struct ScanCompletenessResult {
        let isComplete: Bool
        let wallCount: Int
        let hasFloor: Bool
        let warnings: [String]

        static let minimumWallCount = 3

        var warningMessage: String {
            warnings.joined(separator: "\n")
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

    /// Check if current scan has minimum required data for accurate dimensions
    func checkScanCompleteness() -> ScanCompletenessResult {
        guard let room = currentRoom else {
            return ScanCompletenessResult(
                isComplete: false,
                wallCount: 0,
                hasFloor: false,
                warnings: ["No room data captured"]
            )
        }

        var warnings: [String] = []
        let wallCount = room.walls.count
        let hasFloor = !room.floors.isEmpty

        if wallCount < ScanCompletenessResult.minimumWallCount {
            let wallText = wallCount == 1 ? "wall" : "walls"
            warnings.append("Only \(wallCount) \(wallText) detected (minimum \(ScanCompletenessResult.minimumWallCount) recommended)")
        }

        if !hasFloor {
            warnings.append("No floor surface detected")
        }

        return ScanCompletenessResult(
            isComplete: warnings.isEmpty,
            wallCount: wallCount,
            hasFloor: hasFloor,
            warnings: warnings
        )
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
