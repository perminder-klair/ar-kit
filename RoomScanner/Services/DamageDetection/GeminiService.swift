import Combine
import Foundation
import UIKit

/// Service for interacting with Google Gemini Vision API
@MainActor
final class GeminiService: ObservableObject {

    // MARK: - Error Types

    enum GeminiError: LocalizedError {
        case invalidAPIKey
        case invalidImageData
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case rateLimited
        case quotaExceeded
        case imageTooLarge
        case parsingError(String)

        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid or missing Gemini API key"
            case .invalidImageData:
                return "Unable to process image data"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from Gemini API"
            case .apiError(let message):
                return "API error: \(message)"
            case .rateLimited:
                return "Rate limited. Please try again later"
            case .quotaExceeded:
                return "API quota exceeded"
            case .imageTooLarge:
                return "Image exceeds maximum size (20MB)"
            case .parsingError(let message):
                return "Failed to parse response: \(message)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .invalidAPIKey:
                return "Please configure your Gemini API key in the app settings"
            case .networkError:
                return "Check your internet connection and try again"
            case .rateLimited:
                return "Wait a moment before trying again"
            case .quotaExceeded:
                return "Your daily API quota has been exceeded. Try again tomorrow"
            default:
                return "Please try again"
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastError: GeminiError?

    // MARK: - Configuration

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-3-flash-preview"
    private let maxImageSizeBytes = 20 * 1024 * 1024  // 20MB
    private let session: URLSession

    private var apiKey: String? {
        GeminiConfig.shared.apiKey
    }

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Analyze a single image for damage
    func analyzeImage(_ imageData: Data, surfaceType: SurfaceType) async throws
        -> DamageAnalysisResponse
    {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        guard imageData.count <= maxImageSizeBytes else {
            throw GeminiError.imageTooLarge
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = buildDamageDetectionPrompt(surfaceType: surfaceType)
        let request = try buildRequest(imageData: imageData, prompt: prompt, apiKey: apiKey)

        do {
            let (data, response) = try await session.data(for: request)
            let rawResponse = try handleResponse(data: data, response: response)
            return try parseAnalysisResponse(rawResponse, surfaceType: surfaceType)
        } catch let error as GeminiError {
            lastError = error
            throw error
        } catch {
            let geminiError = GeminiError.networkError(error)
            lastError = geminiError
            throw geminiError
        }
    }

    /// Analyze multiple images for damage (batch)
    func analyzeImages(_ images: [CapturedImageData]) async throws -> [ImageAnalysisResult] {
        var results: [ImageAnalysisResult] = []

        for (index, image) in images.enumerated() {
            do {
                let response = try await analyzeImage(image.data, surfaceType: image.surfaceType)
                results.append(
                    ImageAnalysisResult(
                        imageIndex: index,
                        surfaceType: image.surfaceType,
                        surfaceId: image.surfaceId,
                        response: response,
                        error: nil
                    ))
            } catch {
                results.append(
                    ImageAnalysisResult(
                        imageIndex: index,
                        surfaceType: image.surfaceType,
                        surfaceId: image.surfaceId,
                        response: nil,
                        error: error
                    ))
            }

            // Rate limiting delay between requests
            if index < images.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second
            }
        }

        return results
    }

    // MARK: - Private Methods

    private func buildRequest(imageData: Data, prompt: String, apiKey: String) throws -> URLRequest
    {
        let urlString = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Image = imageData.base64EncodedString()
        let mimeType = detectMimeType(from: imageData)

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart.inlineData(InlineData(mimeType: mimeType, data: base64Image)),
                        GeminiPart.text(prompt),
                    ]
                )
            ],
            generationConfig: GenerationConfig(
                responseMimeType: "application/json"
            )
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try extractTextFromResponse(data)
        case 429:
            throw GeminiError.rateLimited
        case 403:
            throw GeminiError.quotaExceeded
        case 400...499:
            if let errorMsg = extractErrorMessage(from: data) {
                throw GeminiError.apiError(errorMsg)
            }
            throw GeminiError.invalidResponse
        default:
            throw GeminiError.invalidResponse
        }
    }

    private func extractTextFromResponse(_ data: Data) throws -> String {
        let response = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let text = response.candidates?.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        return text
    }

    private func extractErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let error: ErrorDetail?
            struct ErrorDetail: Decodable {
                let message: String?
            }
        }
        let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        return errorResponse?.error?.message
    }

    private func parseAnalysisResponse(_ text: String, surfaceType: SurfaceType) throws
        -> DamageAnalysisResponse
    {
        // Clean up the response text (remove markdown code blocks if present)
        var cleanedText = text
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        }
        if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw GeminiError.parsingError("Invalid UTF-8 data")
        }

        do {
            let response = try JSONDecoder().decode(DamageAnalysisResponse.self, from: jsonData)
            return response
        } catch {
            throw GeminiError.parsingError(error.localizedDescription)
        }
    }

    private func detectMimeType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }

        let bytes = [UInt8](data.prefix(4))

        if bytes[0] == 0x89 && bytes[1] == 0x50 {
            return "image/png"
        } else if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "image/jpeg"
        } else if bytes[0] == 0x52 && bytes[1] == 0x49 {
            return "image/webp"
        }

        return "image/jpeg"
    }

    private func buildDamageDetectionPrompt(surfaceType: SurfaceType) -> String {
        """
        Analyze this image of a room \(surfaceType.displayName.lowercased()) for any visible damage or deterioration.

        Look for these damage types:
        - Cracks (hairline, structural, settlement)
        - Water damage (stains, bubbling, warping)
        - Holes (nail holes, damage holes, missing material)
        - Weathering (sun damage, fading, discoloration)
        - Mold (visible mold, mildew, fungal growth)
        - Peeling (paint, wallpaper, surface coating)
        - Stains (discoloration, marks)
        - Structural damage (warping, buckling, sagging)

        IMPORTANT - Bounding Box Instructions:
        For each damage found, provide a PRECISE bounding box that tightly fits ONLY the damaged area:
        - x: left edge position as fraction of image width (0.0-1.0)
        - y: top edge position as fraction of image height (0.0-1.0)
        - width: damage width as fraction of image width (0.0-1.0)
        - height: damage height as fraction of image height (0.0-1.0)
        The bounding box should closely outline the damage boundaries, NOT include surrounding context.
        This is critical for accurate damage size measurement.

        Respond with a JSON object in this exact format:
        {
            "damages": [
                {
                    "type": "crack|water_damage|hole|weathering|mold|peeling|stain|structural_damage|other",
                    "severity": "low|moderate|high|critical",
                    "description": "Brief description of the damage",
                    "confidence": 0.0 to 1.0,
                    "boundingBox": {"x": 0.0-1.0, "y": 0.0-1.0, "width": 0.0-1.0, "height": 0.0-1.0},
                    "recommendation": "Suggested action"
                }
            ],
            "overallCondition": "excellent|good|fair|poor|critical",
            "summary": "Brief overall assessment"
        }

        If no damage is detected, return an empty damages array with overallCondition as "excellent" or "good".
        Be thorough but avoid false positives. Only report damage you are confident about.
        """
    }
}

// MARK: - Request/Response Models

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

enum GeminiPart: Codable {
    case text(String)
    case inlineData(InlineData)

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(value, forKey: .text)
        case .inlineData(let value):
            try container.encode(value, forKey: .inlineData)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let inlineData = try? container.decode(InlineData.self, forKey: .inlineData) {
            self = .inlineData(inlineData)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid part")
            )
        }
    }
}

struct InlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

struct GenerationConfig: Codable {
    let responseMimeType: String?
}

struct GeminiAPIResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content

        struct Content: Codable {
            let parts: [Part]

            struct Part: Codable {
                let text: String?
            }
        }
    }
}

// MARK: - Analysis Response Models

struct DamageAnalysisResponse: Codable {
    let damages: [DamageItem]
    let overallCondition: String
    let summary: String?

    struct DamageItem: Codable {
        let type: String
        let severity: String
        let description: String
        let confidence: Float
        let boundingBox: BoundingBoxData?
        let recommendation: String?

        struct BoundingBoxData: Codable {
            let x: Float
            let y: Float
            let width: Float
            let height: Float
        }
    }
}

// MARK: - Image Data Types

struct CapturedImageData {
    let data: Data
    let surfaceType: SurfaceType
    let surfaceId: UUID?
}

struct ImageAnalysisResult {
    let imageIndex: Int
    let surfaceType: SurfaceType
    let surfaceId: UUID?
    let response: DamageAnalysisResponse?
    let error: Error?

    var isSuccess: Bool {
        response != nil && error == nil
    }
}
