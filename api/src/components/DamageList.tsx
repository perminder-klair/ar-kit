import type { Damage } from "@/db/schema";

interface DamageListProps {
  damages: Damage[];
}

const severityColors: Record<string, string> = {
  low: "bg-green-100 text-green-800",
  moderate: "bg-yellow-100 text-yellow-800",
  high: "bg-orange-100 text-orange-800",
  critical: "bg-red-100 text-red-800",
};

const damageTypeIcons: Record<string, string> = {
  crack: "🔳",
  waterDamage: "💧",
  hole: "⭕",
  weathering: "🌪️",
  mold: "🦠",
  peeling: "📄",
  stain: "💦",
  structuralDamage: "🏚️",
  other: "❓",
};

export function DamageList({ damages }: DamageListProps) {
  if (damages.length === 0) {
    return (
      <div className="bg-green-50 rounded-lg p-6 text-center">
        <div className="text-4xl mb-2">✅</div>
        <p className="text-green-800 font-medium">No issues detected</p>
        <p className="text-green-600 text-sm">This room is in good condition</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {damages.map((damage) => (
        <div
          key={damage.id}
          className="bg-white rounded-lg border border-gray-200 p-4"
        >
          <div className="flex items-start justify-between mb-3">
            <div className="flex items-center gap-3">
              <span className="text-2xl">
                {damageTypeIcons[damage.type] || "❓"}
              </span>
              <div>
                <h4 className="font-medium capitalize">
                  {damage.type.replace(/([A-Z])/g, " $1").trim()}
                </h4>
                <p className="text-sm text-gray-500">
                  {damage.surfaceType}
                  {damage.wallName && ` - ${damage.wallName}`}
                </p>
              </div>
            </div>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${severityColors[damage.severity]}`}
            >
              {damage.severity}
            </span>
          </div>

          <p className="text-gray-700 mb-3">{damage.description}</p>

          {/* Measurements */}
          {(damage.widthM || damage.heightM || damage.areaM2) && (
            <div className="flex gap-4 text-sm text-gray-600 mb-3">
              {damage.widthM && (
                <span>Width: {(damage.widthM * 100).toFixed(1)} cm</span>
              )}
              {damage.heightM && (
                <span>Height: {(damage.heightM * 100).toFixed(1)} cm</span>
              )}
              {damage.areaM2 && (
                <span>Area: {(damage.areaM2 * 10000).toFixed(1)} cm²</span>
              )}
            </div>
          )}

          {/* Confidence */}
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-3">
            <span>Confidence:</span>
            <div className="flex-1 h-2 bg-gray-200 rounded-full max-w-[100px]">
              <div
                className="h-2 bg-blue-500 rounded-full"
                style={{ width: `${damage.confidence * 100}%` }}
              />
            </div>
            <span>{(damage.confidence * 100).toFixed(0)}%</span>
          </div>

          {/* Recommendation */}
          {damage.recommendation && (
            <div className="bg-blue-50 rounded-lg p-3">
              <p className="text-sm text-blue-800">
                <span className="font-medium">Recommendation:</span>{" "}
                {damage.recommendation}
              </p>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
