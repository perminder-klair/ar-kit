import Foundation

// MARK: - Payload Structures

struct ReportPayload: Codable {
    let userName: String
    let scanDate: String  // ISO8601
    let floorAreaM2: Float
    let wallAreaM2: Float
    let ceilingHeightM: Float
    let volumeM3: Float
    let wallCount: Int
    let doorCount: Int
    let windowCount: Int
    let overallCondition: String?
    let walls: [WallPayload]
    let doors: [OpeningPayload]
    let windows: [OpeningPayload]
    let damages: [DamagePayload]
    let telemetry: SessionTelemetry?
}

struct WallPayload: Codable {
    let name: String
    let widthM: Float
    let heightM: Float
    let areaM2: Float
    let isCurved: Bool
}

struct OpeningPayload: Codable {
    let type: String  // "door" | "window"
    let widthM: Float
    let heightM: Float
    let areaM2: Float
}

struct DamagePayload: Codable {
    let type: String
    let severity: String
    let surfaceType: String
    let wallName: String?
    let description: String
    let confidence: Float
    let recommendation: String?
    let widthM: Float?
    let heightM: Float?
    let areaM2: Float?
    let distanceM: Float?
    let measurementConfidence: Float?
}

// MARK: - API Response

struct ReportResponse: Codable {
    let id: String
    let createdAt: String
    let scanDate: String
}

struct FileUploadResponse: Codable {
    let id: String
    let blobUrl: String
    let fileName: String
}

// MARK: - API Errors

enum ReportAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        }
    }
}

// MARK: - Report API Service

actor ReportAPIService {
    static let shared = ReportAPIService()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    /// Save a report to the cloud
    /// - Parameters:
    ///   - userName: Name of the person who performed the scan
    ///   - dimensions: Room dimensions from the scan
    ///   - damageResult: Optional damage analysis result
    ///   - telemetry: Optional session telemetry for debugging
    /// - Returns: The created report ID and updated telemetry with network timing
    func saveReport(
        userName: String,
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageResult: DamageAnalysisResult?,
        telemetry: SessionTelemetry?
    ) async throws -> (reportId: String, telemetry: SessionTelemetry?) {
        var mutableTelemetry = telemetry
        mutableTelemetry?.timestamps.markUploadStarted()

        let payload = buildPayload(
            userName: userName,
            dimensions: dimensions,
            damageResult: damageResult,
            telemetry: mutableTelemetry
        )

        let startTime = Date()
        let reportId = try await postReport(payload: payload)

        // Update telemetry with network timing
        if var t = mutableTelemetry {
            t.timestamps.markUploadEnded()
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
            t.network.reportUploadDurationMs = durationMs
            if let payloadData = try? encoder.encode(payload) {
                t.network.reportPayloadSizeBytes = payloadData.count
            }
            mutableTelemetry = t
        }

        return (reportId, mutableTelemetry)
    }

    /// Upload a file to the report
    /// - Parameters:
    ///   - reportId: The report ID to attach the file to
    ///   - data: The file data
    ///   - fileName: The name of the file
    ///   - fileType: Either "damage_image" or "model_usdz"
    func uploadFile(
        reportId: String,
        data: Data,
        fileName: String,
        fileType: String
    ) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/reports/\(reportId)/upload") else {
            throw ReportAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add fileType field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"fileType\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fileType)\r\n".data(using: .utf8)!)

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)

        let mimeType: String
        switch fileType {
        case "model_usdz":
            mimeType = "model/vnd.usdz+zip"
        case "model_glb":
            mimeType = "model/gltf-binary"
        default:
            mimeType = "image/jpeg"
        }
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReportAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ReportAPIError.serverError(httpResponse.statusCode, "File upload failed")
        }
    }

    /// Upload damage images from captured frames
    func uploadDamageImages(reportId: String, frames: [CapturedFrame]) async throws {
        for (index, frame) in frames.enumerated() {
            let fileName = "damage_\(index + 1).jpg"
            try await uploadFile(
                reportId: reportId,
                data: frame.imageData,
                fileName: fileName,
                fileType: "damage_image"
            )
        }
    }

    /// Upload USDZ model file
    func uploadModel(reportId: String, modelURL: URL) async throws {
        let data = try Data(contentsOf: modelURL)
        let fileName = modelURL.lastPathComponent
        try await uploadFile(
            reportId: reportId,
            data: data,
            fileName: fileName,
            fileType: "model_usdz"
        )
    }

    // MARK: - Private Methods

    private func buildPayload(
        userName: String,
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageResult: DamageAnalysisResult?,
        telemetry: SessionTelemetry?
    ) -> ReportPayload {
        // Build wall payloads
        let walls = dimensions.walls.map { wall in
            WallPayload(
                name: wall.name,
                widthM: wall.width,
                heightM: wall.height,
                areaM2: wall.area,
                isCurved: wall.isCurved
            )
        }

        // Build door payloads
        let doors = dimensions.doors.map { door in
            OpeningPayload(
                type: "door",
                widthM: door.width,
                heightM: door.height,
                areaM2: door.area
            )
        }

        // Build window payloads
        let windows = dimensions.windows.map { window in
            OpeningPayload(
                type: "window",
                widthM: window.width,
                heightM: window.height,
                areaM2: window.area
            )
        }

        // Build damage payloads
        let damages: [DamagePayload]
        if let result = damageResult {
            damages = result.detectedDamages.map { damage in
                DamagePayload(
                    type: damage.type.rawValue,
                    severity: damage.severity.rawValue,
                    surfaceType: damage.surfaceType.rawValue,
                    wallName: damage.wallName,
                    description: damage.description,
                    confidence: damage.confidence,
                    recommendation: damage.recommendation,
                    widthM: damage.realWidth,
                    heightM: damage.realHeight,
                    areaM2: damage.realArea,
                    distanceM: damage.distanceFromCamera,
                    measurementConfidence: damage.measurementConfidence
                )
            }
        } else {
            damages = []
        }

        // Format date as ISO8601
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let scanDateString = dateFormatter.string(from: Date())

        return ReportPayload(
            userName: userName,
            scanDate: scanDateString,
            floorAreaM2: dimensions.totalFloorArea,
            wallAreaM2: dimensions.totalWallArea,
            ceilingHeightM: dimensions.ceilingHeight,
            volumeM3: dimensions.roomVolume,
            wallCount: dimensions.wallCount,
            doorCount: dimensions.doorCount,
            windowCount: dimensions.windowCount,
            overallCondition: damageResult?.overallCondition.rawValue,
            walls: walls,
            doors: doors,
            windows: windows,
            damages: damages,
            telemetry: telemetry
        )
    }

    private func postReport(payload: ReportPayload) async throws -> String {
        var request = URLRequest(url: APIConfig.reportsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw ReportAPIError.networkError(error)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReportAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw ReportAPIError.serverError(httpResponse.statusCode, errorMessage)
        }

        // Parse response to get ID
        do {
            let response = try decoder.decode(ReportResponse.self, from: data)
            return response.id
        } catch {
            throw ReportAPIError.invalidResponse
        }
    }
}
