import Foundation
import RoomPlan
import simd

/// Processes CapturedRoom data to extract room dimensions and measurements
final class CapturedRoomProcessor {

    // MARK: - Types

    struct RoomDimensions {
        let walls: [WallDimension]
        let floor: FloorDimension
        let ceiling: CeilingDimension
        let doors: [OpeningDimension]
        let windows: [OpeningDimension]
        let totalFloorArea: Float // square meters
        let totalWallArea: Float // square meters
        let ceilingHeight: Float // meters
        let roomVolume: Float // cubic meters

        /// Summary statistics
        var wallCount: Int { walls.count }
        var doorCount: Int { doors.count }
        var windowCount: Int { windows.count }
    }

    struct WallDimension: Identifiable {
        let id: UUID
        let width: Float // meters
        let height: Float // meters
        let area: Float // square meters
        let transform: simd_float4x4
        let confidence: CapturedRoom.Confidence
        let isCurved: Bool
        let polygonCorners: [simd_float3]

        var position: simd_float3 {
            simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
    }

    struct FloorDimension {
        let area: Float // square meters
        let boundingWidth: Float // meters
        let boundingLength: Float // meters
        let polygonCorners: [simd_float3]
        let center: simd_float3
    }

    struct CeilingDimension {
        let area: Float // square meters
        let height: Float // meters from floor
        let polygonCorners: [simd_float3]
    }

    struct OpeningDimension: Identifiable {
        let id: UUID
        let type: OpeningType
        let width: Float // meters
        let height: Float // meters
        let area: Float // square meters
        let transform: simd_float4x4
        let parentWallID: UUID?

        enum OpeningType {
            case door
            case window
            case opening
        }

        var position: simd_float3 {
            simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
    }

    // MARK: - Public Methods

    /// Extract all dimensions from a CapturedRoom
    func extractDimensions(from room: CapturedRoom) -> RoomDimensions {
        let walls = processWalls(room.walls)
        let floor = processFloor(room.floors.first)
        let ceiling = processCeiling(walls: walls)
        let doors = processDoors(room.doors)
        let windows = processWindows(room.windows)

        let totalWallArea = walls.reduce(0) { $0 + $1.area }
        let totalFloorArea = floor.area
        let roomVolume = totalFloorArea * ceiling.height

        return RoomDimensions(
            walls: walls,
            floor: floor,
            ceiling: ceiling,
            doors: doors,
            windows: windows,
            totalFloorArea: totalFloorArea,
            totalWallArea: totalWallArea,
            ceilingHeight: ceiling.height,
            roomVolume: roomVolume
        )
    }

    // MARK: - Private Processing Methods

    private func processWalls(_ surfaces: [CapturedRoom.Surface]) -> [WallDimension] {
        surfaces.map { surface in
            WallDimension(
                id: surface.identifier,
                width: surface.dimensions.x,
                height: surface.dimensions.y,
                area: surface.dimensions.x * surface.dimensions.y,
                transform: surface.transform,
                confidence: surface.confidence,
                isCurved: surface.curve != nil,
                polygonCorners: surface.polygonCorners
            )
        }
    }

    private func processFloor(_ surface: CapturedRoom.Surface?) -> FloorDimension {
        guard let floor = surface else {
            return FloorDimension(
                area: 0,
                boundingWidth: 0,
                boundingLength: 0,
                polygonCorners: [],
                center: .zero
            )
        }

        let corners = floor.polygonCorners
        let area = calculatePolygonArea(corners)
        let center = simd_float3(
            floor.transform.columns.3.x,
            floor.transform.columns.3.y,
            floor.transform.columns.3.z
        )

        return FloorDimension(
            area: area > 0 ? area : floor.dimensions.x * floor.dimensions.z,
            boundingWidth: floor.dimensions.x,
            boundingLength: floor.dimensions.z,
            polygonCorners: corners,
            center: center
        )
    }

    private func processCeiling(walls: [WallDimension]) -> CeilingDimension {
        // Estimate ceiling height from wall heights
        let height: Float
        if let firstWall = walls.first {
            height = firstWall.height
        } else {
            height = 2.4 // Default ceiling height
        }

        // Estimate ceiling area from walls (simplified)
        let totalWallArea = walls.reduce(0) { $0 + $1.area }
        let estimatedCeilingArea = totalWallArea / 4.0 // Rough approximation

        return CeilingDimension(
            area: estimatedCeilingArea,
            height: abs(height),
            polygonCorners: []
        )
    }

    private func processDoors(_ doors: [CapturedRoom.Surface]) -> [OpeningDimension] {
        doors.map { door in
            OpeningDimension(
                id: door.identifier,
                type: .door,
                width: door.dimensions.x,
                height: door.dimensions.y,
                area: door.dimensions.x * door.dimensions.y,
                transform: door.transform,
                parentWallID: door.parentIdentifier
            )
        }
    }

    private func processWindows(_ windows: [CapturedRoom.Surface]) -> [OpeningDimension] {
        windows.map { window in
            OpeningDimension(
                id: window.identifier,
                type: .window,
                width: window.dimensions.x,
                height: window.dimensions.y,
                area: window.dimensions.x * window.dimensions.y,
                transform: window.transform,
                parentWallID: window.parentIdentifier
            )
        }
    }

    // MARK: - Geometry Calculations

    /// Calculate polygon area using Shoelace formula (for floor plan in XZ plane)
    private func calculatePolygonArea(_ corners: [simd_float3]) -> Float {
        guard corners.count >= 3 else { return 0 }

        var area: Float = 0
        let n = corners.count

        for i in 0..<n {
            let j = (i + 1) % n
            // Using x and z for floor plan (horizontal plane)
            area += corners[i].x * corners[j].z
            area -= corners[j].x * corners[i].z
        }

        return abs(area) / 2.0
    }

    /// Calculate bounding box from polygon corners
    func calculateBoundingBox(_ corners: [simd_float3]) -> (min: simd_float3, max: simd_float3)? {
        guard !corners.isEmpty else { return nil }

        var minPoint = corners[0]
        var maxPoint = corners[0]

        for corner in corners {
            minPoint = simd_min(minPoint, corner)
            maxPoint = simd_max(maxPoint, corner)
        }

        return (minPoint, maxPoint)
    }
}

// MARK: - Unit Conversion Extension

extension CapturedRoomProcessor.RoomDimensions {

    /// Measurement unit options
    enum MeasurementUnit {
        case meters
        case feet
        case inches

        var abbreviation: String {
            switch self {
            case .meters: return "m"
            case .feet: return "ft"
            case .inches: return "in"
            }
        }

        var conversionFromMeters: Float {
            switch self {
            case .meters: return 1.0
            case .feet: return 3.28084
            case .inches: return 39.3701
            }
        }
    }

    /// Convert dimension to specified unit
    func convert(_ meters: Float, to unit: MeasurementUnit) -> Float {
        meters * unit.conversionFromMeters
    }

    /// Format dimension with unit
    func format(_ meters: Float, unit: MeasurementUnit, decimals: Int = 2) -> String {
        let converted = convert(meters, to: unit)
        return String(format: "%.\(decimals)f %@", converted, unit.abbreviation)
    }

    /// Format area with unit
    func formatArea(_ squareMeters: Float, unit: MeasurementUnit, decimals: Int = 2) -> String {
        let factor = unit.conversionFromMeters
        let converted = squareMeters * factor * factor
        return String(format: "%.\(decimals)f %@\u{00B2}", converted, unit.abbreviation)
    }

    /// Format volume with unit
    func formatVolume(_ cubicMeters: Float, unit: MeasurementUnit, decimals: Int = 2) -> String {
        let factor = unit.conversionFromMeters
        let converted = cubicMeters * factor * factor * factor
        return String(format: "%.\(decimals)f %@\u{00B3}", converted, unit.abbreviation)
    }
}
