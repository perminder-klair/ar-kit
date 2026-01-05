import Foundation
import UIKit
import RoomPlan
import Combine

/// Service for orchestrating damage analysis workflow
@MainActor
final class DamageAnalysisService: ObservableObject {

    // MARK: - Error Types

    enum DamageAnalysisError: LocalizedError {
        case noCapturedRoom
        case noImagesProvided
        case imageCaptureFailed(String)
        case analysisTimeout
        case allImagesFailed
        case partialFailure(successCount: Int, failCount: Int)
        case geminiError(GeminiService.GeminiError)
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .noCapturedRoom:
                return "No room scan data available"
            case .noImagesProvided:
                return "No images provided for analysis"
            case .imageCaptureFailed(let reason):
                return "Image capture failed: \(reason)"
            case .analysisTimeout:
                return "Analysis timed out"
            case .allImagesFailed:
                return "All image analyses failed"
            case .partialFailure(let success, let fail):
                return "Analysis partially complete: \(success) succeeded, \(fail) failed"
            case .geminiError(let error):
                return error.errorDescription
            case .notConfigured:
                return "Damage analysis is not configured. Please add your Gemini API key."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .notConfigured:
                return "Add your API key to GeminiAPIKey.plist"
            case .allImagesFailed:
                return "Check your internet connection and try again"
            case .partialFailure:
                return "Results shown are from successful analyses only"
            default:
                return "Please try again"
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var status: DamageAnalysisStatus = .idle
    @Published private(set) var analysisResult: DamageAnalysisResult?
    @Published private(set) var currentRoom: CapturedRoom?
    @Published private(set) var pendingImages: [CapturedImageData] = []

    // MARK: - Services

    private let geminiService = GeminiService()
    private let imageCaptureHelper = ImageCaptureHelper()

    // MARK: - Configuration

    var isConfigured: Bool {
        GeminiConfig.shared.isConfigured
    }

    // MARK: - Public Methods

    /// Set the room to analyze
    func setRoom(_ room: CapturedRoom) {
        currentRoom = room
        analysisResult = nil
        status = .idle
    }

    /// Add image for analysis
    func addImage(_ image: UIImage, surfaceType: SurfaceType, surfaceId: UUID? = nil) {
        if let imageData = imageCaptureHelper.createCapturedImageData(
            from: image,
            surfaceType: surfaceType,
            surfaceId: surfaceId
        ) {
            pendingImages.append(imageData)
        }
    }

    /// Add image data for analysis
    func addImageData(_ data: Data, surfaceType: SurfaceType, surfaceId: UUID? = nil) {
        if let imageData = imageCaptureHelper.createCapturedImageData(
            from: data,
            surfaceType: surfaceType,
            surfaceId: surfaceId
        ) {
            pendingImages.append(imageData)
        }
    }

    /// Clear pending images
    func clearPendingImages() {
        pendingImages.removeAll()
    }

    /// Start analysis with pending images
    func analyzeWithPendingImages() async throws -> DamageAnalysisResult {
        guard !pendingImages.isEmpty else {
            throw DamageAnalysisError.noImagesProvided
        }
        return try await analyze(images: pendingImages)
    }

    /// Analyze provided images for damage
    func analyze(images: [CapturedImageData]) async throws -> DamageAnalysisResult {
        guard isConfigured else {
            throw DamageAnalysisError.notConfigured
        }

        guard !images.isEmpty else {
            throw DamageAnalysisError.noImagesProvided
        }

        let startTime = Date()
        status = .analyzing(progress: 0)

        // Analyze images
        let results = try await analyzeImagesWithProgress(images)

        // Process results
        let (detectedDamages, overallCondition) = processResults(results, images: images)

        let processingTime = Date().timeIntervalSince(startTime)

        let result = DamageAnalysisResult(
            roomScanId: nil,
            detectedDamages: detectedDamages,
            overallCondition: overallCondition,
            analyzedImageCount: images.count,
            processingTimeSeconds: processingTime
        )

        self.analysisResult = result
        self.status = .completed
        self.pendingImages.removeAll()

        return result
    }

    /// Analyze room with provided images
    func analyzeRoom(_ room: CapturedRoom, images: [CapturedImageData]) async throws -> DamageAnalysisResult {
        setRoom(room)

        guard isConfigured else {
            throw DamageAnalysisError.notConfigured
        }

        guard !images.isEmpty else {
            throw DamageAnalysisError.noImagesProvided
        }

        let result = try await analyze(images: images)

        // Update result with room scan ID
        let updatedResult = DamageAnalysisResult(
            id: result.id,
            analysisDate: result.analysisDate,
            roomScanId: nil, // CapturedRoom doesn't have an ID - could add one to RoomScanResult
            detectedDamages: result.detectedDamages,
            overallCondition: result.overallCondition,
            analyzedImageCount: result.analyzedImageCount,
            processingTimeSeconds: result.processingTimeSeconds
        )

        self.analysisResult = updatedResult
        return updatedResult
    }

    /// Reset the service state
    func reset() {
        status = .idle
        analysisResult = nil
        currentRoom = nil
        pendingImages.removeAll()
    }

    // MARK: - Private Methods

    private func analyzeImagesWithProgress(_ images: [CapturedImageData]) async throws -> [ImageAnalysisResult] {
        var results: [ImageAnalysisResult] = []
        let totalImages = Float(images.count)

        for (index, image) in images.enumerated() {
            // Update progress
            status = .analyzing(progress: Float(index) / totalImages)

            do {
                let response = try await geminiService.analyzeImage(image.data, surfaceType: image.surfaceType)
                results.append(ImageAnalysisResult(
                    imageIndex: index,
                    surfaceType: image.surfaceType,
                    surfaceId: image.surfaceId,
                    response: response,
                    error: nil
                ))
            } catch {
                results.append(ImageAnalysisResult(
                    imageIndex: index,
                    surfaceType: image.surfaceType,
                    surfaceId: image.surfaceId,
                    response: nil,
                    error: error
                ))
            }

            // Rate limiting delay between requests
            if index < images.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
        }

        // Check if all failed
        let successCount = results.filter { $0.isSuccess }.count
        if successCount == 0 {
            if let firstError = results.first?.error as? GeminiService.GeminiError {
                throw DamageAnalysisError.geminiError(firstError)
            }
            throw DamageAnalysisError.allImagesFailed
        }

        return results
    }

    private func processResults(_ results: [ImageAnalysisResult], images: [CapturedImageData]) -> ([DetectedDamage], OverallCondition) {
        var allDamages: [DetectedDamage] = []
        var conditions: [OverallCondition] = []

        for result in results where result.isSuccess {
            guard let response = result.response else { continue }

            // Convert damage items to DetectedDamage
            for damageItem in response.damages {
                let damage = convertToDamage(
                    damageItem,
                    surfaceType: result.surfaceType,
                    surfaceId: result.surfaceId,
                    imageIndex: result.imageIndex
                )
                allDamages.append(damage)
            }

            // Track conditions for overall assessment
            if let condition = OverallCondition(rawValue: response.overallCondition) {
                conditions.append(condition)
            }
        }

        // Determine overall condition (worst case)
        let overallCondition = determineOverallCondition(from: conditions, damages: allDamages)

        return (allDamages, overallCondition)
    }

    private func convertToDamage(
        _ item: DamageAnalysisResponse.DamageItem,
        surfaceType: SurfaceType,
        surfaceId: UUID?,
        imageIndex: Int
    ) -> DetectedDamage {
        let damageType = DamageType(rawValue: item.type) ?? .other
        let severity = DamageSeverity(rawValue: item.severity) ?? .low

        var boundingBox: DamageBoundingBox?
        if let box = item.boundingBox {
            boundingBox = DamageBoundingBox(
                x: box.x,
                y: box.y,
                width: box.width,
                height: box.height
            )
        }

        return DetectedDamage(
            type: damageType,
            severity: severity,
            description: item.description,
            surfaceType: surfaceType,
            surfaceId: surfaceId,
            confidence: item.confidence,
            boundingBox: boundingBox,
            recommendation: item.recommendation,
            imageIndex: imageIndex
        )
    }

    private func determineOverallCondition(from conditions: [OverallCondition], damages: [DetectedDamage]) -> OverallCondition {
        // If no damages found, return best condition from responses
        if damages.isEmpty {
            return conditions.min(by: { conditionPriority($0) < conditionPriority($1) }) ?? .excellent
        }

        // If critical damages exist, condition is critical
        if damages.contains(where: { $0.severity == .critical }) {
            return .critical
        }

        // If high severity damages exist, condition is poor
        if damages.contains(where: { $0.severity == .high }) {
            return .poor
        }

        // If moderate damages exist, condition is fair
        if damages.contains(where: { $0.severity == .moderate }) {
            return .fair
        }

        // Only low severity damages
        return .good
    }

    private func conditionPriority(_ condition: OverallCondition) -> Int {
        switch condition {
        case .excellent: return 0
        case .good: return 1
        case .fair: return 2
        case .poor: return 3
        case .critical: return 4
        }
    }
}
