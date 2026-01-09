import { z } from "zod";

// MARK: - Session Telemetry Schemas

// Device info schema
export const deviceInfoSchema = z.object({
  model: z.string(),
  systemVersion: z.string(),
  appVersion: z.string(),
  buildNumber: z.string(),
  hasLiDAR: z.boolean(),
  processorCount: z.number().int().nullable().optional(),
  physicalMemoryGB: z.number().nullable().optional(),
});

// State transition timestamps schema
export const stateTimestampsSchema = z.object({
  sessionStartedAt: z.string().datetime(),
  scanStartedAt: z.string().datetime().nullable().optional(),
  scanEndedAt: z.string().datetime().nullable().optional(),
  processingStartedAt: z.string().datetime().nullable().optional(),
  processingEndedAt: z.string().datetime().nullable().optional(),
  analysisStartedAt: z.string().datetime().nullable().optional(),
  analysisEndedAt: z.string().datetime().nullable().optional(),
  uploadStartedAt: z.string().datetime().nullable().optional(),
  uploadEndedAt: z.string().datetime().nullable().optional(),
});

// Scan metrics schema
export const scanMetricsSchema = z.object({
  durationSeconds: z.number(),
  processingDurationSeconds: z.number(),
  isComplete: z.boolean(),
  wallCount: z.number().int(),
  hasFloor: z.boolean(),
  warnings: z.array(z.string()),
  finalState: z.enum(["completed", "cancelled", "failed"]),
  failureReason: z.string().nullable().optional(),
});

// Surface distribution schema
export const surfaceDistributionSchema = z.object({
  wall: z.number().int(),
  floor: z.number().int(),
  ceiling: z.number().int(),
});

// Frame capture metrics schema
export const frameCaptureMetricsSchema = z.object({
  totalFrames: z.number().int(),
  framesWithDepth: z.number().int(),
  framesWithoutDepth: z.number().int(),
  surfaceDistribution: surfaceDistributionSchema,
  avgImageSizeBytes: z.number().int().nullable().optional(),
  captureStartedAt: z.string().datetime().nullable().optional(),
  captureEndedAt: z.string().datetime().nullable().optional(),
});

// Wall confidence distribution schema
export const wallConfidenceDistributionSchema = z.object({
  high: z.number().int(),
  medium: z.number().int(),
  low: z.number().int(),
});

// Confidence metrics schema
export const confidenceMetricsSchema = z.object({
  wallConfidenceDistribution: wallConfidenceDistributionSchema,
  avgDamageConfidence: z.number().min(0).max(1).nullable().optional(),
  avgMeasurementConfidence: z.number().min(0).max(1).nullable().optional(),
});

// Telemetry error schema
export const telemetryErrorSchema = z.object({
  code: z.string(),
  message: z.string(),
  timestamp: z.string().datetime(),
});

// Analysis error schema
export const analysisErrorSchema = z.object({
  code: z.string(),
  message: z.string(),
  imageIndex: z.number().int().nullable().optional(),
  timestamp: z.string().datetime(),
});

// Error context schema
export const errorContextSchema = z.object({
  scanErrors: z.array(telemetryErrorSchema),
  analysisErrors: z.array(analysisErrorSchema),
  uploadRetryCount: z.number().int(),
  lastUploadError: z.string().nullable().optional(),
});

// Network timing schema
export const networkTimingSchema = z.object({
  reportUploadDurationMs: z.number().int().nullable().optional(),
  reportPayloadSizeBytes: z.number().int().nullable().optional(),
  fileUploadDurationMs: z.number().int().nullable().optional(),
  totalFilesSizeBytes: z.number().int().nullable().optional(),
  fileUploadCount: z.number().int(),
});

// Complete session telemetry schema
export const sessionTelemetrySchema = z.object({
  sessionId: z.string().uuid(),
  device: deviceInfoSchema,
  timestamps: stateTimestampsSchema,
  scanMetrics: scanMetricsSchema,
  frameCapture: frameCaptureMetricsSchema,
  confidence: confidenceMetricsSchema,
  errors: errorContextSchema,
  network: networkTimingSchema,
});

// MARK: - Room Report Schemas

// Wall schema
export const wallSchema = z.object({
  name: z.string(),
  widthM: z.number(),
  heightM: z.number(),
  areaM2: z.number(),
  isCurved: z.boolean().optional().default(false),
});

// Opening schema (door or window)
export const openingSchema = z.object({
  type: z.enum(["door", "window"]),
  widthM: z.number(),
  heightM: z.number(),
  areaM2: z.number(),
});

// Damage schema
export const damageSchema = z.object({
  type: z.string(),
  severity: z.enum(["low", "moderate", "high", "critical"]),
  surfaceType: z.enum(["wall", "floor", "ceiling", "door", "window", "unknown"]),
  wallName: z.string().nullable().optional(),
  description: z.string(),
  confidence: z.number().min(0).max(1),
  recommendation: z.string().nullable().optional(),
  widthM: z.number().nullable().optional(),
  heightM: z.number().nullable().optional(),
  areaM2: z.number().nullable().optional(),
  distanceM: z.number().nullable().optional(),
  measurementConfidence: z.number().min(0).max(1).nullable().optional(),
});

// Full report creation schema
export const createReportSchema = z.object({
  userName: z.string().min(1),
  scanDate: z.string().datetime(),
  floorAreaM2: z.number(),
  wallAreaM2: z.number(),
  ceilingHeightM: z.number(),
  volumeM3: z.number(),
  wallCount: z.number().int(),
  doorCount: z.number().int(),
  windowCount: z.number().int(),
  overallCondition: z
    .enum(["excellent", "good", "fair", "poor", "critical"])
    .nullable()
    .optional(),
  walls: z.array(wallSchema),
  doors: z.array(openingSchema),
  windows: z.array(openingSchema),
  damages: z.array(damageSchema),
  telemetry: sessionTelemetrySchema.nullable().optional(),
});

export type CreateReportInput = z.infer<typeof createReportSchema>;
export type WallInput = z.infer<typeof wallSchema>;
export type OpeningInput = z.infer<typeof openingSchema>;
export type DamageInput = z.infer<typeof damageSchema>;
export type SessionTelemetryInput = z.infer<typeof sessionTelemetrySchema>;
