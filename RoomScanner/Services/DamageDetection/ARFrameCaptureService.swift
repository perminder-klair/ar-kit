import Foundation
import UIKit
import Combine
import simd
import ARKit
import CoreMotion

/// Captured frame data from room scanning
struct CapturedFrame: Identifiable {
    let id: UUID
    let imageData: Data
    let timestamp: Date
    let cameraTransform: simd_float4x4
    let surfaceType: SurfaceType

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
        surfaceType: SurfaceType = .wall,
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
        self.surfaceType = surfaceType
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
    @Published private(set) var currentSurfaceType: SurfaceType = .wall

    // MARK: - Configuration

    private let maxFrames = 15
    private let imageCompression: CGFloat = 0.7
    private let maxImageDimension: CGFloat = 1920

    // MARK: - Motion Detection

    private let motionManager = CMMotionManager()

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Start capturing mode
    func startCapturing() {
        isCapturing = true
        startMotionUpdates()
        print("ARFrameCaptureService: Started capturing with motion detection")
    }

    /// Stop capturing mode
    func stopCapturing() {
        isCapturing = false
        stopMotionUpdates()
        print("ARFrameCaptureService: Stopped capturing, total frames: \(frameCount)")
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

        // Detect surface type from camera orientation
        let surfaceType = detectSurfaceType(from: arFrame.camera.transform)
        currentSurfaceType = surfaceType

        let frame = CapturedFrame(
            imageData: imageData,
            cameraTransform: arFrame.camera.transform,
            surfaceType: surfaceType,
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
        print("ARFrameCaptureService: Captured ARFrame \(frameCount)/\(maxFrames) (\(hasDepth), surface: \(surfaceType.rawValue))")
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

    /// Add frames from external source (e.g., during-scan capture)
    func addFrames(_ frames: [CapturedFrame]) {
        capturedFrames.append(contentsOf: frames)
        frameCount = capturedFrames.count
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
                surfaceType: frame.surfaceType,
                surfaceId: nil
            )
        }
    }

    // MARK: - Motion-Based Surface Detection

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("ARFrameCaptureService: Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1  // 10Hz updates
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.updateSurfaceType(from: motion)
        }
        print("ARFrameCaptureService: Started motion updates")
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func updateSurfaceType(from motion: CMDeviceMotion) {
        // Pitch: rotation around the X-axis (tilting forward/back)
        // Positive pitch = device tilted up (looking at ceiling)
        // Negative pitch = device tilted down (looking at floor)
        let pitch = motion.attitude.pitch
        let threshold = 0.52  // ~30 degrees in radians

        let newType: SurfaceType
        if pitch > threshold {
            newType = .ceiling
        } else if pitch < -threshold {
            newType = .floor
        } else {
            newType = .wall
        }

        // Only update if changed to avoid unnecessary UI updates
        if newType != currentSurfaceType {
            currentSurfaceType = newType
        }
    }

    // MARK: - Transform-Based Surface Detection (for ARFrames)

    /// Determines surface type based on camera orientation
    /// - Parameter transform: The camera transform matrix from ARKit
    /// - Returns: The detected surface type (wall, floor, or ceiling)
    private func detectSurfaceType(from transform: simd_float4x4) -> SurfaceType {
        // Handle identity transform (screenshots) - default to wall
        if transform == simd_float4x4(1) {
            return .wall
        }

        // Extract camera forward direction in world space
        // Camera looks down its -Z axis, so we negate the third column
        let forward = -simd_float3(
            transform.columns.2.x,
            transform.columns.2.y,
            transform.columns.2.z
        )

        // Normalize for safety (should already be normalized from ARKit)
        let normalizedForward = simd_normalize(forward)

        // Threshold: ~30 degrees from vertical = sin(30) ≈ 0.5
        let verticalThreshold: Float = 0.5

        if normalizedForward.y < -verticalThreshold {
            // Camera looking UP (negative Y means pointing toward ceiling)
            return .ceiling
        } else if normalizedForward.y > verticalThreshold {
            // Camera looking DOWN (positive Y means pointing toward floor)
            return .floor
        } else {
            // Camera roughly horizontal - pointing at wall
            return .wall
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
