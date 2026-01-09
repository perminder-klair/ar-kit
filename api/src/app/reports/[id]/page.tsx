import { db } from "@/db";
import { notFound } from "next/navigation";
import Link from "next/link";
import { StatsGrid } from "@/components/StatsGrid";
import { DamageList } from "@/components/DamageList";
import { DeleteButton } from "@/components/DeleteButton";
import { ExportButton } from "@/components/ExportButton";
import { ModelViewer } from "@/components/ModelViewer";

type Params = Promise<{ id: string }>;

const conditionColors: Record<string, string> = {
  excellent: "bg-green-100 text-green-800",
  good: "bg-blue-100 text-blue-800",
  fair: "bg-yellow-100 text-yellow-800",
  poor: "bg-orange-100 text-orange-800",
  critical: "bg-red-100 text-red-800",
};

export default async function ReportDetailPage({
  params,
}: {
  params: Params;
}) {
  const { id } = await params;

  const report = await db.query.reports.findFirst({
    where: (reports, { eq }) => eq(reports.id, id),
    with: {
      walls: true,
      openings: true,
      damages: true,
      files: true,
      telemetry: true,
    },
  });

  const damageImages = report?.files.filter((f) => f.fileType === "damage_image") || [];
  const usdzFiles = report?.files.filter((f) => f.fileType === "model_usdz") || [];
  const glbFiles = report?.files.filter((f) => f.fileType === "model_glb") || [];

  if (!report) {
    notFound();
  }

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center text-blue-600 hover:text-blue-800 mb-6"
        >
          <svg
            className="w-4 h-4 mr-2"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 19l-7-7 7-7"
            />
          </svg>
          Back to Reports
        </Link>

        {/* Header */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <div className="flex justify-between items-start mb-4">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                Room Scan Report
              </h1>
              <p className="text-gray-500">
                Scanned by {report.userName} on {formatDate(report.scanDate)}
              </p>
            </div>
            <div className="flex items-center gap-3">
              {report.overallCondition && (
                <span
                  className={`px-4 py-2 rounded-full text-sm font-medium ${conditionColors[report.overallCondition]}`}
                >
                  {report.overallCondition.charAt(0).toUpperCase() +
                    report.overallCondition.slice(1)}{" "}
                  Condition
                </span>
              )}
              <DeleteButton reportId={report.id} />
            </div>
          </div>

          {/* Quick Stats */}
          <div className="grid grid-cols-4 gap-4 pt-4 border-t">
            <div className="text-center">
              <p className="text-2xl font-bold">{report.wallCount}</p>
              <p className="text-sm text-gray-500">Walls</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold">{report.doorCount}</p>
              <p className="text-sm text-gray-500">Doors</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold">{report.windowCount}</p>
              <p className="text-sm text-gray-500">Windows</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold">{report.damages.length}</p>
              <p className="text-sm text-gray-500">Issues</p>
            </div>
          </div>
        </div>

        {/* Export Options */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">Export Options</h2>
          <div className="flex gap-4">
            <ExportButton reportId={report.id} />
          </div>
        </div>

        {/* 3D Model */}
        {(glbFiles.length > 0 || usdzFiles.length > 0) && (
          <div className="bg-white rounded-lg shadow-md p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">3D Room Model</h2>

            {glbFiles.length > 0 ? (
              <ModelViewer
                glbUrl={glbFiles[0].blobUrl}
                usdzUrl={usdzFiles[0]?.blobUrl}
              />
            ) : (
              <div className="bg-gray-100 rounded-lg p-8 text-center">
                <svg className="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
                <p className="text-gray-500 mb-2">Interactive 3D preview not available</p>
                <p className="text-sm text-gray-400">GLB model format required for web display</p>
              </div>
            )}

            <div className="mt-4 flex gap-4">
              {usdzFiles[0] && (
                <a
                  href={usdzFiles[0].blobUrl}
                  download={usdzFiles[0].fileName}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Download USDZ (iOS AR)
                </a>
              )}
              {glbFiles[0] && (
                <a
                  href={glbFiles[0].blobUrl}
                  download={glbFiles[0].fileName}
                  className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Download GLB
                </a>
              )}
            </div>
          </div>
        )}

        {/* Damage Images */}
        {damageImages.length > 0 && (
          <div className="bg-white rounded-lg shadow-md p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">
              Scan Images ({damageImages.length})
            </h2>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {damageImages.map((file) => (
                <a
                  key={file.id}
                  href={file.blobUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block overflow-hidden rounded-lg border border-gray-200 hover:border-blue-500 transition-colors"
                >
                  <img
                    src={file.blobUrl}
                    alt={file.fileName}
                    className="w-full h-48 object-cover"
                  />
                </a>
              ))}
            </div>
          </div>
        )}

        {/* Room Details */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">Room Details</h2>
          <StatsGrid
            report={report}
            walls={report.walls}
            openings={report.openings}
          />
        </div>

        {/* Damage Analysis */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">
            Damage Analysis ({report.damages.length} Issue
            {report.damages.length !== 1 ? "s" : ""})
          </h2>
          <DamageList damages={report.damages} />
        </div>

        {/* Debug Info / Telemetry */}
        {report.telemetry && (
          <div className="bg-white rounded-lg shadow-md p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">Debug Info</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Device Info */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="font-medium text-gray-700 mb-3">Device</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Model</span>
                    <span className="font-mono">{report.telemetry.deviceModel}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">iOS Version</span>
                    <span>{report.telemetry.systemVersion}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">App Version</span>
                    <span>{report.telemetry.appVersion} ({report.telemetry.buildNumber})</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-gray-500">LiDAR</span>
                    <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                      report.telemetry.hasLidar
                        ? "bg-green-100 text-green-800"
                        : "bg-gray-100 text-gray-600"
                    }`}>
                      {report.telemetry.hasLidar ? "Available" : "Not Available"}
                    </span>
                  </div>
                </div>
              </div>

              {/* Timing */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="font-medium text-gray-700 mb-3">Timing</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Scan Duration</span>
                    <span>{report.telemetry.scanDurationSeconds?.toFixed(1) ?? "-"}s</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Processing</span>
                    <span>{report.telemetry.processingDurationSeconds?.toFixed(1) ?? "-"}s</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Upload</span>
                    <span>{report.telemetry.reportUploadDurationMs ? `${report.telemetry.reportUploadDurationMs}ms` : "-"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Payload Size</span>
                    <span>{report.telemetry.reportPayloadSizeBytes ? `${(report.telemetry.reportPayloadSizeBytes / 1024).toFixed(1)} KB` : "-"}</span>
                  </div>
                </div>
              </div>

              {/* Quality Metrics */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="font-medium text-gray-700 mb-3">Scan Quality</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between items-center">
                    <span className="text-gray-500">Completeness</span>
                    <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                      report.telemetry.scanIsComplete
                        ? "bg-green-100 text-green-800"
                        : "bg-yellow-100 text-yellow-800"
                    }`}>
                      {report.telemetry.scanIsComplete ? "Complete" : "Incomplete"}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-gray-500">Status</span>
                    <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                      report.telemetry.scanFinalState === "completed"
                        ? "bg-green-100 text-green-800"
                        : report.telemetry.scanFinalState === "cancelled"
                        ? "bg-yellow-100 text-yellow-800"
                        : "bg-red-100 text-red-800"
                    }`}>
                      {report.telemetry.scanFinalState ?? "-"}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Wall Confidence</span>
                    <span className="text-xs">
                      <span className="text-green-600">{report.telemetry.wallConfidenceHigh ?? 0} high</span>
                      {" / "}
                      <span className="text-yellow-600">{report.telemetry.wallConfidenceMedium ?? 0} med</span>
                      {" / "}
                      <span className="text-red-600">{report.telemetry.wallConfidenceLow ?? 0} low</span>
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Has Floor</span>
                    <span>{report.telemetry.scanHasFloor ? "Yes" : "No"}</span>
                  </div>
                </div>
              </div>

              {/* Frame Capture */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h3 className="font-medium text-gray-700 mb-3">Frame Capture</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-500">Total Frames</span>
                    <span>{report.telemetry.frameTotalCount ?? 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">With Depth</span>
                    <span className="text-green-600">{report.telemetry.framesWithDepth ?? 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Without Depth</span>
                    <span className="text-gray-600">{report.telemetry.framesWithoutDepth ?? 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-500">Surfaces</span>
                    <span className="text-xs">
                      {report.telemetry.frameWallCount ?? 0} wall / {report.telemetry.frameFloorCount ?? 0} floor / {report.telemetry.frameCeilingCount ?? 0} ceiling
                    </span>
                  </div>
                </div>
              </div>

              {/* Errors (if any) */}
              {((report.telemetry.scanErrors as unknown[])?.length > 0 ||
                (report.telemetry.analysisErrors as unknown[])?.length > 0 ||
                (report.telemetry.uploadRetryCount ?? 0) > 0) && (
                <div className="bg-red-50 rounded-lg p-4 md:col-span-2">
                  <h3 className="font-medium text-red-700 mb-3">Errors</h3>
                  <div className="space-y-2 text-sm">
                    {(report.telemetry.scanErrors as Array<{code: string; message: string}>)?.length > 0 && (
                      <div>
                        <span className="text-red-600 font-medium">Scan Errors:</span>
                        <ul className="list-disc list-inside text-red-700 mt-1">
                          {(report.telemetry.scanErrors as Array<{code: string; message: string}>).map((err, i) => (
                            <li key={i}>{err.code}: {err.message}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                    {(report.telemetry.analysisErrors as Array<{code: string; message: string}>)?.length > 0 && (
                      <div>
                        <span className="text-red-600 font-medium">Analysis Errors:</span>
                        <ul className="list-disc list-inside text-red-700 mt-1">
                          {(report.telemetry.analysisErrors as Array<{code: string; message: string}>).map((err, i) => (
                            <li key={i}>{err.code}: {err.message}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                    {(report.telemetry.uploadRetryCount ?? 0) > 0 && (
                      <div className="flex justify-between">
                        <span className="text-red-600">Upload Retries</span>
                        <span>{report.telemetry.uploadRetryCount}</span>
                      </div>
                    )}
                    {report.telemetry.lastUploadError && (
                      <div>
                        <span className="text-red-600 font-medium">Last Upload Error:</span>
                        <p className="text-red-700 mt-1">{report.telemetry.lastUploadError}</p>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Warnings (if any) */}
              {(report.telemetry.scanWarnings as string[])?.length > 0 && (
                <div className="bg-yellow-50 rounded-lg p-4 md:col-span-2">
                  <h3 className="font-medium text-yellow-700 mb-3">Warnings</h3>
                  <ul className="list-disc list-inside text-sm text-yellow-700">
                    {(report.telemetry.scanWarnings as string[]).map((warning, i) => (
                      <li key={i}>{warning}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* Session ID */}
            <div className="mt-4 pt-4 border-t text-xs text-gray-400">
              Session ID: {report.telemetry.sessionId}
            </div>
          </div>
        )}

        {/* Metadata */}
        <div className="mt-6 text-center text-sm text-gray-400">
          <p>Report ID: {report.id}</p>
          <p>Created: {formatDate(report.createdAt)}</p>
        </div>
      </div>
    </div>
  );
}
