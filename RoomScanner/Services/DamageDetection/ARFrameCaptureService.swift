import Foundation
import UIKit
import Combine
import simd
import ARKit

/// Captured frame data from room scanning
struct CapturedFrame: Identifiable {
    let id: UUID
    let imageData: Data
    let timestamp: Date
    let cameraTransform: simd_float4x4

    // Depth data for size calculation
    let depthData: Data?
    let depthWidth: Int
    let depthHeight: Int
    let cameraIntrinsics: simd_float3x3?
    let imageWidth: Int
    let imageHeight: Int

    init(
        id: UUID = UUID(),
        imageData: Data,
        timestamp: Date = Date(),
        cameraTransform: simd_float4x4 = simd_float4x4(1),
        depthData: Data? = nil,
        depthWidth: Int = 0,
        depthHeight: Int = 0,
        cameraIntrinsics: simd_float3x3? = nil,
        imageWidth: Int = 0,
        imageHeight: Int = 0
    ) {
        self.id = id
        self.imageData = imageData
        self.timestamp = timestamp
        self.cameraTransform = cameraTransform
        self.depthData = depthData
        self.depthWidth = depthWidth
        self.depthHeight = depthHeight
        self.cameraIntrinsics = cameraIntrinsics
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    /// Whether this frame has depth data for size calculation
    var hasDepthData: Bool {
        depthData != nil && depthWidth > 0 && depthHeight > 0 && cameraIntrinsics != nil
    }
}

/// Service for capturing frames during room scanning
/// Uses screenshot-based capture from RoomCaptureView
final class ARFrameCaptureService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var capturedFrames: [CapturedFrame] = []
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var frameCount: Int = 0

    // MARK: - Configuration

    private let maxFrames = 15
    private let imageCompression: CGFloat = 0.7
    private let maxImageDimension: CGFloat = 1920

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Start capturing mode
    func startCapturing() {
        isCapturing = true
        print("ARFrameCaptureService: Started capturing")
    }

    /// Stop capturing mode
    func stopCapturing() {
        isCapturing = false
        print("ARFrameCaptureService: Stopped capturing, total frames: \(frameCount)")
    }

    /// Add a screenshot captured from RoomCaptureView
    func addScreenshot(_ image: UIImage) {
        guard isCapturing, capturedFrames.count < maxFrames else {
            return
        }

        // Resize if needed
        let resized = resizeIfNeeded(image)

        // Compress to JPEG
        guard let data = resized.jpegData(compressionQuality: imageCompression) else {
            print("ARFrameCaptureService: Failed to compress screenshot")
            return
        }

        let frame = CapturedFrame(
            imageData: data,
            cameraTransform: simd_float4x4(1),  // Identity - no transform for screenshots
            imageWidth: Int(resized.size.width),
            imageHeight: Int(resized.size.height)
        )

        capturedFrames.append(frame)
        frameCount = capturedFrames.count

        print("ARFrameCaptureService: Captured screenshot \(frameCount)/\(maxFrames)")
    }

    /// Capture frame from ARSession with full depth data for damage size calculation
    func captureFrame(from arFrame: ARFrame) {
        guard isCapturing, capturedFrames.count < maxFrames else {
            return
        }

        // Convert captured image to UIImage
        let pixelBuffer = arFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("ARFrameCaptureService: Failed to create CGImage from ARFrame")
            return
        }

        let image = UIImage(cgImage: cgImage)
        let resized = resizeIfNeeded(image)

        guard let imageData = resized.jpegData(compressionQuality: imageCompression) else {
            print("ARFrameCaptureService: Failed to compress ARFrame image")
            return
        }

        // Extract depth data if available (requires LiDAR device)
        var depthData: Data? = nil
        var depthWidth = 0
        var depthHeight = 0

        if let sceneDepth = arFrame.sceneDepth {
            let depthMap = sceneDepth.depthMap
            depthWidth = CVPixelBufferGetWidth(depthMap)
            depthHeight = CVPixelBufferGetHeight(depthMap)
            depthData = convertDepthMapToData(depthMap)
        }

        // Get camera intrinsics for 3D projection
        let intrinsics = arFrame.camera.intrinsics

        let frame = CapturedFrame(
            imageData: imageData,
            cameraTransform: arFrame.camera.transform,
            depthData: depthData,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            cameraIntrinsics: intrinsics,
            imageWidth: CVPixelBufferGetWidth(pixelBuffer),
            imageHeight: CVPixelBufferGetHeight(pixelBuffer)
        )

        capturedFrames.append(frame)
        frameCount = capturedFrames.count

        let hasDepth = depthData != nil ? "with depth" : "no depth"
        print("ARFrameCaptureService: Captured ARFrame \(frameCount)/\(maxFrames) (\(hasDepth))")
    }

    /// Convert depth map CVPixelBuffer to Data for storage
    private func convertDepthMapToData(_ depthMap: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // Depth map is Float32 format
        let dataSize = height * bytesPerRow
        return Data(bytes: baseAddress, count: dataSize)
    }

    /// Clear all captured frames
    func clearFrames() {
        capturedFrames.removeAll()
        frameCount = 0
    }

    /// Reset service for new scan
    func reset() {
        stopCapturing()
        clearFrames()
    }

    /// Convert captured frames to CapturedImageData for analysis
    func getImagesForAnalysis() -> [CapturedImageData] {
        return capturedFrames.map { frame in
            CapturedImageData(
                data: frame.imageData,
                surfaceType: .wall,  // Default to wall - most common surface
                surfaceId: nil
            )
        }
    }

    // MARK: - Private Methods

    private func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size

        guard size.width > maxImageDimension || size.height > maxImageDimension else {
            return image
        }

        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxImageDimension, height: maxImageDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxImageDimension * aspectRatio, height: maxImageDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
