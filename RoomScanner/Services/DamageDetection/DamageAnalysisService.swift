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
    private let sizeCalculator = DamageSizeCalculator()

    // MARK: - Frame Storage for Size Calculation

    private var capturedFramesForAnalysis: [CapturedFrame] = []

    // MARK: - Wall Name Lookup

    /// Maps wall UUIDs to their human-readable names ("Wall A", "Wall B", etc.)
    private var wallNameLookup: [UUID: String] = [:]

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
        buildWallNameLookup(from: room)
    }

    /// Build wall name lookup from CapturedRoom walls
    private func buildWallNameLookup(from room: CapturedRoom) {
        wallNameLookup.removeAll()
        for (index, wall) in room.walls.enumerated() {
            wallNameLookup[wall.identifier] = wallName(for: index)
        }
    }

    /// Generate wall name from index (0 -> "Wall A", 1 -> "Wall B", etc.)
    private func wallName(for index: Int) -> String {
        let letter = Character(UnicodeScalar(65 + (index % 26))!) // A-Z
        if index < 26 {
            return "Wall \(letter)"
        } else {
            // For 26+ walls: Wall AA, Wall AB, etc.
            let prefix = Character(UnicodeScalar(65 + (index / 26 - 1))!)
            return "Wall \(prefix)\(letter)"
        }
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

    /// Analyze with captured frames that include depth data for damage size calculation
    func analyzeWithFrames(_ frames: [CapturedFrame]) async throws -> DamageAnalysisResult {
        guard isConfigured else {
            throw DamageAnalysisError.notConfigured
        }

        guard !frames.isEmpty else {
            throw DamageAnalysisError.noImagesProvided
        }

        // Store frames for size calculation during processing
        capturedFramesForAnalysis = frames

        let startTime = Date()
        status = .analyzing(progress: 0)

        // Convert frames to image data for Gemini analysis
        let images = frames.map { frame in
            CapturedImageData(
                data: frame.imageData,
                surfaceType: frame.surfaceType,
                surfaceId: nil
            )
        }

        // Analyze images
        let results = try await analyzeImagesWithProgress(images)

        // Process results with depth-based size calculation
        let (detectedDamages, overallCondition) = processResultsWithFrames(results)

        let processingTime = Date().timeIntervalSince(startTime)

        let result = DamageAnalysisResult(
            roomScanId: nil,
            detectedDamages: detectedDamages,
            overallCondition: overallCondition,
            analyzedImageCount: frames.count,
            processingTimeSeconds: processingTime
        )

        self.analysisResult = result
        self.status = .completed
        self.capturedFramesForAnalysis.removeAll()

        return result
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
        }

        // Deduplicate damages across frames (same damage may appear in multiple frames)
        let uniqueDamages = deduplicateDamages(allDamages)

        // Determine overall condition based on damage count
        let overallCondition: OverallCondition = uniqueDamages.isEmpty ? .excellent : .good

        return (uniqueDamages, overallCondition)
    }

    /// Process results with frame depth data for damage size calculation
    private func processResultsWithFrames(_ results: [ImageAnalysisResult]) -> ([DetectedDamage], OverallCondition) {
        var allDamages: [DetectedDamage] = []

        for result in results where result.isSuccess {
            guard let response = result.response else { continue }

            // Get the corresponding frame for depth data
            let frame: CapturedFrame? = result.imageIndex < capturedFramesForAnalysis.count
                ? capturedFramesForAnalysis[result.imageIndex]
                : nil

            // Convert damage items to DetectedDamage with size calculation
            for damageItem in response.damages {
                let damage = convertToDamageWithSize(
                    damageItem,
                    surfaceType: result.surfaceType,
                    surfaceId: result.surfaceId,
                    imageIndex: result.imageIndex,
                    frame: frame
                )
                allDamages.append(damage)
            }
        }

        // Deduplicate damages across frames (same damage may appear in multiple frames)
        let uniqueDamages = deduplicateDamages(allDamages)

        // Determine overall condition based on damage count
        let overallCondition: OverallCondition = uniqueDamages.isEmpty ? .excellent : .good

        return (uniqueDamages, overallCondition)
    }

    private func convertToDamage(
        _ item: DamageAnalysisResponse.DamageItem,
        surfaceType: SurfaceType,
        surfaceId: UUID?,
        imageIndex: Int
    ) -> DetectedDamage {
        let damageType = DamageType(rawValue: item.type) ?? .other

        // Look up wall name if this is a wall surface with a known ID
        let wallName: String? = surfaceId.flatMap { wallNameLookup[$0] }

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
            severity: .low,
            description: item.description,
            surfaceType: surfaceType,
            surfaceId: surfaceId,
            wallName: wallName,
            confidence: item.confidence,
            boundingBox: boundingBox,
            recommendation: item.recommendation,
            imageIndex: imageIndex
        )
    }

    /// Convert damage item to DetectedDamage with real-world size calculation using depth data
    private func convertToDamageWithSize(
        _ item: DamageAnalysisResponse.DamageItem,
        surfaceType: SurfaceType,
        surfaceId: UUID?,
        imageIndex: Int,
        frame: CapturedFrame?
    ) -> DetectedDamage {
        let damageType = DamageType(rawValue: item.type) ?? .other

        // Look up wall name if this is a wall surface with a known ID
        let wallName: String? = surfaceId.flatMap { wallNameLookup[$0] }

        var boundingBox: DamageBoundingBox?
        if let box = item.boundingBox {
            boundingBox = DamageBoundingBox(
                x: box.x,
                y: box.y,
                width: box.width,
                height: box.height
            )
        }

        // Calculate real-world dimensions if we have depth data and a bounding box
        var realWidth: Float?
        var realHeight: Float?
        var realArea: Float?
        var distanceFromCamera: Float?
        var measurementConfidence: Float?

        if let bbox = boundingBox,
           let frame = frame,
           frame.hasDepthData,
           let depthData = frame.depthData,
           let intrinsics = frame.cameraIntrinsics {

            if let dimensions = sizeCalculator.calculateSize(
                boundingBox: bbox,
                depthData: depthData,
                depthWidth: frame.depthWidth,
                depthHeight: frame.depthHeight,
                cameraIntrinsics: intrinsics,
                imageWidth: frame.imageWidth,
                imageHeight: frame.imageHeight
            ) {
                realWidth = dimensions.width
                realHeight = dimensions.height
                realArea = dimensions.area
                distanceFromCamera = dimensions.depth
                measurementConfidence = dimensions.confidence

                print("DamageAnalysisService: Calculated size for \(damageType.displayName): \(dimensions.formattedDimensions) (\(dimensions.formattedArea))")
            }
        }

        return DetectedDamage(
            type: damageType,
            severity: .low,
            description: item.description,
            surfaceType: surfaceType,
            surfaceId: surfaceId,
            wallName: wallName,
            confidence: item.confidence,
            boundingBox: boundingBox,
            recommendation: item.recommendation,
            imageIndex: imageIndex,
            realWidth: realWidth,
            realHeight: realHeight,
            realArea: realArea,
            distanceFromCamera: distanceFromCamera,
            measurementConfidence: measurementConfidence
        )
    }

    // MARK: - Damage Deduplication

    /// Deduplicates damages detected across multiple frames
    private func deduplicateDamages(_ damages: [DetectedDamage]) -> [DetectedDamage] {
        guard damages.count > 1 else { return damages }

        var uniqueDamages: [DetectedDamage] = []

        for damage in damages {
            // Check if this damage is a duplicate of an existing one
            if let existingIndex = findMatchingDamage(damage, in: uniqueDamages) {
                // Keep the better one (higher confidence or closer distance)
                if shouldReplace(existing: uniqueDamages[existingIndex], with: damage) {
                    uniqueDamages[existingIndex] = damage
                }
            } else {
                // New unique damage
                uniqueDamages.append(damage)
            }
        }

        print("DamageAnalysisService: Deduplicated \(damages.count) damages to \(uniqueDamages.count) unique")
        return uniqueDamages
    }

    /// Find a matching damage in the list (same damage seen from different frame)
    private func findMatchingDamage(_ damage: DetectedDamage, in list: [DetectedDamage]) -> Int? {
        for (index, existing) in list.enumerated() {
            if isDuplicate(damage, existing) {
                return index
            }
        }
        return nil
    }

    /// Check if two damages are likely the same (even with different types)
    private func isDuplicate(_ a: DetectedDamage, _ b: DetectedDamage) -> Bool {
        // Primary check: bounding box overlap (spatial similarity)
        if let bboxA = a.boundingBox, let bboxB = b.boundingBox {
            let iou = calculateIoU(bboxA, bboxB)
            if iou > 0.3 {
                // High overlap - likely same damage even if types differ
                return true
            }
        }

        // Secondary check: similar real-world size AND same type
        // (more conservative - requires type match when no bbox overlap)
        if a.type == b.type,
           let areaA = a.realArea, let areaB = b.realArea {
            let sizeDiff = abs(areaA - areaB) / max(areaA, areaB)
            if sizeDiff < 1.0 { // Within 100% size difference
                return true
            }
        }

        return false
    }

    /// Calculate Intersection over Union for bounding boxes
    private func calculateIoU(_ a: DamageBoundingBox, _ b: DamageBoundingBox) -> Float {
        let x1 = max(a.x, b.x)
        let y1 = max(a.y, b.y)
        let x2 = min(a.x + a.width, b.x + b.width)
        let y2 = min(a.y + a.height, b.y + b.height)

        let intersection = max(0, x2 - x1) * max(0, y2 - y1)
        let areaA = a.width * a.height
        let areaB = b.width * b.height
        let union = areaA + areaB - intersection

        return union > 0 ? intersection / union : 0
    }

    /// Decide which damage to keep when duplicates are found
    private func shouldReplace(existing: DetectedDamage, with new: DetectedDamage) -> Bool {
        // Prefer higher confidence
        if new.confidence > existing.confidence + 0.1 {
            return true
        }

        // Prefer closer distance (more accurate depth measurement)
        if let newDist = new.distanceFromCamera,
           let existDist = existing.distanceFromCamera,
           newDist < existDist * 0.8 {
            return true
        }

        return false
    }
}
