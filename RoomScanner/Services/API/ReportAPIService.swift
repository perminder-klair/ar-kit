import Foundation

// MARK: - Payload Structures

struct ReportPayload: Codable {
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
    ///   - dimensions: Room dimensions from the scan
    ///   - damageResult: Optional damage analysis result
    /// - Returns: The created report ID
    func saveReport(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageResult: DamageAnalysisResult?
    ) async throws -> String {
        let payload = buildPayload(dimensions: dimensions, damageResult: damageResult)
        return try await postReport(payload: payload)
    }

    // MARK: - Private Methods

    private func buildPayload(
        dimensions: CapturedRoomProcessor.RoomDimensions,
        damageResult: DamageAnalysisResult?
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
            damages: damages
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
