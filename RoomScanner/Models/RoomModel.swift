import Foundation
import RoomPlan
import simd

/// Wrapper for room scan data
struct RoomScanResult: Identifiable {
    let id: UUID
    let capturedRoom: CapturedRoom
    let scanDate: Date
    let dimensions: CapturedRoomProcessor.RoomDimensions?

    init(capturedRoom: CapturedRoom, dimensions: CapturedRoomProcessor.RoomDimensions? = nil) {
        self.id = UUID()
        self.capturedRoom = capturedRoom
        self.scanDate = Date()
        self.dimensions = dimensions
    }
}

/// Scan session status
enum ScanStatus: Equatable {
    case idle
    case preparing
    case scanning
    case processing
    case completed
    case error(String)

    var isActive: Bool {
        switch self {
        case .scanning, .processing:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .preparing:
            return "Preparing..."
        case .scanning:
            return "Scanning room..."
        case .processing:
            return "Processing..."
        case .completed:
            return "Scan complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

/// Measurement formatting utilities
struct MeasurementFormatter {
    enum Unit: String, CaseIterable {
        case meters = "m"
        case feet = "ft"
        case centimeters = "cm"
        case inches = "in"

        var displayName: String {
            switch self {
            case .meters: return "Meters"
            case .feet: return "Feet"
            case .centimeters: return "Centimeters"
            case .inches: return "Inches"
            }
        }

        var toMetersMultiplier: Float {
            switch self {
            case .meters: return 1.0
            case .feet: return 0.3048
            case .centimeters: return 0.01
            case .inches: return 0.0254
            }
        }

        var fromMetersMultiplier: Float {
            1.0 / toMetersMultiplier
        }
    }

    let unit: Unit
    let decimals: Int

    init(unit: Unit = .meters, decimals: Int = 2) {
        self.unit = unit
        self.decimals = decimals
    }

    func format(_ meters: Float) -> String {
        let value = meters * unit.fromMetersMultiplier
        return String(format: "%.\(decimals)f %@", value, unit.rawValue)
    }

    func formatArea(_ squareMeters: Float) -> String {
        let multiplier = unit.fromMetersMultiplier * unit.fromMetersMultiplier
        let value = squareMeters * multiplier
        return String(format: "%.\(decimals)f %@\u{00B2}", value, unit.rawValue)
    }

    func formatVolume(_ cubicMeters: Float) -> String {
        let multiplier = unit.fromMetersMultiplier * unit.fromMetersMultiplier * unit.fromMetersMultiplier
        let value = cubicMeters * multiplier
        return String(format: "%.\(decimals)f %@\u{00B3}", value, unit.rawValue)
    }
}

/// Position in 3D space
struct Position3D: Codable, Equatable {
    let x: Float
    let y: Float
    let z: Float

    init(_ simd: simd_float3) {
        self.x = simd.x
        self.y = simd.y
        self.z = simd.z
    }

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    var simd: simd_float3 {
        simd_float3(x, y, z)
    }

    static let zero = Position3D(x: 0, y: 0, z: 0)
}
