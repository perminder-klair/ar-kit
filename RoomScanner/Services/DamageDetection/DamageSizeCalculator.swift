import Foundation
import simd

/// Real-world dimensions calculated for detected damage
struct DamageRealDimensions {
    let width: Float       // meters
    let height: Float      // meters
    let area: Float        // square meters
    let depth: Float       // distance from camera in meters
    let confidence: Float  // measurement confidence (0.0-1.0)

    /// Formatted width in appropriate unit
    var formattedWidth: String {
        formatLength(width)
    }

    /// Formatted height in appropriate unit
    var formattedHeight: String {
        formatLength(height)
    }

    /// Formatted area in appropriate unit
    var formattedArea: String {
        if area < 0.01 {
            return String(format: "%.1f cm²", area * 10000)
        } else if area < 1.0 {
            return String(format: "%.0f cm²", area * 10000)
        } else {
            return String(format: "%.2f m²", area)
        }
    }

    /// Formatted dimensions as "W x H"
    var formattedDimensions: String {
        "\(formattedWidth) × \(formattedHeight)"
    }

    private func formatLength(_ meters: Float) -> String {
        if meters < 0.01 {
            return String(format: "%.1f mm", meters * 1000)
        } else if meters < 1.0 {
            return String(format: "%.1f cm", meters * 100)
        } else {
            return String(format: "%.2f m", meters)
        }
    }
}

/// Service for calculating real-world damage dimensions from bounding boxes and depth data
final class DamageSizeCalculator {

    // MARK: - Configuration

    /// Minimum valid depth in meters
    private let minValidDepth: Float = 0.1

    /// Maximum valid depth in meters
    private let maxValidDepth: Float = 5.0

    /// Number of depth samples to average for robustness
    private let depthSampleGrid = 3

    // MARK: - Public Methods

    /// Calculate real-world size from bounding box and depth data using pinhole camera model
    /// - Parameters:
    ///   - boundingBox: Normalized bounding box (0.0-1.0) from damage detection
    ///   - depthData: Raw depth buffer data (Float32 values in meters)
    ///   - depthWidth: Width of depth buffer
    ///   - depthHeight: Height of depth buffer
    ///   - cameraIntrinsics: 3x3 camera intrinsic matrix
    ///   - imageWidth: Width of source image
    ///   - imageHeight: Height of source image
    /// - Returns: Real-world dimensions or nil if calculation fails
    func calculateSize(
        boundingBox: DamageBoundingBox,
        depthData: Data,
        depthWidth: Int,
        depthHeight: Int,
        cameraIntrinsics: simd_float3x3,
        imageWidth: Int,
        imageHeight: Int
    ) -> DamageRealDimensions? {

        // Validate inputs
        guard depthWidth > 0, depthHeight > 0, imageWidth > 0, imageHeight > 0 else {
            return nil
        }

        // Convert normalized bbox (0-1) to pixel coordinates in the original image
        let pixelX = boundingBox.x * Float(imageWidth)
        let pixelY = boundingBox.y * Float(imageHeight)
        let pixelW = boundingBox.width * Float(imageWidth)
        let pixelH = boundingBox.height * Float(imageHeight)

        // Calculate center of bounding box in original image coordinates
        let centerPixelX = pixelX + pixelW / 2.0
        let centerPixelY = pixelY + pixelH / 2.0

        // Map image coordinates to depth buffer coordinates
        let scaleX = Float(depthWidth) / Float(imageWidth)
        let scaleY = Float(depthHeight) / Float(imageHeight)

        let depthCenterX = Int(centerPixelX * scaleX)
        let depthCenterY = Int(centerPixelY * scaleY)

        // Sample depth at multiple points for robustness
        guard let depth = sampleDepthWithAverage(
            depthData: depthData,
            centerX: depthCenterX,
            centerY: depthCenterY,
            width: depthWidth,
            height: depthHeight
        ) else {
            return nil
        }

        // Validate depth is in reasonable range
        guard depth >= minValidDepth, depth <= maxValidDepth else {
            return nil
        }

        // Extract focal lengths from camera intrinsics matrix
        // intrinsics[0][0] = fx (focal length in x, pixels)
        // intrinsics[1][1] = fy (focal length in y, pixels)
        let fx = cameraIntrinsics[0][0]
        let fy = cameraIntrinsics[1][1]

        guard fx > 0, fy > 0 else {
            return nil
        }

        // Apply pinhole camera model to convert pixel dimensions to real-world meters
        // real_size = depth * (pixel_size / focal_length)
        let realWidth = depth * pixelW / fx
        let realHeight = depth * pixelH / fy
        let realArea = realWidth * realHeight

        // Calculate confidence based on depth consistency and bbox size
        let confidence = calculateConfidence(
            depth: depth,
            bboxWidth: boundingBox.width,
            bboxHeight: boundingBox.height
        )

        return DamageRealDimensions(
            width: realWidth,
            height: realHeight,
            area: realArea,
            depth: depth,
            confidence: confidence
        )
    }

    /// Calculate size using surface dimensions as fallback when depth data unavailable
    /// - Parameters:
    ///   - boundingBox: Normalized bounding box (0.0-1.0)
    ///   - surfaceWidth: Known surface width in meters
    ///   - surfaceHeight: Known surface height in meters
    /// - Returns: Estimated real-world dimensions
    func calculateSizeFromSurface(
        boundingBox: DamageBoundingBox,
        surfaceWidth: Float,
        surfaceHeight: Float
    ) -> DamageRealDimensions {
        let realWidth = boundingBox.width * surfaceWidth
        let realHeight = boundingBox.height * surfaceHeight
        let realArea = realWidth * realHeight

        return DamageRealDimensions(
            width: realWidth,
            height: realHeight,
            area: realArea,
            depth: 0,  // Unknown
            confidence: 0.7  // Lower confidence for surface-based estimation
        )
    }

    // MARK: - Private Methods

    /// Sample depth at center with averaging for noise reduction
    private func sampleDepthWithAverage(
        depthData: Data,
        centerX: Int,
        centerY: Int,
        width: Int,
        height: Int
    ) -> Float? {
        var validSamples: [Float] = []
        let halfGrid = depthSampleGrid / 2
        let bytesPerRow = width * MemoryLayout<Float>.size

        depthData.withUnsafeBytes { buffer in
            guard let basePtr = buffer.baseAddress else { return }

            for dy in -halfGrid...halfGrid {
                for dx in -halfGrid...halfGrid {
                    let x = min(max(centerX + dx, 0), width - 1)
                    let y = min(max(centerY + dy, 0), height - 1)

                    let offset = y * bytesPerRow + x * MemoryLayout<Float>.size
                    guard offset >= 0, offset + MemoryLayout<Float>.size <= depthData.count else {
                        continue
                    }

                    let depthValue = basePtr.load(fromByteOffset: offset, as: Float.self)

                    // Filter out invalid depth values (NaN, inf, or out of range)
                    if depthValue.isFinite && depthValue >= minValidDepth && depthValue <= maxValidDepth {
                        validSamples.append(depthValue)
                    }
                }
            }
        }

        guard !validSamples.isEmpty else {
            return nil
        }

        // Return median for robustness against outliers
        let sorted = validSamples.sorted()
        return sorted[sorted.count / 2]
    }

    /// Calculate confidence score based on measurement quality indicators
    private func calculateConfidence(
        depth: Float,
        bboxWidth: Float,
        bboxHeight: Float
    ) -> Float {
        var confidence: Float = 1.0

        // Reduce confidence for far objects (less accurate depth)
        if depth > 3.0 {
            confidence *= 0.8
        } else if depth > 2.0 {
            confidence *= 0.9
        }

        // Reduce confidence for very small bounding boxes (harder to measure)
        let bboxArea = bboxWidth * bboxHeight
        if bboxArea < 0.01 {
            confidence *= 0.7
        } else if bboxArea < 0.05 {
            confidence *= 0.85
        }

        // Reduce confidence for very large bounding boxes (may span multiple depths)
        if bboxArea > 0.5 {
            confidence *= 0.8
        }

        return min(max(confidence, 0.0), 1.0)
    }
}
