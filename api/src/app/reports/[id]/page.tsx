import { db } from "@/db";
import { notFound } from "next/navigation";
import Link from "next/link";
import { StatsGrid } from "@/components/StatsGrid";
import { DamageList } from "@/components/DamageList";
import { DeleteButton } from "@/components/DeleteButton";
import { ExportButton } from "@/components/ExportButton";

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
    },
  });

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
              <p className="text-gray-500">{formatDate(report.scanDate)}</p>
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
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-semibold mb-4">
            Damage Analysis ({report.damages.length} Issue
            {report.damages.length !== 1 ? "s" : ""})
          </h2>
          <DamageList damages={report.damages} />
        </div>

        {/* Metadata */}
        <div className="mt-6 text-center text-sm text-gray-400">
          <p>Report ID: {report.id}</p>
          <p>Created: {formatDate(report.createdAt)}</p>
        </div>
      </div>
    </div>
  );
}
