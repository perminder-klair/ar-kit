import { NextRequest, NextResponse } from "next/server";
import { put } from "@vercel/blob";
import { db } from "@/db";
import { reports, reportFiles } from "@/db/schema";
import { eq } from "drizzle-orm";

type Params = Promise<{ id: string }>;

// POST /api/reports/[id]/upload - Upload files for a report
export async function POST(
  request: NextRequest,
  { params }: { params: Params }
) {
  try {
    const { id } = await params;

    // Verify report exists
    const report = await db.query.reports.findFirst({
      where: eq(reports.id, id),
    });

    if (!report) {
      return NextResponse.json({ error: "Report not found" }, { status: 404 });
    }

    const formData = await request.formData();
    const file = formData.get("file") as File | null;
    const fileType = formData.get("fileType") as string | null;

    if (!file) {
      return NextResponse.json({ error: "No file provided" }, { status: 400 });
    }

    if (!fileType || !["damage_image", "model_usdz"].includes(fileType)) {
      return NextResponse.json(
        { error: "Invalid fileType. Must be 'damage_image' or 'model_usdz'" },
        { status: 400 }
      );
    }

    // Upload to Vercel Blob
    const blob = await put(`room-scans/${id}/${file.name}`, file, {
      access: "public",
    });

    // Save file metadata to database
    const [newFile] = await db
      .insert(reportFiles)
      .values({
        reportId: id,
        fileType,
        fileName: file.name,
        blobUrl: blob.url,
        size: file.size,
      })
      .returning();

    return NextResponse.json(newFile, { status: 201 });
  } catch (error) {
    console.error("Error uploading file:", error);
    return NextResponse.json(
      { error: "Failed to upload file" },
      { status: 500 }
    );
  }
}
