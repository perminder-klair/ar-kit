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
        let exportData = createExportData(from: dimensions)

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
        let pdfData = generatePDFData(dimensions: dimensions, capturedRoom: capturedRoom)

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

    private func createExportData(from dimensions: CapturedRoomProcessor.RoomDimensions) -> RoomExportData {
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

        return RoomExportData(
            exportDate: Date(),
            roomDimensions: roomData,
            surfaces: surfaces
        )
    }

    private func generatePDFData(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        capturedRoom: CapturedRoom
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
