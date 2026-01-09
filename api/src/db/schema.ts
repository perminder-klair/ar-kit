import {
  pgTable,
  uuid,
  timestamp,
  real,
  integer,
  text,
  boolean,
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

// Relations
export const reportsRelations = relations(reports, ({ many }) => ({
  walls: many(walls),
  openings: many(openings),
  damages: many(damages),
  files: many(reportFiles),
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
