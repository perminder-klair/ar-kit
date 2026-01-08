import { NextRequest, NextResponse } from "next/server";
import { db } from "@/db";

type Params = Promise<{ id: string }>;

// GET /api/reports/[id]/export - Export report as formatted JSON
export async function GET(
  request: NextRequest,
  { params }: { params: Params }
) {
  try {
    const { id } = await params;

    const report = await db.query.reports.findFirst({
      where: (reports, { eq }) => eq(reports.id, id),
      with: {
        walls: true,
        openings: true,
        damages: true,
      },
    });

    if (!report) {
      return NextResponse.json({ error: "Report not found" }, { status: 404 });
    }

    // Format the export data to match iOS app export format
    const exportData = {
      exportDate: new Date().toISOString(),
      reportId: report.id,
      scanDate: report.scanDate,
      roomDimensions: {
        floorAreaM2: report.floorAreaM2,
        wallAreaM2: report.wallAreaM2,
        ceilingHeightM: report.ceilingHeightM,
        volumeM3: report.volumeM3,
      },
      surfaces: {
        walls: report.walls.map((wall) => ({
          id: wall.id,
          name: wall.name,
          widthM: wall.widthM,
          heightM: wall.heightM,
          areaM2: wall.areaM2,
          isCurved: wall.isCurved,
        })),
        doors: report.openings
          .filter((o) => o.type === "door")
          .map((door) => ({
            id: door.id,
            type: door.type,
            widthM: door.widthM,
            heightM: door.heightM,
            areaM2: door.areaM2,
          })),
        windows: report.openings
          .filter((o) => o.type === "window")
          .map((window) => ({
            id: window.id,
            type: window.type,
            widthM: window.widthM,
            heightM: window.heightM,
            areaM2: window.areaM2,
          })),
      },
      damageAnalysis: report.overallCondition
        ? {
            overallCondition: report.overallCondition,
            totalDamagesFound: report.damages.length,
            criticalDamages: report.damages.filter(
              (d) => d.severity === "critical"
            ).length,
            highPriorityDamages: report.damages.filter(
              (d) => d.severity === "high"
            ).length,
            damages: report.damages.map((damage) => ({
              id: damage.id,
              type: damage.type,
              severity: damage.severity,
              surfaceType: damage.surfaceType,
              wallName: damage.wallName,
              description: damage.description,
              confidence: damage.confidence,
              recommendation: damage.recommendation,
              measurements: {
                widthM: damage.widthM,
                heightM: damage.heightM,
                areaM2: damage.areaM2,
                distanceM: damage.distanceM,
              },
            })),
          }
        : null,
      summary: {
        wallCount: report.wallCount,
        doorCount: report.doorCount,
        windowCount: report.windowCount,
        issueCount: report.damages.length,
      },
    };

    return NextResponse.json(exportData);
  } catch (error) {
    console.error("Error exporting report:", error);
    return NextResponse.json(
      { error: "Failed to export report" },
      { status: 500 }
    );
  }
}
