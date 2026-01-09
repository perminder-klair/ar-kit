import { z } from "zod";

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
});

export type CreateReportInput = z.infer<typeof createReportSchema>;
export type WallInput = z.infer<typeof wallSchema>;
export type OpeningInput = z.infer<typeof openingSchema>;
export type DamageInput = z.infer<typeof damageSchema>;
