import { NextRequest, NextResponse } from "next/server";
import { db } from "@/db";
import { reports, walls, openings, damages } from "@/db/schema";
import { createReportSchema } from "@/schemas/report";
import { desc } from "drizzle-orm";

// GET /api/reports - List all reports
export async function GET() {
  try {
    const allReports = await db.query.reports.findMany({
      orderBy: [desc(reports.createdAt)],
      with: {
        walls: true,
        openings: true,
        damages: true,
      },
    });

    return NextResponse.json(allReports);
  } catch (error) {
    console.error("Error fetching reports:", error);
    return NextResponse.json(
      { error: "Failed to fetch reports" },
      { status: 500 }
    );
  }
}

// POST /api/reports - Create a new report
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    // Validate input
    const parsed = createReportSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json(
        { error: "Invalid input", details: parsed.error.flatten() },
        { status: 400 }
      );
    }

    const data = parsed.data;

    // Insert report
    const [newReport] = await db
      .insert(reports)
      .values({
        scanDate: new Date(data.scanDate),
        floorAreaM2: data.floorAreaM2,
        wallAreaM2: data.wallAreaM2,
        ceilingHeightM: data.ceilingHeightM,
        volumeM3: data.volumeM3,
        wallCount: data.wallCount,
        doorCount: data.doorCount,
        windowCount: data.windowCount,
        overallCondition: data.overallCondition,
      })
      .returning();

    // Insert walls
    if (data.walls.length > 0) {
      await db.insert(walls).values(
        data.walls.map((wall) => ({
          reportId: newReport.id,
          name: wall.name,
          widthM: wall.widthM,
          heightM: wall.heightM,
          areaM2: wall.areaM2,
          isCurved: wall.isCurved,
        }))
      );
    }

    // Insert doors
    const doors = data.doors.map((door) => ({
      reportId: newReport.id,
      type: "door" as const,
      widthM: door.widthM,
      heightM: door.heightM,
      areaM2: door.areaM2,
    }));

    // Insert windows
    const windows = data.windows.map((window) => ({
      reportId: newReport.id,
      type: "window" as const,
      widthM: window.widthM,
      heightM: window.heightM,
      areaM2: window.areaM2,
    }));

    if (doors.length > 0 || windows.length > 0) {
      await db.insert(openings).values([...doors, ...windows]);
    }

    // Insert damages
    if (data.damages.length > 0) {
      await db.insert(damages).values(
        data.damages.map((damage) => ({
          reportId: newReport.id,
          type: damage.type,
          severity: damage.severity,
          surfaceType: damage.surfaceType,
          wallName: damage.wallName,
          description: damage.description,
          confidence: damage.confidence,
          recommendation: damage.recommendation,
          widthM: damage.widthM,
          heightM: damage.heightM,
          areaM2: damage.areaM2,
          distanceM: damage.distanceM,
          measurementConfidence: damage.measurementConfidence,
        }))
      );
    }

    // Fetch complete report with relations
    const completeReport = await db.query.reports.findFirst({
      where: (reports, { eq }) => eq(reports.id, newReport.id),
      with: {
        walls: true,
        openings: true,
        damages: true,
      },
    });

    return NextResponse.json(completeReport, { status: 201 });
  } catch (error) {
    console.error("Error creating report:", error);
    return NextResponse.json(
      { error: "Failed to create report" },
      { status: 500 }
    );
  }
}
