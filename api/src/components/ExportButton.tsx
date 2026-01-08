"use client";

import { useState } from "react";

interface ExportButtonProps {
  reportId: string;
}

export function ExportButton({ reportId }: ExportButtonProps) {
  const [isExporting, setIsExporting] = useState(false);

  const handleExport = async () => {
    setIsExporting(true);
    try {
      const res = await fetch(`/api/reports/${reportId}/export`);
      if (!res.ok) {
        throw new Error("Export failed");
      }

      const data = await res.json();
      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: "application/json",
      });

      // Create download link
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `room-report-${reportId.slice(0, 8)}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Export error:", error);
      alert("Failed to export report");
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <button
      onClick={handleExport}
      disabled={isExporting}
      className="flex items-center gap-3 px-4 py-3 bg-orange-50 hover:bg-orange-100 border border-orange-200 rounded-lg transition-colors disabled:opacity-50"
    >
      <span className="text-2xl">📄</span>
      <div className="text-left">
        <p className="font-medium text-gray-900">
          {isExporting ? "Exporting..." : "Export JSON"}
        </p>
        <p className="text-sm text-gray-500">Download report data</p>
      </div>
    </button>
  );
}
