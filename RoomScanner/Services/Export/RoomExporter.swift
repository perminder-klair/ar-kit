import Foundation
import RoomPlan
import PDFKit
import UIKit
import simd

/// Service for exporting room data in various formats
final class RoomExporter {

    // MARK: - Types

    enum ExportError: LocalizedError {
        case exportFailed(String)
        case fileCreationFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .exportFailed(let message):
                return "Export failed: \(message)"
            case .fileCreationFailed:
                return "Failed to create export file"
            case .encodingFailed:
                return "Failed to encode data"
            }
        }
    }

    // MARK: - Three.js Export Types

    struct ThreeJSExportData: Codable {
        let version: String
        let unit: String
        let exportDate: Date
        let room: ThreeJSRoomInfo
        let surfaces: [ThreeJSSurface]
        let damages: [ThreeJSDamage]
    }

    struct ThreeJSRoomInfo: Codable {
        let boundingBox: ThreeJSBoundingBox
        let floorArea: Float
        let wallArea: Float
        let ceilingHeight: Float
        let volume: Float
    }

    struct ThreeJSBoundingBox: Codable {
        let min: [Float]
        let max: [Float]
    }

    struct ThreeJSSurface: Codable {
        let id: String
        let type: String
        let vertices: [[Float]]
        let transform: [Float]
        let dimensions: ThreeJSDimensions
        let parentId: String?
        let confidence: String
    }

    struct ThreeJSDimensions: Codable {
        let width: Float
        let height: Float
        let depth: Float
    }

    struct ThreeJSDamage: Codable {
        let id: String
        let type: String
        let severity: String
        let position: [Float]
        let surfaceId: String?
        let surfaceType: String
        let measurements: ThreeJSMeasurements?
        let confidence: Float
        let description: String
        let recommendation: String?
    }

    struct ThreeJSMeasurements: Codable {
        let width: Float
        let height: Float
        let area: Float
    }

    struct RoomExportData: Codable {
        let exportDate: Date
        let roomDimensions: RoomDimensionsData
        let surfaces: SurfacesData
        let damageAnalysis: DamageAnalysisData?

        struct RoomDimensionsData: Codable {
            let floorAreaM2: Float
            let wallAreaM2: Float
            let ceilingHeightM: Float
            let volumeM3: Float
        }

        struct SurfacesData: Codable {
            let walls: [WallData]
            let doors: [OpeningData]
            let windows: [OpeningData]

            struct WallData: Codable {
                let id: String
                let widthM: Float
                let heightM: Float
                let areaM2: Float
                let isCurved: Bool
            }

            struct OpeningData: Codable {
                let id: String
                let type: String
                let widthM: Float
                let heightM: Float
                let areaM2: Float
            }
        }

        struct DamageAnalysisData: Codable {
            let analysisDate: Date
            let overallCondition: String
            let totalDamagesFound: Int
            let criticalDamages: Int
            let highPriorityDamages: Int
            let damages: [DamageData]

            struct DamageData: Codable {
                let type: String
                let severity: String
                let surfaceType: String
                let description: String
                let confidence: Float
                let recommendation: String?
                // Size measurements (from LiDAR depth)
                let widthM: Float?
                let heightM: Float?
                let areaM2: Float?
                let distanceM: Float?
            }
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    private var exportDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDir = docs.appendingPathComponent("RoomScans", isDirectory: true)

        if !fileManager.fileExists(atPath: exportDir.path) {
            try? fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        }

        return exportDir
    }

    // MARK: - USDZ Export

    /// Export room as USDZ 3D model
    func exportUSDZ(capturedRoom: CapturedRoom) async throws -> URL {
        let filename = generateFilename(extension: "usdz")
        let url = exportDirectory.appendingPathComponent(filename)

        do {
            try capturedRoom.export(to: url, exportOptions: .mesh)
            return url
        } catch {
            throw ExportError.exportFailed(error.localizedDescription)
        }
    }

    /// Export room as USDZ with metadata
    func exportUSDZWithMetadata(capturedRoom: CapturedRoom) async throws -> (modelURL: URL, metadataURL: URL) {
        let modelFilename = generateFilename(extension: "usdz")
        let metadataFilename = generateFilename(extension: "json", suffix: "_metadata")

        let modelURL = exportDirectory.appendingPathComponent(modelFilename)
        let metadataURL = exportDirectory.appendingPathComponent(metadataFilename)

        do {
            try capturedRoom.export(
                to: modelURL,
                metadataURL: metadataURL,
                modelProvider: nil,
                exportOptions: .mesh
            )
            return (modelURL, metadataURL)
        } catch {
            throw ExportError.exportFailed(error.localizedDescription)
        }
    }

    // MARK: - JSON Export

    /// Export dimensions as JSON
    func exportJSON(dimensions: CapturedRoomProcessor.RoomDimensions) throws -> URL {
        try exportJSON(dimensions: dimensions, damageAnalysis: nil)
    }

    /// Export dimensions with damage analysis as JSON
    func exportJSON(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageAnalysis: DamageAnalysisResult?
    ) throws -> URL {
        let exportData = createExportData(from: dimensions, damageAnalysis: damageAnalysis)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(exportData) else {
            throw ExportError.encodingFailed
        }

        let filename = generateFilename(extension: "json")
        let url = exportDirectory.appendingPathComponent(filename)

        do {
            try jsonData.write(to: url)
            return url
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    // MARK: - PDF Export

    /// Export as PDF report
    func exportPDF(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        capturedRoom: CapturedRoom
    ) throws -> URL {
        try exportPDF(dimensions: dimensions, capturedRoom: capturedRoom, damageAnalysis: nil, capturedFrames: [])
    }

    /// Export as PDF report with damage analysis
    func exportPDF(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        capturedRoom: CapturedRoom,
        damageAnalysis: DamageAnalysisResult?,
        capturedFrames: [CapturedFrame] = []
    ) throws -> URL {
        let pdfData = generatePDFData(dimensions: dimensions, capturedRoom: capturedRoom, damageAnalysis: damageAnalysis, capturedFrames: capturedFrames)

        let filename = generateFilename(extension: "pdf")
        let url = exportDirectory.appendingPathComponent(filename)

        do {
            try pdfData.write(to: url)
            return url
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    // MARK: - Three.js JSON Export

    /// Export room geometry and damages as Three.js compatible JSON
    func exportThreeJS(
        capturedRoom: CapturedRoom,
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageAnalysis: DamageAnalysisResult?,
        capturedFrames: [CapturedFrame] = []
    ) throws -> URL {
        let exportData = createThreeJSExportData(
            capturedRoom: capturedRoom,
            dimensions: dimensions,
            damageAnalysis: damageAnalysis,
            capturedFrames: capturedFrames
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(exportData) else {
            throw ExportError.encodingFailed
        }

        let filename = generateFilename(extension: "json", suffix: "_threejs")
        let url = exportDirectory.appendingPathComponent(filename)

        do {
            try jsonData.write(to: url)
            return url
        } catch {
            throw ExportError.fileCreationFailed
        }
    }

    private func createThreeJSExportData(
        capturedRoom: CapturedRoom,
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageAnalysis: DamageAnalysisResult?,
        capturedFrames: [CapturedFrame]
    ) -> ThreeJSExportData {
        // Calculate bounding box from all surfaces
        var allCorners: [simd_float3] = []
        allCorners.append(contentsOf: dimensions.floor.polygonCorners)
        for wall in dimensions.walls {
            allCorners.append(contentsOf: wall.polygonCorners)
        }

        let boundingBox: ThreeJSBoundingBox
        if let (minPt, maxPt) = CapturedRoomProcessor().calculateBoundingBox(allCorners) {
            boundingBox = ThreeJSBoundingBox(
                min: [minPt.x, minPt.y, minPt.z],
                max: [maxPt.x, maxPt.y, maxPt.z]
            )
        } else {
            boundingBox = ThreeJSBoundingBox(min: [0, 0, 0], max: [0, 0, 0])
        }

        let roomInfo = ThreeJSRoomInfo(
            boundingBox: boundingBox,
            floorArea: dimensions.totalFloorArea,
            wallArea: dimensions.totalWallArea,
            ceilingHeight: dimensions.ceilingHeight,
            volume: dimensions.roomVolume
        )

        // Extract surfaces with geometry
        var surfaces: [ThreeJSSurface] = []

        // Floor
        if !dimensions.floor.polygonCorners.isEmpty {
            surfaces.append(ThreeJSSurface(
                id: "floor",
                type: "floor",
                vertices: dimensions.floor.polygonCorners.map { [$0.x, $0.y, $0.z] },
                transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
                           dimensions.floor.center.x, dimensions.floor.center.y, dimensions.floor.center.z, 1],
                dimensions: ThreeJSDimensions(
                    width: dimensions.floor.boundingWidth,
                    height: 0,
                    depth: dimensions.floor.boundingLength
                ),
                parentId: nil,
                confidence: "high"
            ))
        }

        // Walls
        for wall in dimensions.walls {
            let transform = wall.transform
            let transformArray: [Float] = [
                transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
                transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
                transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
                transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
            ]

            surfaces.append(ThreeJSSurface(
                id: wall.id.uuidString,
                type: "wall",
                vertices: wall.polygonCorners.map { [$0.x, $0.y, $0.z] },
                transform: transformArray,
                dimensions: ThreeJSDimensions(width: wall.width, height: wall.height, depth: 0.1),
                parentId: nil,
                confidence: confidenceToString(wall.confidence)
            ))
        }

        // Doors
        for (index, door) in capturedRoom.doors.enumerated() {
            let transform = door.transform
            let transformArray: [Float] = [
                transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
                transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
                transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
                transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
            ]

            surfaces.append(ThreeJSSurface(
                id: door.identifier.uuidString,
                type: "door",
                vertices: door.polygonCorners.map { [$0.x, $0.y, $0.z] },
                transform: transformArray,
                dimensions: ThreeJSDimensions(
                    width: index < dimensions.doors.count ? dimensions.doors[index].width : door.dimensions.x,
                    height: index < dimensions.doors.count ? dimensions.doors[index].height : door.dimensions.y,
                    depth: door.dimensions.z
                ),
                parentId: door.parentIdentifier?.uuidString,
                confidence: confidenceToString(door.confidence)
            ))
        }

        // Windows
        for (index, window) in capturedRoom.windows.enumerated() {
            let transform = window.transform
            let transformArray: [Float] = [
                transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w,
                transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w,
                transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
                transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w
            ]

            surfaces.append(ThreeJSSurface(
                id: window.identifier.uuidString,
                type: "window",
                vertices: window.polygonCorners.map { [$0.x, $0.y, $0.z] },
                transform: transformArray,
                dimensions: ThreeJSDimensions(
                    width: index < dimensions.windows.count ? dimensions.windows[index].width : window.dimensions.x,
                    height: index < dimensions.windows.count ? dimensions.windows[index].height : window.dimensions.y,
                    depth: window.dimensions.z
                ),
                parentId: window.parentIdentifier?.uuidString,
                confidence: confidenceToString(window.confidence)
            ))
        }

        // Extract damages with 3D positions
        var damages: [ThreeJSDamage] = []
        if let analysis = damageAnalysis {
            let positionCalculator = DamagePositionCalculator()
            let damagePositions = positionCalculator.calculatePositionsWithCameraTransforms(
                damages: analysis.detectedDamages,
                frames: capturedFrames,
                room: capturedRoom,
                ceilingHeight: dimensions.ceilingHeight
            )

            for damage in analysis.detectedDamages {
                let position = damagePositions.first { $0.damageId == damage.id }
                let pos = position?.position ?? simd_float3(0, 0, 0)

                var measurements: ThreeJSMeasurements?
                if let w = damage.realWidth, let h = damage.realHeight, let a = damage.realArea {
                    measurements = ThreeJSMeasurements(width: w, height: h, area: a)
                }

                damages.append(ThreeJSDamage(
                    id: damage.id.uuidString,
                    type: damage.type.rawValue,
                    severity: damage.severity.rawValue,
                    position: [pos.x, pos.y, pos.z],
                    surfaceId: damage.surfaceId?.uuidString,
                    surfaceType: damage.surfaceType.rawValue,
                    measurements: measurements,
                    confidence: damage.confidence,
                    description: damage.description,
                    recommendation: damage.recommendation
                ))
            }
        }

        return ThreeJSExportData(
            version: "1.0",
            unit: "meters",
            exportDate: Date(),
            room: roomInfo,
            surfaces: surfaces,
            damages: damages
        )
    }

    private func confidenceToString(_ confidence: CapturedRoom.Confidence) -> String {
        switch confidence {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Private Methods

    private func generateFilename(extension ext: String, suffix: String = "") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "RoomScan_\(timestamp)\(suffix).\(ext)"
    }

    private func createExportData(
        from dimensions: CapturedRoomProcessor.RoomDimensions,
        damageAnalysis: DamageAnalysisResult? = nil
    ) -> RoomExportData {
        let roomData = RoomExportData.RoomDimensionsData(
            floorAreaM2: dimensions.totalFloorArea,
            wallAreaM2: dimensions.totalWallArea,
            ceilingHeightM: dimensions.ceilingHeight,
            volumeM3: dimensions.roomVolume
        )

        let walls = dimensions.walls.map { wall in
            RoomExportData.SurfacesData.WallData(
                id: wall.id.uuidString,
                widthM: wall.width,
                heightM: wall.height,
                areaM2: wall.area,
                isCurved: wall.isCurved
            )
        }

        let doors = dimensions.doors.map { door in
            RoomExportData.SurfacesData.OpeningData(
                id: door.id.uuidString,
                type: "door",
                widthM: door.width,
                heightM: door.height,
                areaM2: door.area
            )
        }

        let windows = dimensions.windows.map { window in
            RoomExportData.SurfacesData.OpeningData(
                id: window.id.uuidString,
                type: "window",
                widthM: window.width,
                heightM: window.height,
                areaM2: window.area
            )
        }

        let surfaces = RoomExportData.SurfacesData(
            walls: walls,
            doors: doors,
            windows: windows
        )

        // Create damage analysis data if available
        var damageData: RoomExportData.DamageAnalysisData?
        if let analysis = damageAnalysis {
            let damages = analysis.detectedDamages.map { damage in
                RoomExportData.DamageAnalysisData.DamageData(
                    type: damage.type.rawValue,
                    severity: damage.severity.rawValue,
                    surfaceType: damage.surfaceType.rawValue,
                    description: damage.description,
                    confidence: damage.confidence,
                    recommendation: damage.recommendation,
                    widthM: damage.realWidth,
                    heightM: damage.realHeight,
                    areaM2: damage.realArea,
                    distanceM: damage.distanceFromCamera
                )
            }

            damageData = RoomExportData.DamageAnalysisData(
                analysisDate: analysis.analysisDate,
                overallCondition: analysis.overallCondition.rawValue,
                totalDamagesFound: analysis.detectedDamages.count,
                criticalDamages: analysis.criticalCount,
                highPriorityDamages: analysis.highPriorityCount,
                damages: damages
            )
        }

        return RoomExportData(
            exportDate: Date(),
            roomDimensions: roomData,
            surfaces: surfaces,
            damageAnalysis: damageData
        )
    }

    private func generatePDFData(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        capturedRoom: CapturedRoom,
        damageAnalysis: DamageAnalysisResult? = nil,
        capturedFrames: [CapturedFrame] = []
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yOffset: CGFloat = 50

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let title = "Room Inspection Report"
            title.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: [.font: titleFont])
            yOffset += 40

            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateString = "Generated: \(dateFormatter.string(from: Date()))"
            dateString.draw(
                at: CGPoint(x: 50, y: yOffset),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray]
            )
            yOffset += 40

            // Room Summary Section
            yOffset = drawSection(
                title: "Room Summary",
                at: yOffset,
                in: context.cgContext
            )

            let summaryItems = [
                ("Floor Area", String(format: "%.2f m\u{00B2}", dimensions.totalFloorArea)),
                ("Wall Area", String(format: "%.2f m\u{00B2}", dimensions.totalWallArea)),
                ("Ceiling Height", String(format: "%.2f m", dimensions.ceilingHeight)),
                ("Volume", String(format: "%.2f m\u{00B3}", dimensions.roomVolume))
            ]

            for (label, value) in summaryItems {
                yOffset = drawLabelValue(label: label, value: value, at: yOffset)
            }

            yOffset += 20

            // Surfaces Section
            yOffset = drawSection(
                title: "Detected Surfaces",
                at: yOffset,
                in: context.cgContext
            )

            let surfaceItems = [
                ("Walls", "\(dimensions.wallCount)"),
                ("Doors", "\(dimensions.doorCount)"),
                ("Windows", "\(dimensions.windowCount)")
            ]

            for (label, value) in surfaceItems {
                yOffset = drawLabelValue(label: label, value: value, at: yOffset)
            }

            yOffset += 20

            // Wall Details
            if !dimensions.walls.isEmpty {
                yOffset = drawSection(
                    title: "Wall Measurements",
                    at: yOffset,
                    in: context.cgContext
                )

                for (index, wall) in dimensions.walls.prefix(10).enumerated() {
                    let wallInfo = String(
                        format: "Wall %d: %.2f m × %.2f m (%.2f m\u{00B2})",
                        index + 1,
                        wall.width,
                        wall.height,
                        wall.area
                    )
                    wallInfo.draw(
                        at: CGPoint(x: 70, y: yOffset),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 11)]
                    )
                    yOffset += 18
                }

                if dimensions.walls.count > 10 {
                    let moreText = "... and \(dimensions.walls.count - 10) more walls"
                    moreText.draw(
                        at: CGPoint(x: 70, y: yOffset),
                        withAttributes: [
                            .font: UIFont.italicSystemFont(ofSize: 11),
                            .foregroundColor: UIColor.gray
                        ]
                    )
                    yOffset += 18
                }
            }

            // Damage Analysis Section
            if let damage = damageAnalysis {
                yOffset += 20

                // Check if we need a new page
                if yOffset > pageRect.height - 200 {
                    context.beginPage()
                    yOffset = 50
                }

                yOffset = drawSection(
                    title: "Damage Assessment",
                    at: yOffset,
                    in: context.cgContext
                )

                // Overall condition
                let conditionColor = damageConditionColor(damage.overallCondition)
                yOffset = drawLabelValueWithColor(
                    label: "Overall Condition",
                    value: damage.overallCondition.displayName.uppercased(),
                    at: yOffset,
                    valueColor: conditionColor
                )

                yOffset = drawLabelValue(label: "Total Issues Found", value: "\(damage.detectedDamages.count)", at: yOffset)
                yOffset = drawLabelValue(label: "Critical Issues", value: "\(damage.criticalCount)", at: yOffset)
                yOffset = drawLabelValue(label: "High Priority", value: "\(damage.highPriorityCount)", at: yOffset)

                yOffset += 10

                // List damages by severity
                let criticalDamages = damage.detectedDamages.filter { $0.severity == .critical }
                let highDamages = damage.detectedDamages.filter { $0.severity == .high }
                let moderateDamages = damage.detectedDamages.filter { $0.severity == .moderate }
                let lowDamages = damage.detectedDamages.filter { $0.severity == .low }

                if !criticalDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "CRITICAL ISSUES",
                        damages: criticalDamages,
                        at: yOffset,
                        color: .systemRed,
                        context: context,
                        pageRect: pageRect,
                        capturedFrames: capturedFrames
                    )
                }

                if !highDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "HIGH PRIORITY",
                        damages: highDamages,
                        at: yOffset,
                        color: .systemOrange,
                        context: context,
                        pageRect: pageRect,
                        capturedFrames: capturedFrames
                    )
                }

                if !moderateDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "MODERATE",
                        damages: moderateDamages,
                        at: yOffset,
                        color: .systemYellow,
                        context: context,
                        pageRect: pageRect,
                        capturedFrames: capturedFrames
                    )
                }

                if !lowDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "LOW PRIORITY",
                        damages: lowDamages,
                        at: yOffset,
                        color: .systemGreen,
                        context: context,
                        pageRect: pageRect,
                        capturedFrames: capturedFrames
                    )
                }
            }

            // Footer
            let footerY = pageRect.height - 40
            let footer = "Generated by Room Scanner App"
            let footerWidth = footer.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)]).width
            footer.draw(
                at: CGPoint(x: (pageRect.width - footerWidth) / 2, y: footerY),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
            )
        }

        return data
    }

    private func damageConditionColor(_ condition: OverallCondition) -> UIColor {
        switch condition {
        case .excellent: return .systemGreen
        case .good: return .systemBlue
        case .fair: return .systemYellow
        case .poor: return .systemOrange
        case .critical: return .systemRed
        }
    }

    private func drawLabelValueWithColor(label: String, value: String, at yOffset: CGFloat, valueColor: UIColor) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 12)
        let valueFont = UIFont.boldSystemFont(ofSize: 12)

        label.draw(
            at: CGPoint(x: 70, y: yOffset),
            withAttributes: [.font: labelFont, .foregroundColor: UIColor.darkGray]
        )

        value.draw(
            at: CGPoint(x: 250, y: yOffset),
            withAttributes: [.font: valueFont, .foregroundColor: valueColor]
        )

        return yOffset + 20
    }

    private func drawDamageSection(
        title: String,
        damages: [DetectedDamage],
        at yOffset: CGFloat,
        color: UIColor,
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        capturedFrames: [CapturedFrame] = []
    ) -> CGFloat {
        var currentY = yOffset

        // Check if we need a new page
        if currentY > pageRect.height - 100 {
            context.beginPage()
            currentY = 50
        }

        // Section title with color indicator
        let titleFont = UIFont.boldSystemFont(ofSize: 12)
        title.draw(
            at: CGPoint(x: 70, y: currentY),
            withAttributes: [.font: titleFont, .foregroundColor: color]
        )
        currentY += 20

        for (index, damage) in damages.prefix(5).enumerated() {
            // Check if we need a new page for image + text (~280pt needed)
            if currentY > pageRect.height - 280 {
                context.beginPage()
                currentY = 50
            }

            // Draw damage image with overlay if available
            if damage.imageIndex < capturedFrames.count {
                let frame = capturedFrames[damage.imageIndex]
                currentY = drawDamageImage(
                    damage: damage,
                    frame: frame,
                    at: currentY,
                    severityColor: color,
                    pageRect: pageRect
                )
            }

            let damageTitle = "\(index + 1). \(damage.type.displayName) - \(damage.surfaceType.displayName)"
            damageTitle.draw(
                at: CGPoint(x: 90, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 11)]
            )
            currentY += 16

            // Show size measurements if available
            if damage.hasMeasurements, let dimensions = damage.formattedDimensions, let area = damage.formattedArea {
                let sizeText = "Size: \(dimensions) (\(area))"
                sizeText.draw(
                    at: CGPoint(x: 90, y: currentY),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.systemBlue]
                )
                currentY += 14
            }

            let description = damage.description
            let descriptionRect = CGRect(x: 90, y: currentY, width: 450, height: 40)
            description.draw(
                in: descriptionRect,
                withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray]
            )
            currentY += 35

            if let recommendation = damage.recommendation {
                let recText = "Recommendation: \(recommendation)"
                let recRect = CGRect(x: 90, y: currentY, width: 450, height: 30)
                recText.draw(
                    in: recRect,
                    withAttributes: [.font: UIFont.italicSystemFont(ofSize: 10), .foregroundColor: UIColor.gray]
                )
                currentY += 30
            }

            currentY += 10
        }

        if damages.count > 5 {
            let moreText = "... and \(damages.count - 5) more \(title.lowercased()) items"
            moreText.draw(
                at: CGPoint(x: 90, y: currentY),
                withAttributes: [
                    .font: UIFont.italicSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
            )
            currentY += 18
        }

        return currentY + 10
    }

    private func drawDamageImage(
        damage: DetectedDamage,
        frame: CapturedFrame,
        at yOffset: CGFloat,
        severityColor: UIColor,
        pageRect: CGRect
    ) -> CGFloat {
        guard let image = UIImage(data: frame.imageData) else {
            return yOffset
        }

        // Scale image to fit PDF width (max 250pt width, maintain aspect ratio)
        let maxWidth: CGFloat = 250
        let maxHeight: CGFloat = 180
        let imageAspect = image.size.width / image.size.height

        var drawWidth = maxWidth
        var drawHeight = drawWidth / imageAspect

        if drawHeight > maxHeight {
            drawHeight = maxHeight
            drawWidth = drawHeight * imageAspect
        }

        let imageX: CGFloat = 90
        let imageRect = CGRect(x: imageX, y: yOffset, width: drawWidth, height: drawHeight)

        // Draw the image
        image.draw(in: imageRect)

        // Draw bounding box overlay if available
        if let bbox = damage.boundingBox {
            let bboxX = imageX + CGFloat(bbox.x) * drawWidth
            let bboxY = yOffset + CGFloat(bbox.y) * drawHeight
            let bboxWidth = CGFloat(bbox.width) * drawWidth
            let bboxHeight = CGFloat(bbox.height) * drawHeight

            let bboxRect = CGRect(x: bboxX, y: bboxY, width: bboxWidth, height: bboxHeight)

            // Draw semi-transparent fill
            let fillColor = severityColor.withAlphaComponent(0.15)
            fillColor.setFill()
            UIBezierPath(rect: bboxRect).fill()

            // Draw border
            severityColor.setStroke()
            let borderPath = UIBezierPath(rect: bboxRect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Draw severity label on the bounding box
            let labelText = damage.severity.displayName.uppercased()
            let labelFont = UIFont.boldSystemFont(ofSize: 8)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: UIColor.white,
                .backgroundColor: severityColor
            ]
            let labelSize = labelText.size(withAttributes: labelAttrs)
            let labelRect = CGRect(x: bboxX, y: bboxY - labelSize.height - 2, width: labelSize.width + 4, height: labelSize.height + 2)

            severityColor.setFill()
            UIBezierPath(rect: labelRect).fill()

            labelText.draw(at: CGPoint(x: bboxX + 2, y: bboxY - labelSize.height - 1), withAttributes: [.font: labelFont, .foregroundColor: UIColor.white])
        }

        // Draw image border
        UIColor.lightGray.setStroke()
        let imageBorder = UIBezierPath(rect: imageRect)
        imageBorder.lineWidth = 0.5
        imageBorder.stroke()

        return yOffset + drawHeight + 10
    }

    private func drawSection(title: String, at yOffset: CGFloat, in context: CGContext) -> CGFloat {
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        title.draw(
            at: CGPoint(x: 50, y: yOffset),
            withAttributes: [.font: sectionFont]
        )
        return yOffset + 28
    }

    private func drawLabelValue(label: String, value: String, at yOffset: CGFloat) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 12)
        let valueFont = UIFont.boldSystemFont(ofSize: 12)

        label.draw(
            at: CGPoint(x: 70, y: yOffset),
            withAttributes: [.font: labelFont, .foregroundColor: UIColor.darkGray]
        )

        value.draw(
            at: CGPoint(x: 250, y: yOffset),
            withAttributes: [.font: valueFont]
        )

        return yOffset + 20
    }
}
