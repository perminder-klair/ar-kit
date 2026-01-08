import { db } from "@/db";
import { reports } from "@/db/schema";
import { desc } from "drizzle-orm";
import { ReportCard } from "@/components/ReportCard";

export const dynamic = "force-dynamic";

export default async function Home() {
  const allReports = await db.query.reports.findMany({
    orderBy: [desc(reports.createdAt)],
    with: {
      walls: true,
      openings: true,
      damages: true,
    },
  });

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-6xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Room Scan Reports</h1>
          <p className="text-gray-600 mt-2">
            View and manage room inspection reports from the iOS app
          </p>
        </div>

        {/* Stats Summary */}
        {allReports.length > 0 && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
              <p className="text-sm text-gray-500">Total Reports</p>
              <p className="text-2xl font-bold">{allReports.length}</p>
            </div>
            <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
              <p className="text-sm text-gray-500">Total Issues</p>
              <p className="text-2xl font-bold">
                {allReports.reduce((sum, r) => sum + r.damages.length, 0)}
              </p>
            </div>
            <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
              <p className="text-sm text-gray-500">Critical Issues</p>
              <p className="text-2xl font-bold text-red-600">
                {allReports.reduce(
                  (sum, r) =>
                    sum + r.damages.filter((d) => d.severity === "critical").length,
                  0
                )}
              </p>
            </div>
            <div className="bg-white rounded-lg p-4 shadow-sm border border-gray-200">
              <p className="text-sm text-gray-500">Total Floor Area</p>
              <p className="text-2xl font-bold">
                {allReports.reduce((sum, r) => sum + r.floorAreaM2, 0).toFixed(1)} m²
              </p>
            </div>
          </div>
        )}

        {/* Reports Grid */}
        {allReports.length === 0 ? (
          <div className="bg-white rounded-lg shadow-md p-12 text-center">
            <div className="text-6xl mb-4">📱</div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">
              No reports yet
            </h2>
            <p className="text-gray-600 max-w-md mx-auto">
              Scan a room using the iOS app and tap &quot;Save to Cloud&quot; to see
              your reports here.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {allReports.map((report) => (
              <ReportCard key={report.id} report={report} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
