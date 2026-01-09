import Foundation

/// Types of damage that can be detected
enum DamageType: String, Codable, CaseIterable {
    case crack = "crack"
    case waterDamage = "water_damage"
    case hole = "hole"
    case weathering = "weathering"
    case mold = "mold"
    case peeling = "peeling"
    case stain = "stain"
    case structuralDamage = "structural_damage"
    case other = "other"

    var displayName: String {
        switch self {
        case .crack: return "Crack"
        case .waterDamage: return "Water Damage"
        case .hole: return "Hole"
        case .weathering: return "Weathering"
        case .mold: return "Mold"
        case .peeling: return "Peeling"
        case .stain: return "Stain"
        case .structuralDamage: return "Structural Damage"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .crack: return "bolt.slash"
        case .waterDamage: return "drop.fill"
        case .hole: return "circle.dashed"
        case .weathering: return "sun.max.fill"
        case .mold: return "allergens"
        case .peeling: return "leaf"
        case .stain: return "paintbrush"
        case .structuralDamage: return "exclamationmark.triangle"
        case .other: return "questionmark.circle"
        }
    }
}

/// Severity levels for detected damage
enum DamageSeverity: String, Codable, CaseIterable, Comparable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }

    var numericValue: Int {
        switch self {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    static func < (lhs: DamageSeverity, rhs: DamageSeverity) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

/// Surface types where damage can be detected
enum SurfaceType: String, Codable, CaseIterable {
    case wall = "wall"
    case floor = "floor"
    case ceiling = "ceiling"
    case door = "door"
    case window = "window"
    case unknown = "unknown"

    var displayName: String {
        rawValue.capitalized
    }
}

/// Overall condition assessment
enum OverallCondition: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
}

/// Bounding box for damage location in image
struct DamageBoundingBox: Codable, Equatable {
    let x: Float      // 0.0 - 1.0 relative
    let y: Float
    let width: Float
    let height: Float
}

/// Individual detected damage item
struct DetectedDamage: Identifiable, Codable {
    let id: UUID
    let type: DamageType
    let severity: DamageSeverity
    let description: String
    let surfaceType: SurfaceType
    let surfaceId: UUID?           // Links to CapturedRoom surface if mappable
    let wallName: String?          // "Wall A", "Wall B", etc. - nil for non-wall surfaces
    let confidence: Float          // 0.0 - 1.0
    let boundingBox: DamageBoundingBox?
    let recommendation: String?
    let imageIndex: Int            // Index of source image in analysis

    // Real-world dimensions (calculated from LiDAR depth)
    let realWidth: Float?          // meters
    let realHeight: Float?         // meters
    let realArea: Float?           // square meters
    let distanceFromCamera: Float? // meters
    let measurementConfidence: Float?  // 0.0 - 1.0

    init(
        id: UUID = UUID(),
        type: DamageType,
        severity: DamageSeverity,
        description: String,
        surfaceType: SurfaceType,
        surfaceId: UUID? = nil,
        wallName: String? = nil,
        confidence: Float,
        boundingBox: DamageBoundingBox? = nil,
        recommendation: String? = nil,
        imageIndex: Int = 0,
        realWidth: Float? = nil,
        realHeight: Float? = nil,
        realArea: Float? = nil,
        distanceFromCamera: Float? = nil,
        measurementConfidence: Float? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
        self.surfaceType = surfaceType
        self.surfaceId = surfaceId
        self.wallName = wallName
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.recommendation = recommendation
        self.imageIndex = imageIndex
        self.realWidth = realWidth
        self.realHeight = realHeight
        self.realArea = realArea
        self.distanceFromCamera = distanceFromCamera
        self.measurementConfidence = measurementConfidence
    }

    /// Whether real-world dimensions are available
    var hasMeasurements: Bool {
        realWidth != nil && realHeight != nil && realArea != nil
    }

    /// Formatted area in appropriate unit (cm² or m²)
    var formattedArea: String? {
        guard let area = realArea else { return nil }
        if area < 0.01 {
            return String(format: "%.1f cm²", area * 10000)
        } else if area < 1.0 {
            return String(format: "%.0f cm²", area * 10000)
        } else {
            return String(format: "%.2f m²", area)
        }
    }

    /// Formatted dimensions as "W × H" in appropriate unit
    var formattedDimensions: String? {
        guard let width = realWidth, let height = realHeight else { return nil }
        let w = formatLength(width)
        let h = formatLength(height)
        return "\(w) × \(h)"
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

    /// Create a copy with updated measurements (area auto-calculated from width × height)
    func withMeasurements(width: Float?, height: Float?) -> DetectedDamage {
        let area: Float? = if let w = width, let h = height {
            w * h
        } else {
            nil
        }

        return DetectedDamage(
            id: id,
            type: type,
            severity: severity,
            description: description,
            surfaceType: surfaceType,
            surfaceId: surfaceId,
            wallName: wallName,
            confidence: confidence,
            boundingBox: boundingBox,
            recommendation: recommendation,
            imageIndex: imageIndex,
            realWidth: width,
            realHeight: height,
            realArea: area,
            distanceFromCamera: distanceFromCamera,
            measurementConfidence: 1.0  // Manual measurements have full confidence
        )
    }
}

/// Complete damage analysis result
struct DamageAnalysisResult: Identifiable, Codable {
    let id: UUID
    let analysisDate: Date
    let roomScanId: UUID?
    let detectedDamages: [DetectedDamage]
    let overallCondition: OverallCondition
    let analyzedImageCount: Int
    let processingTimeSeconds: Double

    init(
        id: UUID = UUID(),
        analysisDate: Date = Date(),
        roomScanId: UUID? = nil,
        detectedDamages: [DetectedDamage],
        overallCondition: OverallCondition,
        analyzedImageCount: Int,
        processingTimeSeconds: Double
    ) {
        self.id = id
        self.analysisDate = analysisDate
        self.roomScanId = roomScanId
        self.detectedDamages = detectedDamages
        self.overallCondition = overallCondition
        self.analyzedImageCount = analyzedImageCount
        self.processingTimeSeconds = processingTimeSeconds
    }

    // MARK: - Computed Aggregations

    var damagesBySeverity: [DamageSeverity: [DetectedDamage]] {
        Dictionary(grouping: detectedDamages, by: { $0.severity })
    }

    var damagesBySurface: [SurfaceType: [DetectedDamage]] {
        Dictionary(grouping: detectedDamages, by: { $0.surfaceType })
    }

    var damagesByType: [DamageType: [DetectedDamage]] {
        Dictionary(grouping: detectedDamages, by: { $0.type })
    }

    var criticalCount: Int {
        detectedDamages.filter { $0.severity == .critical }.count
    }

    var highPriorityCount: Int {
        detectedDamages.filter { $0.severity >= .high }.count
    }

    var hasDamages: Bool {
        !detectedDamages.isEmpty
    }
}

/// Status of damage analysis
enum DamageAnalysisStatus: Equatable {
    case idle
    case capturingImages
    case analyzing(progress: Float)
    case completed
    case failed(String)

    var isActive: Bool {
        switch self {
        case .capturingImages, .analyzing:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready to analyze"
        case .capturingImages:
            return "Capturing images..."
        case .analyzing(let progress):
            return "Analyzing... \(Int(progress * 100))%"
        case .completed:
            return "Analysis complete"
        case .failed(let message):
            return "Error: \(message)"
        }
    }
}
