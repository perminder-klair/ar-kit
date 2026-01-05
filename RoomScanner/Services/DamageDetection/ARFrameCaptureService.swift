import Foundation
import UIKit
import Combine
import simd

/// Captured frame data from room scanning
struct CapturedFrame: Identifiable {
    let id: UUID
    let imageData: Data
    let timestamp: Date
    let cameraTransform: simd_float4x4

    init(id: UUID = UUID(), imageData: Data, timestamp: Date = Date(), cameraTransform: simd_float4x4 = simd_float4x4(1)) {
        self.id = id
        self.imageData = imageData
        self.timestamp = timestamp
        self.cameraTransform = cameraTransform
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
            cameraTransform: simd_float4x4(1)  // Identity - no transform for screenshots
        )

        capturedFrames.append(frame)
        frameCount = capturedFrames.count

        print("ARFrameCaptureService: Captured screenshot \(frameCount)/\(maxFrames)")
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
