import Foundation
import RoomPlan
import PDFKit
import UIKit

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
        try exportPDF(dimensions: dimensions, capturedRoom: capturedRoom, damageAnalysis: nil)
    }

    /// Export as PDF report with damage analysis
    func exportPDF(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        capturedRoom: CapturedRoom,
        damageAnalysis: DamageAnalysisResult?
    ) throws -> URL {
        let pdfData = generatePDFData(dimensions: dimensions, capturedRoom: capturedRoom, damageAnalysis: damageAnalysis)

        let filename = generateFilename(extension: "pdf")
        let url = exportDirectory.appendingPathComponent(filename)

        do {
            try pdfData.write(to: url)
            return url
        } catch {
            throw ExportError.fileCreationFailed
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
        damageAnalysis: DamageAnalysisResult? = nil
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
                        pageRect: pageRect
                    )
                }

                if !highDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "HIGH PRIORITY",
                        damages: highDamages,
                        at: yOffset,
                        color: .systemOrange,
                        context: context,
                        pageRect: pageRect
                    )
                }

                if !moderateDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "MODERATE",
                        damages: moderateDamages,
                        at: yOffset,
                        color: .systemYellow,
                        context: context,
                        pageRect: pageRect
                    )
                }

                if !lowDamages.isEmpty {
                    yOffset = drawDamageSection(
                        title: "LOW PRIORITY",
                        damages: lowDamages,
                        at: yOffset,
                        color: .systemGreen,
                        context: context,
                        pageRect: pageRect
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
        pageRect: CGRect
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
            // Check if we need a new page
            if currentY > pageRect.height - 80 {
                context.beginPage()
                currentY = 50
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

            currentY += 5
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
