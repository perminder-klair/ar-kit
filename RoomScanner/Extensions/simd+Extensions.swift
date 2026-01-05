import simd
import Foundation

// MARK: - simd_float3 Extensions

extension simd_float3 {
    /// Distance to another point
    func distance(to other: simd_float3) -> Float {
        simd_distance(self, other)
    }

    /// Normalize vector
    var normalized: simd_float3 {
        simd_normalize(self)
    }

    /// Dot product with another vector
    func dot(_ other: simd_float3) -> Float {
        simd_dot(self, other)
    }

    /// Cross product with another vector
    func cross(_ other: simd_float3) -> simd_float3 {
        simd_cross(self, other)
    }

    /// Length/magnitude of vector
    var length: Float {
        simd_length(self)
    }

    /// Format as string
    var formatted: String {
        String(format: "(%.2f, %.2f, %.2f)", x, y, z)
    }
}

// MARK: - simd_float4x4 Extensions

extension simd_float4x4 {
    /// Extract position from transform matrix
    var position: simd_float3 {
        simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }

    /// Extract scale from transform matrix
    var scale: simd_float3 {
        simd_float3(
            simd_length(simd_float3(columns.0.x, columns.0.y, columns.0.z)),
            simd_length(simd_float3(columns.1.x, columns.1.y, columns.1.z)),
            simd_length(simd_float3(columns.2.x, columns.2.y, columns.2.z))
        )
    }

    /// Create translation matrix
    static func translation(_ translation: simd_float3) -> simd_float4x4 {
        simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(translation.x, translation.y, translation.z, 1)
        )
    }

    /// Create scale matrix
    static func scale(_ scale: simd_float3) -> simd_float4x4 {
        simd_float4x4(
            simd_float4(scale.x, 0, 0, 0),
            simd_float4(0, scale.y, 0, 0),
            simd_float4(0, 0, scale.z, 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    /// Identity matrix
    static let identity = matrix_identity_float4x4
}

// MARK: - Helper Functions

/// Linear interpolation between two values
func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
    a + (b - a) * t
}

/// Linear interpolation between two vectors
func lerp(_ a: simd_float3, _ b: simd_float3, t: Float) -> simd_float3 {
    a + (b - a) * t
}

/// Clamp value to range
func clamp(_ value: Float, min: Float, max: Float) -> Float {
    Swift.min(Swift.max(value, min), max)
}

/// Degrees to radians
func radians(_ degrees: Float) -> Float {
    degrees * .pi / 180.0
}

/// Radians to degrees
func degrees(_ radians: Float) -> Float {
    radians * 180.0 / .pi
}
