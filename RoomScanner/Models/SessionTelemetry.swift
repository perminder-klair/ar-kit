import Foundation
import ARKit
import RoomPlan

// MARK: - Session Telemetry

/// Complete telemetry data for a scanning session
struct SessionTelemetry: Codable {
    let sessionId: UUID
    let device: DeviceInfo
    var timestamps: StateTimestamps
    var scanMetrics: ScanMetrics
    var frameCapture: FrameCaptureMetrics
    var confidence: ConfidenceMetrics
    var errors: ErrorContext
    var network: NetworkTiming

    init(
        sessionId: UUID = UUID(),
        device: DeviceInfo = DeviceInfo(),
        timestamps: StateTimestamps = StateTimestamps(),
        scanMetrics: ScanMetrics = ScanMetrics(),
        frameCapture: FrameCaptureMetrics = FrameCaptureMetrics(),
        confidence: ConfidenceMetrics = ConfidenceMetrics(),
        errors: ErrorContext = ErrorContext(),
        network: NetworkTiming = NetworkTiming()
    ) {
        self.sessionId = sessionId
        self.device = device
        self.timestamps = timestamps
        self.scanMetrics = scanMetrics
        self.frameCapture = frameCapture
        self.confidence = confidence
        self.errors = errors
        self.network = network
    }
}

// MARK: - Device Info

/// Device and app information
struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let hasLiDAR: Bool
    let processorCount: Int?
    let physicalMemoryGB: Double?

    init() {
        self.model = Self.deviceModelIdentifier()
        self.systemVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        self.processorCount = ProcessInfo.processInfo.processorCount
        self.physicalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// MARK: - State Timestamps

/// Timestamps for key state transitions
struct StateTimestamps: Codable {
    var sessionStartedAt: Date
    var scanStartedAt: Date?
    var scanEndedAt: Date?
    var processingStartedAt: Date?
    var processingEndedAt: Date?
    var analysisStartedAt: Date?
    var analysisEndedAt: Date?
    var uploadStartedAt: Date?
    var uploadEndedAt: Date?

    init(sessionStartedAt: Date = Date()) {
        self.sessionStartedAt = sessionStartedAt
    }

    mutating func markScanStarted() {
        scanStartedAt = Date()
    }

    mutating func markScanEnded() {
        scanEndedAt = Date()
    }

    mutating func markProcessingStarted() {
        processingStartedAt = Date()
    }

    mutating func markProcessingEnded() {
        processingEndedAt = Date()
    }

    mutating func markAnalysisStarted() {
        analysisStartedAt = Date()
    }

    mutating func markAnalysisEnded() {
        analysisEndedAt = Date()
    }

    mutating func markUploadStarted() {
        uploadStartedAt = Date()
    }

    mutating func markUploadEnded() {
        uploadEndedAt = Date()
    }
}

// MARK: - Scan Metrics

/// Metrics from the room scanning session
struct ScanMetrics: Codable {
    var durationSeconds: Double
    var processingDurationSeconds: Double
    var isComplete: Bool
    var wallCount: Int
    var hasFloor: Bool
    var warnings: [String]
    var finalState: ScanFinalState
    var failureReason: String?

    enum ScanFinalState: String, Codable {
        case completed
        case cancelled
        case failed
    }

    init(
        durationSeconds: Double = 0,
        processingDurationSeconds: Double = 0,
        isComplete: Bool = false,
        wallCount: Int = 0,
        hasFloor: Bool = false,
        warnings: [String] = [],
        finalState: ScanFinalState = .completed,
        failureReason: String? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.processingDurationSeconds = processingDurationSeconds
        self.isComplete = isComplete
        self.wallCount = wallCount
        self.hasFloor = hasFloor
        self.warnings = warnings
        self.finalState = finalState
        self.failureReason = failureReason
    }

    /// Update from RoomCaptureService completeness result
    mutating func update(from completeness: RoomCaptureService.ScanCompletenessResult) {
        self.isComplete = completeness.isComplete
        self.wallCount = completeness.wallCount
        self.hasFloor = completeness.hasFloor
        self.warnings = completeness.warnings
    }
}

// MARK: - Frame Capture Metrics

/// Metrics from AR frame capture for damage detection
struct FrameCaptureMetrics: Codable {
    var totalFrames: Int
    var framesWithDepth: Int
    var framesWithoutDepth: Int
    var surfaceDistribution: SurfaceDistribution
    var avgImageSizeBytes: Int?
    var captureStartedAt: Date?
    var captureEndedAt: Date?

    struct SurfaceDistribution: Codable {
        var wall: Int
        var floor: Int
        var ceiling: Int

        init(wall: Int = 0, floor: Int = 0, ceiling: Int = 0) {
            self.wall = wall
            self.floor = floor
            self.ceiling = ceiling
        }
    }

    init(
        totalFrames: Int = 0,
        framesWithDepth: Int = 0,
        framesWithoutDepth: Int = 0,
        surfaceDistribution: SurfaceDistribution = SurfaceDistribution(),
        avgImageSizeBytes: Int? = nil,
        captureStartedAt: Date? = nil,
        captureEndedAt: Date? = nil
    ) {
        self.totalFrames = totalFrames
        self.framesWithDepth = framesWithDepth
        self.framesWithoutDepth = framesWithoutDepth
        self.surfaceDistribution = surfaceDistribution
        self.avgImageSizeBytes = avgImageSizeBytes
        self.captureStartedAt = captureStartedAt
        self.captureEndedAt = captureEndedAt
    }

    /// Update from captured frames
    mutating func update(from frames: [CapturedFrame]) {
        totalFrames = frames.count
        framesWithDepth = frames.filter { $0.hasDepthData }.count
        framesWithoutDepth = totalFrames - framesWithDepth

        var dist = SurfaceDistribution()
        for frame in frames {
            switch frame.surfaceType {
            case .wall: dist.wall += 1
            case .floor: dist.floor += 1
            case .ceiling: dist.ceiling += 1
            default: break
            }
        }
        surfaceDistribution = dist

        if !frames.isEmpty {
            let totalSize = frames.reduce(0) { $0 + $1.imageData.count }
            avgImageSizeBytes = totalSize / frames.count
        }
    }
}

// MARK: - Confidence Metrics

/// Confidence score distributions
struct ConfidenceMetrics: Codable {
    var wallConfidenceDistribution: WallConfidenceDistribution
    var avgDamageConfidence: Float?
    var avgMeasurementConfidence: Float?

    struct WallConfidenceDistribution: Codable {
        var high: Int
        var medium: Int
        var low: Int

        init(high: Int = 0, medium: Int = 0, low: Int = 0) {
            self.high = high
            self.medium = medium
            self.low = low
        }
    }

    init(
        wallConfidenceDistribution: WallConfidenceDistribution = WallConfidenceDistribution(),
        avgDamageConfidence: Float? = nil,
        avgMeasurementConfidence: Float? = nil
    ) {
        self.wallConfidenceDistribution = wallConfidenceDistribution
        self.avgDamageConfidence = avgDamageConfidence
        self.avgMeasurementConfidence = avgMeasurementConfidence
    }

    /// Update from wall dimensions
    mutating func update(from walls: [CapturedRoomProcessor.WallDimension]) {
        var dist = WallConfidenceDistribution()
        for wall in walls {
            switch wall.confidence {
            case .high: dist.high += 1
            case .medium: dist.medium += 1
            case .low: dist.low += 1
            @unknown default: break
            }
        }
        wallConfidenceDistribution = dist
    }

    /// Update from damage analysis result
    mutating func update(from damages: [DetectedDamage]) {
        guard !damages.isEmpty else { return }

        let totalConfidence = damages.reduce(0) { $0 + $1.confidence }
        avgDamageConfidence = totalConfidence / Float(damages.count)

        let measurementConfidences = damages.compactMap { $0.measurementConfidence }
        if !measurementConfidences.isEmpty {
            avgMeasurementConfidence = measurementConfidences.reduce(0, +) / Float(measurementConfidences.count)
        }
    }
}

// MARK: - Error Context

/// Error tracking for diagnostics
struct ErrorContext: Codable {
    var scanErrors: [TelemetryError]
    var analysisErrors: [AnalysisError]
    var uploadRetryCount: Int
    var lastUploadError: String?

    struct TelemetryError: Codable {
        let code: String
        let message: String
        let timestamp: Date

        init(code: String, message: String, timestamp: Date = Date()) {
            self.code = code
            self.message = message
            self.timestamp = timestamp
        }
    }

    struct AnalysisError: Codable {
        let code: String
        let message: String
        let imageIndex: Int?
        let timestamp: Date

        init(code: String, message: String, imageIndex: Int? = nil, timestamp: Date = Date()) {
            self.code = code
            self.message = message
            self.imageIndex = imageIndex
            self.timestamp = timestamp
        }
    }

    init(
        scanErrors: [TelemetryError] = [],
        analysisErrors: [AnalysisError] = [],
        uploadRetryCount: Int = 0,
        lastUploadError: String? = nil
    ) {
        self.scanErrors = scanErrors
        self.analysisErrors = analysisErrors
        self.uploadRetryCount = uploadRetryCount
        self.lastUploadError = lastUploadError
    }

    mutating func addScanError(code: String, message: String) {
        scanErrors.append(TelemetryError(code: code, message: message))
    }

    mutating func addAnalysisError(code: String, message: String, imageIndex: Int? = nil) {
        analysisErrors.append(AnalysisError(code: code, message: message, imageIndex: imageIndex))
    }

    mutating func recordUploadRetry(error: String) {
        uploadRetryCount += 1
        lastUploadError = error
    }
}

// MARK: - Network Timing

/// Network request timing metrics
struct NetworkTiming: Codable {
    var reportUploadDurationMs: Int?
    var reportPayloadSizeBytes: Int?
    var fileUploadDurationMs: Int?
    var totalFilesSizeBytes: Int?
    var fileUploadCount: Int

    init(
        reportUploadDurationMs: Int? = nil,
        reportPayloadSizeBytes: Int? = nil,
        fileUploadDurationMs: Int? = nil,
        totalFilesSizeBytes: Int? = nil,
        fileUploadCount: Int = 0
    ) {
        self.reportUploadDurationMs = reportUploadDurationMs
        self.reportPayloadSizeBytes = reportPayloadSizeBytes
        self.fileUploadDurationMs = fileUploadDurationMs
        self.totalFilesSizeBytes = totalFilesSizeBytes
        self.fileUploadCount = fileUploadCount
    }
}
