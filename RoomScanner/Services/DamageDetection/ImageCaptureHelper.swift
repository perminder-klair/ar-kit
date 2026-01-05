import UIKit
import RoomPlan

/// Helper for capturing and processing images for damage analysis
final class ImageCaptureHelper {

    // MARK: - Configuration

    private let maxDimension: CGFloat = 2048
    private let compressionQuality: CGFloat = 0.8

    // MARK: - Public Methods

    /// Compress image data for upload
    func compressImage(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        return compressImage(image)
    }

    /// Compress UIImage for upload
    func compressImage(_ image: UIImage) -> Data? {
        let resizedImage = resizeIfNeeded(image)
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }

    /// Create captured image data from UIImage with surface info
    func createCapturedImageData(
        from image: UIImage,
        surfaceType: SurfaceType,
        surfaceId: UUID? = nil
    ) -> CapturedImageData? {
        guard let data = compressImage(image) else {
            return nil
        }
        return CapturedImageData(data: data, surfaceType: surfaceType, surfaceId: surfaceId)
    }

    /// Create captured image data from raw data with surface info
    func createCapturedImageData(
        from data: Data,
        surfaceType: SurfaceType,
        surfaceId: UUID? = nil
    ) -> CapturedImageData? {
        if let compressed = compressImage(data) {
            return CapturedImageData(data: compressed, surfaceType: surfaceType, surfaceId: surfaceId)
        }
        return nil
    }

    /// Generate placeholder images from CapturedRoom for analysis
    /// In a real implementation, this would capture actual room images
    /// For now, we'll work with user-provided images
    func generateAnalysisImages(from room: CapturedRoom) -> [CapturedImageData] {
        // This is a placeholder - actual implementation would:
        // 1. Access ARSession frames during/after scan
        // 2. Extract images from specific surfaces
        // 3. Associate images with surface IDs
        //
        // For the initial implementation, users will provide images manually
        return []
    }

    /// Determine surface type from CapturedRoom surface
    func surfaceType(for surface: CapturedRoom.Surface) -> SurfaceType {
        switch surface.category {
        case .wall:
            return .wall
        case .floor:
            return .floor
        case .door:
            return .door
        case .window:
            return .window
        case .opening:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    /// Get unique surfaces from CapturedRoom
    func getSurfaces(from room: CapturedRoom) -> [SurfaceInfo] {
        var surfaces: [SurfaceInfo] = []

        for surface in room.walls {
            surfaces.append(SurfaceInfo(
                id: UUID(),
                type: .wall,
                category: surface.category,
                confidence: surface.confidence
            ))
        }

        if let floor = room.floors.first {
            surfaces.append(SurfaceInfo(
                id: UUID(),
                type: .floor,
                category: floor.category,
                confidence: floor.confidence
            ))
        }

        for door in room.doors {
            surfaces.append(SurfaceInfo(
                id: UUID(),
                type: .door,
                category: door.category,
                confidence: door.confidence
            ))
        }

        for window in room.windows {
            surfaces.append(SurfaceInfo(
                id: UUID(),
                type: .window,
                category: window.category,
                confidence: window.confidence
            ))
        }

        return surfaces
    }

    // MARK: - Private Methods

    private func resizeIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Supporting Types

struct SurfaceInfo: Identifiable {
    let id: UUID
    let type: SurfaceType
    let category: CapturedRoom.Surface.Category
    let confidence: CapturedRoom.Confidence
}
