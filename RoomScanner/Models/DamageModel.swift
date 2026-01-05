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
    let confidence: Float          // 0.0 - 1.0
    let boundingBox: DamageBoundingBox?
    let recommendation: String?
    let imageIndex: Int            // Index of source image in analysis

    init(
        id: UUID = UUID(),
        type: DamageType,
        severity: DamageSeverity,
        description: String,
        surfaceType: SurfaceType,
        surfaceId: UUID? = nil,
        confidence: Float,
        boundingBox: DamageBoundingBox? = nil,
        recommendation: String? = nil,
        imageIndex: Int = 0
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
        self.surfaceType = surfaceType
        self.surfaceId = surfaceId
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.recommendation = recommendation
        self.imageIndex = imageIndex
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
