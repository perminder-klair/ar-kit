import Link from "next/link";
import type { Report, Damage } from "@/db/schema";

interface ReportCardProps {
  report: Report & { damages: Damage[] };
}

const conditionColors: Record<string, string> = {
  excellent: "bg-green-100 text-green-800",
  good: "bg-blue-100 text-blue-800",
  fair: "bg-yellow-100 text-yellow-800",
  poor: "bg-orange-100 text-orange-800",
  critical: "bg-red-100 text-red-800",
};

const severityColors: Record<string, string> = {
  low: "bg-green-500",
  moderate: "bg-yellow-500",
  high: "bg-orange-500",
  critical: "bg-red-500",
};

export function ReportCard({ report }: ReportCardProps) {
  const damagesBySeverity = report.damages.reduce(
    (acc, d) => {
      acc[d.severity] = (acc[d.severity] || 0) + 1;
      return acc;
    },
    {} as Record<string, number>
  );

  const formatDate = (date: Date) => {
    return new Date(date).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <Link href={`/reports/${report.id}`}>
      <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow cursor-pointer border border-gray-200">
        {/* Header */}
        <div className="flex justify-between items-start mb-4">
          <div>
            <p className="text-sm text-gray-500">Scanned</p>
            <p className="font-medium">{formatDate(report.scanDate)}</p>
          </div>
          {report.overallCondition && (
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${conditionColors[report.overallCondition] || "bg-gray-100 text-gray-800"}`}
            >
              {report.overallCondition.charAt(0).toUpperCase() +
                report.overallCondition.slice(1)}
            </span>
          )}
        </div>

        {/* Room Stats */}
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div>
            <p className="text-sm text-gray-500">Floor Area</p>
            <p className="font-semibold">{report.floorAreaM2.toFixed(1)} m²</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Volume</p>
            <p className="font-semibold">{report.volumeM3.toFixed(1)} m³</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Ceiling Height</p>
            <p className="font-semibold">{report.ceilingHeightM.toFixed(2)} m</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Surfaces</p>
            <p className="font-semibold">
              {report.wallCount}W / {report.doorCount}D / {report.windowCount}W
            </p>
          </div>
        </div>

        {/* Damage Summary */}
        {report.damages.length > 0 && (
          <div className="border-t pt-4">
            <p className="text-sm text-gray-500 mb-2">
              {report.damages.length} Issue{report.damages.length !== 1 ? "s" : ""}{" "}
              Found
            </p>
            <div className="flex gap-2">
              {(["critical", "high", "moderate", "low"] as const).map(
                (severity) =>
                  damagesBySeverity[severity] ? (
                    <div
                      key={severity}
                      className="flex items-center gap-1 text-sm"
                    >
                      <span
                        className={`w-3 h-3 rounded-full ${severityColors[severity]}`}
                      />
                      <span>{damagesBySeverity[severity]}</span>
                    </div>
                  ) : null
              )}
            </div>
          </div>
        )}
      </div>
    </Link>
  );
}
