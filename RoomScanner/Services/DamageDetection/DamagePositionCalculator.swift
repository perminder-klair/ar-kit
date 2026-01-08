import Foundation
import simd
import RoomPlan

/// 3D world position for a detected damage
struct DamageWorldPosition {
    let position: simd_float3      // 3D world coordinates
    let damageId: UUID             // Links to DetectedDamage
    let confidence: Float          // Position accuracy (0.0-1.0)
    let surfaceNormal: simd_float3 // Surface normal for box orientation
}

/// Calculates 3D world positions from 2D damage detections using depth data
final class DamagePositionCalculator {

    // MARK: - Configuration

    private let minValidDepth: Float = 0.1
    private let maxValidDepth: Float = 5.0
    private let depthSampleGrid = 3
    private let defaultCeilingHeight: Float = 2.4

    // Track which wall index to use for distributing damages
    private var wallDamageIndex = 0

    // Actual ceiling height from room scan (set per calculation)
    private var ceilingHeight: Float = 2.4

    // MARK: - Public Methods

    /// Calculate positions from CapturedRoom surfaces (RECOMMENDED)
    /// Uses RoomPlan's coordinate system which matches the USDZ export
    func calculatePositionsFromRoom(
        damages: [DetectedDamage],
        room: CapturedRoom,
        ceilingHeight: Float? = nil
    ) -> [DamageWorldPosition] {
        var positions: [DamageWorldPosition] = []
        wallDamageIndex = 0  // Reset for each calculation
        self.ceilingHeight = ceilingHeight ?? defaultCeilingHeight

        for damage in damages {
            if let position = findSurfacePosition(for: damage, in: room) {
                positions.append(position)
            }
        }

        return positions
    }

    /// Calculate positions using camera transforms from captured frames (ENHANCED)
    /// Uses camera direction to find which wall the user was looking at
    func calculatePositionsWithCameraTransforms(
        damages: [DetectedDamage],
        frames: [CapturedFrame],
        room: CapturedRoom,
        ceilingHeight: Float? = nil
    ) -> [DamageWorldPosition] {
        var positions: [DamageWorldPosition] = []
        self.ceilingHeight = ceilingHeight ?? defaultCeilingHeight

        for damage in damages {
            // Get the frame where this damage was detected
            let frame: CapturedFrame? = damage.imageIndex < frames.count ? frames[damage.imageIndex] : nil

            if let position = findSurfacePositionWithCamera(
                for: damage,
                cameraTransform: frame?.cameraTransform,
                in: room
            ) {
                positions.append(position)
            }
        }

        return positions
    }

    /// Calculate world positions using depth frames (DEPRECATED - coordinate system mismatch)
    /// Positions calculated here are in ARSession's coordinate system, not RoomPlan's
    func calculateAllPositions(
        damages: [DetectedDamage],
        frames: [CapturedFrame]
    ) -> [DamageWorldPosition] {
        var positions: [DamageWorldPosition] = []

        for damage in damages {
            guard damage.imageIndex < frames.count else { continue }
            let frame = frames[damage.imageIndex]

            if let position = calculateWorldPosition(for: damage, frame: frame) {
                positions.append(position)
            }
        }

        return positions
    }

    // MARK: - Room-Based Positioning

    private func findSurfacePosition(
        for damage: DetectedDamage,
        in room: CapturedRoom
    ) -> DamageWorldPosition? {
        // Find matching surface by type
        var transform: simd_float4x4?

        switch damage.surfaceType {
        case .wall:
            // Distribute wall damages across different walls
            if !room.walls.isEmpty {
                let wallIndex = wallDamageIndex % room.walls.count
                transform = room.walls[wallIndex].transform
                wallDamageIndex += 1
            }
        case .floor:
            transform = room.floors.first?.transform
        case .ceiling:
            // Use floor position with ceiling height offset
            if let floorTransform = room.floors.first?.transform {
                var ceilingTransform = floorTransform
                // Offset Y by actual ceiling height from room scan
                ceilingTransform.columns.3.y += ceilingHeight
                transform = ceilingTransform
            }
        case .door:
            transform = room.doors.first?.transform
        case .window:
            transform = room.windows.first?.transform
        case .unknown:
            transform = room.walls.first?.transform
        }

        guard let surfaceTransform = transform else { return nil }

        // Get surface center from transform
        let position = simd_float3(
            surfaceTransform.columns.3.x,
            surfaceTransform.columns.3.y,
            surfaceTransform.columns.3.z
        )

        // Get surface normal (Z axis of transform) and offset marker outward
        let normal = simd_normalize(simd_float3(
            surfaceTransform.columns.2.x,
            surfaceTransform.columns.2.y,
            surfaceTransform.columns.2.z
        ))
        let offsetPosition = position + normal * 0.05  // 5cm offset from surface

        return DamageWorldPosition(
            position: offsetPosition,
            damageId: damage.id,
            confidence: 0.7,  // Lower confidence for surface-based placement
            surfaceNormal: normal
        )
    }

    /// Find surface position using camera transform for better wall selection
    private func findSurfacePositionWithCamera(
        for damage: DetectedDamage,
        cameraTransform: simd_float4x4?,
        in room: CapturedRoom
    ) -> DamageWorldPosition? {
        var transform: simd_float4x4?
        var confidence: Float = 0.7

        switch damage.surfaceType {
        case .wall:
            // Use camera transform to find the best matching wall
            if let camera = cameraTransform, let bestWall = findBestMatchingWall(
                cameraTransform: camera,
                walls: room.walls
            ) {
                transform = bestWall.transform
                confidence = 0.85  // Higher confidence when using camera direction
            } else if !room.walls.isEmpty {
                // Fallback to distribution
                let wallIndex = wallDamageIndex % room.walls.count
                transform = room.walls[wallIndex].transform
                wallDamageIndex += 1
            }
        case .floor:
            transform = room.floors.first?.transform
        case .ceiling:
            if let floorTransform = room.floors.first?.transform {
                var ceilingTransform = floorTransform
                ceilingTransform.columns.3.y += ceilingHeight
                transform = ceilingTransform
            }
        case .door:
            transform = room.doors.first?.transform
        case .window:
            transform = room.windows.first?.transform
        case .unknown:
            transform = room.walls.first?.transform
        }

        guard let surfaceTransform = transform else { return nil }

        let position = simd_float3(
            surfaceTransform.columns.3.x,
            surfaceTransform.columns.3.y,
            surfaceTransform.columns.3.z
        )

        let normal = simd_normalize(simd_float3(
            surfaceTransform.columns.2.x,
            surfaceTransform.columns.2.y,
            surfaceTransform.columns.2.z
        ))
        let offsetPosition = position + normal * 0.05

        return DamageWorldPosition(
            position: offsetPosition,
            damageId: damage.id,
            confidence: confidence,
            surfaceNormal: normal
        )
    }

    /// Find the wall that the camera ray actually intersects
    /// Uses ray-plane intersection WITH bounds checking
    private func findBestMatchingWall(
        cameraTransform: simd_float4x4,
        walls: [CapturedRoom.Surface]
    ) -> CapturedRoom.Surface? {
        guard !walls.isEmpty else { return nil }

        // Handle identity transform - fallback to first wall
        if cameraTransform == simd_float4x4(1) {
            return walls.first
        }

        // Camera position and forward direction
        let cameraPos = simd_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -simd_normalize(simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))

        var bestWall: CapturedRoom.Surface?
        var bestDistance: Float = Float.infinity

        for wall in walls {
            // Wall center position
            let wallPos = simd_float3(
                wall.transform.columns.3.x,
                wall.transform.columns.3.y,
                wall.transform.columns.3.z
            )

            // Wall coordinate axes
            let wallXAxis = simd_normalize(simd_float3(
                wall.transform.columns.0.x,
                wall.transform.columns.0.y,
                wall.transform.columns.0.z
            ))
            let wallYAxis = simd_normalize(simd_float3(
                wall.transform.columns.1.x,
                wall.transform.columns.1.y,
                wall.transform.columns.1.z
            ))
            let wallNormal = simd_normalize(simd_float3(
                wall.transform.columns.2.x,
                wall.transform.columns.2.y,
                wall.transform.columns.2.z
            ))

            // Ray-plane intersection
            let denom = simd_dot(cameraForward, wallNormal)
            guard abs(denom) > 0.001 else { continue }

            let t = simd_dot(wallPos - cameraPos, wallNormal) / denom
            guard t > 0.1 && t < 10.0 else { continue }

            // Calculate intersection point in world space
            let intersectionPoint = cameraPos + cameraForward * t

            // Transform to wall's local coordinate space
            let toIntersection = intersectionPoint - wallPos
            let localX = simd_dot(toIntersection, wallXAxis)
            let localY = simd_dot(toIntersection, wallYAxis)

            // Check if intersection is within wall bounds
            let halfWidth = wall.dimensions.x / 2.0
            let halfHeight = wall.dimensions.y / 2.0

            guard abs(localX) <= halfWidth && abs(localY) <= halfHeight else {
                continue  // Intersection outside wall bounds, skip
            }

            // Select nearest wall that passes bounds check
            if t < bestDistance {
                bestDistance = t
                bestWall = wall
            }
        }

        // Fallback to closest wall by position if no bounded intersection found
        if bestWall == nil {
            bestWall = walls.min { wall1, wall2 in
                let pos1 = simd_float3(wall1.transform.columns.3.x, wall1.transform.columns.3.y, wall1.transform.columns.3.z)
                let pos2 = simd_float3(wall2.transform.columns.3.x, wall2.transform.columns.3.y, wall2.transform.columns.3.z)
                return simd_length(pos1 - cameraPos) < simd_length(pos2 - cameraPos)
            }
        }

        return bestWall
    }

    /// Calculate world position for a single damage detection
    func calculateWorldPosition(
        for damage: DetectedDamage,
        frame: CapturedFrame
    ) -> DamageWorldPosition? {

        guard let boundingBox = damage.boundingBox,
              frame.hasDepthData,
              let depthData = frame.depthData,
              let intrinsics = frame.cameraIntrinsics else {
            return nil
        }

        // 1. Get pixel center of bounding box
        let centerX = (boundingBox.x + boundingBox.width / 2) * Float(frame.imageWidth)
        let centerY = (boundingBox.y + boundingBox.height / 2) * Float(frame.imageHeight)

        // 2. Map to depth buffer coordinates
        let scaleX = Float(frame.depthWidth) / Float(frame.imageWidth)
        let scaleY = Float(frame.depthHeight) / Float(frame.imageHeight)
        let depthCenterX = Int(centerX * scaleX)
        let depthCenterY = Int(centerY * scaleY)

        // 3. Sample depth at center
        guard let depth = sampleDepthWithMedian(
            depthData: depthData,
            centerX: depthCenterX,
            centerY: depthCenterY,
            width: frame.depthWidth,
            height: frame.depthHeight
        ), depth >= minValidDepth, depth <= maxValidDepth else {
            return nil
        }

        // 4. Unproject to camera space using intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        guard fx > 0, fy > 0 else { return nil }

        let cameraSpaceX = (centerX - cx) * depth / fx
        let cameraSpaceY = (centerY - cy) * depth / fy
        let cameraPoint = simd_float3(cameraSpaceX, cameraSpaceY, depth)

        // 5. Transform to world space
        let cameraTransform = frame.cameraTransform
        let worldPoint4 = cameraTransform * simd_float4(cameraPoint, 1.0)
        let worldPosition = simd_float3(worldPoint4.x, worldPoint4.y, worldPoint4.z)

        // 6. Calculate confidence
        let confidence = calculateConfidence(depth: depth, boundingBox: boundingBox)

        // 7. Calculate surface normal (camera forward direction)
        let cameraForward = -simd_normalize(simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))

        return DamageWorldPosition(
            position: worldPosition,
            damageId: damage.id,
            confidence: confidence,
            surfaceNormal: cameraForward
        )
    }

    // MARK: - Private Methods

    /// Sample depth with median filtering for noise reduction
    private func sampleDepthWithMedian(
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

                    if depthValue.isFinite && depthValue >= minValidDepth && depthValue <= maxValidDepth {
                        validSamples.append(depthValue)
                    }
                }
            }
        }

        guard !validSamples.isEmpty else { return nil }

        let sorted = validSamples.sorted()
        return sorted[sorted.count / 2]
    }

    /// Calculate confidence based on depth and bounding box size
    private func calculateConfidence(depth: Float, boundingBox: DamageBoundingBox) -> Float {
        var confidence: Float = 1.0

        // Reduce confidence for far objects
        if depth > 3.0 {
            confidence *= 0.8
        } else if depth > 2.0 {
            confidence *= 0.9
        }

        // Reduce confidence for very small bounding boxes
        let bboxArea = boundingBox.width * boundingBox.height
        if bboxArea < 0.01 {
            confidence *= 0.7
        } else if bboxArea < 0.05 {
            confidence *= 0.85
        }

        return min(max(confidence, 0.0), 1.0)
    }
}
