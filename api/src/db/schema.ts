import {
  pgTable,
  uuid,
  timestamp,
  real,
  integer,
  text,
  boolean,
  jsonb,
} from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";

// Reports table - main room scan data
export const reports = pgTable("reports", {
  id: uuid("id").primaryKey().defaultRandom(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  userName: text("user_name").notNull().default("Unknown"),
  scanDate: timestamp("scan_date").notNull(),
  floorAreaM2: real("floor_area_m2").notNull(),
  wallAreaM2: real("wall_area_m2").notNull(),
  ceilingHeightM: real("ceiling_height_m").notNull(),
  volumeM3: real("volume_m3").notNull(),
  wallCount: integer("wall_count").notNull(),
  doorCount: integer("door_count").notNull(),
  windowCount: integer("window_count").notNull(),
  overallCondition: text("overall_condition"),
});

// Walls table - individual wall dimensions
export const walls = pgTable("walls", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id")
    .notNull()
    .references(() => reports.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  widthM: real("width_m").notNull(),
  heightM: real("height_m").notNull(),
  areaM2: real("area_m2").notNull(),
  isCurved: boolean("is_curved").default(false),
});

// Openings table - doors and windows
export const openings = pgTable("openings", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id")
    .notNull()
    .references(() => reports.id, { onDelete: "cascade" }),
  type: text("type").notNull(), // "door" | "window"
  widthM: real("width_m").notNull(),
  heightM: real("height_m").notNull(),
  areaM2: real("area_m2").notNull(),
});

// Report files table - uploaded images and 3D models
export const reportFiles = pgTable("report_files", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id")
    .notNull()
    .references(() => reports.id, { onDelete: "cascade" }),
  fileType: text("file_type").notNull(), // "damage_image" | "model_usdz"
  fileName: text("file_name").notNull(),
  blobUrl: text("blob_url").notNull(),
  size: integer("size").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Damages table - detected damage items
export const damages = pgTable("damages", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id")
    .notNull()
    .references(() => reports.id, { onDelete: "cascade" }),
  type: text("type").notNull(),
  severity: text("severity").notNull(),
  surfaceType: text("surface_type").notNull(),
  wallName: text("wall_name"),
  description: text("description").notNull(),
  confidence: real("confidence").notNull(),
  recommendation: text("recommendation"),
  widthM: real("width_m"),
  heightM: real("height_m"),
  areaM2: real("area_m2"),
  distanceM: real("distance_m"),
  measurementConfidence: real("measurement_confidence"),
});

// Session telemetry table - debugging and analytics data
export const sessionTelemetry = pgTable("session_telemetry", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id")
    .notNull()
    .references(() => reports.id, { onDelete: "cascade" }),
  sessionId: uuid("session_id").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),

  // Device info
  deviceModel: text("device_model").notNull(),
  systemVersion: text("system_version").notNull(),
  appVersion: text("app_version").notNull(),
  buildNumber: text("build_number").notNull(),
  hasLidar: boolean("has_lidar").notNull(),
  processorCount: integer("processor_count"),
  physicalMemoryGb: real("physical_memory_gb"),

  // State timestamps
  sessionStartedAt: timestamp("session_started_at").notNull(),
  scanStartedAt: timestamp("scan_started_at"),
  scanEndedAt: timestamp("scan_ended_at"),
  processingStartedAt: timestamp("processing_started_at"),
  processingEndedAt: timestamp("processing_ended_at"),
  analysisStartedAt: timestamp("analysis_started_at"),
  analysisEndedAt: timestamp("analysis_ended_at"),
  uploadStartedAt: timestamp("upload_started_at"),
  uploadEndedAt: timestamp("upload_ended_at"),

  // Scan metrics
  scanDurationSeconds: real("scan_duration_seconds"),
  processingDurationSeconds: real("processing_duration_seconds"),
  scanIsComplete: boolean("scan_is_complete"),
  scanWallCount: integer("scan_wall_count"),
  scanHasFloor: boolean("scan_has_floor"),
  scanWarnings: jsonb("scan_warnings").$type<string[]>(),
  scanFinalState: text("scan_final_state"),
  scanFailureReason: text("scan_failure_reason"),

  // Frame capture metrics
  frameTotalCount: integer("frame_total_count"),
  framesWithDepth: integer("frames_with_depth"),
  framesWithoutDepth: integer("frames_without_depth"),
  frameWallCount: integer("frame_wall_count"),
  frameFloorCount: integer("frame_floor_count"),
  frameCeilingCount: integer("frame_ceiling_count"),
  avgImageSizeBytes: integer("avg_image_size_bytes"),
  captureStartedAt: timestamp("capture_started_at"),
  captureEndedAt: timestamp("capture_ended_at"),

  // Confidence metrics
  wallConfidenceHigh: integer("wall_confidence_high"),
  wallConfidenceMedium: integer("wall_confidence_medium"),
  wallConfidenceLow: integer("wall_confidence_low"),
  avgDamageConfidence: real("avg_damage_confidence"),
  avgMeasurementConfidence: real("avg_measurement_confidence"),

  // Error context (JSONB for flexibility)
  scanErrors: jsonb("scan_errors").$type<
    Array<{ code: string; message: string; timestamp: string }>
  >(),
  analysisErrors: jsonb("analysis_errors").$type<
    Array<{ code: string; message: string; imageIndex?: number; timestamp: string }>
  >(),
  uploadRetryCount: integer("upload_retry_count").default(0),
  lastUploadError: text("last_upload_error"),

  // Network timing
  reportUploadDurationMs: integer("report_upload_duration_ms"),
  reportPayloadSizeBytes: integer("report_payload_size_bytes"),
  fileUploadDurationMs: integer("file_upload_duration_ms"),
  totalFilesSizeBytes: integer("total_files_size_bytes"),
  fileUploadCount: integer("file_upload_count"),
});

// Relations
export const reportsRelations = relations(reports, ({ many, one }) => ({
  walls: many(walls),
  openings: many(openings),
  damages: many(damages),
  files: many(reportFiles),
  telemetry: one(sessionTelemetry),
}));

export const reportFilesRelations = relations(reportFiles, ({ one }) => ({
  report: one(reports, {
    fields: [reportFiles.reportId],
    references: [reports.id],
  }),
}));

export const wallsRelations = relations(walls, ({ one }) => ({
  report: one(reports, {
    fields: [walls.reportId],
    references: [reports.id],
  }),
}));

export const openingsRelations = relations(openings, ({ one }) => ({
  report: one(reports, {
    fields: [openings.reportId],
    references: [reports.id],
  }),
}));

export const damagesRelations = relations(damages, ({ one }) => ({
  report: one(reports, {
    fields: [damages.reportId],
    references: [reports.id],
  }),
}));

export const sessionTelemetryRelations = relations(sessionTelemetry, ({ one }) => ({
  report: one(reports, {
    fields: [sessionTelemetry.reportId],
    references: [reports.id],
  }),
}));

// Types
export type Report = typeof reports.$inferSelect;
export type NewReport = typeof reports.$inferInsert;
export type Wall = typeof walls.$inferSelect;
export type NewWall = typeof walls.$inferInsert;
export type Opening = typeof openings.$inferSelect;
export type NewOpening = typeof openings.$inferInsert;
export type Damage = typeof damages.$inferSelect;
export type NewDamage = typeof damages.$inferInsert;
export type ReportFile = typeof reportFiles.$inferSelect;
export type NewReportFile = typeof reportFiles.$inferInsert;
export type SessionTelemetryRecord = typeof sessionTelemetry.$inferSelect;
export type NewSessionTelemetryRecord = typeof sessionTelemetry.$inferInsert;
