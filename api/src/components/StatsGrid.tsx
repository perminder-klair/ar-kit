import type { Report, Wall, Opening } from "@/db/schema";

interface StatsGridProps {
  report: Report;
  walls: Wall[];
  openings: Opening[];
}

export function StatsGrid({ report, walls, openings }: StatsGridProps) {
  const doors = openings.filter((o) => o.type === "door");
  const windows = openings.filter((o) => o.type === "window");

  return (
    <div className="space-y-6">
      {/* Room Dimensions */}
      <div>
        <h3 className="text-lg font-semibold mb-3">Room Dimensions</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard
            label="Floor Area"
            value={`${report.floorAreaM2.toFixed(2)} m²`}
          />
          <StatCard
            label="Wall Area"
            value={`${report.wallAreaM2.toFixed(2)} m²`}
          />
          <StatCard
            label="Ceiling Height"
            value={`${report.ceilingHeightM.toFixed(2)} m`}
          />
          <StatCard
            label="Volume"
            value={`${report.volumeM3.toFixed(2)} m³`}
          />
        </div>
      </div>

      {/* Walls */}
      {walls.length > 0 && (
        <div>
          <h3 className="text-lg font-semibold mb-3">Walls ({walls.length})</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {walls.map((wall) => (
              <div
                key={wall.id}
                className="bg-gray-50 rounded-lg p-3 border border-gray-200"
              >
                <div className="flex justify-between items-center mb-2">
                  <span className="font-medium">{wall.name}</span>
                  {wall.isCurved && (
                    <span className="text-xs bg-purple-100 text-purple-800 px-2 py-0.5 rounded">
                      Curved
                    </span>
                  )}
                </div>
                <div className="text-sm text-gray-600 space-y-1">
                  <div className="flex justify-between">
                    <span>Width:</span>
                    <span>{wall.widthM.toFixed(2)} m</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Height:</span>
                    <span>{wall.heightM.toFixed(2)} m</span>
                  </div>
                  <div className="flex justify-between font-medium text-gray-900">
                    <span>Area:</span>
                    <span>{wall.areaM2.toFixed(2)} m²</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Doors & Windows */}
      {(doors.length > 0 || windows.length > 0) && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {doors.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold mb-3">Doors ({doors.length})</h3>
              <div className="space-y-2">
                {doors.map((door, i) => (
                  <OpeningCard key={door.id} opening={door} index={i + 1} />
                ))}
              </div>
            </div>
          )}
          {windows.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold mb-3">
                Windows ({windows.length})
              </h3>
              <div className="space-y-2">
                {windows.map((window, i) => (
                  <OpeningCard key={window.id} opening={window} index={i + 1} />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-lg p-4 border border-gray-200">
      <p className="text-sm text-gray-500">{label}</p>
      <p className="text-xl font-semibold">{value}</p>
    </div>
  );
}

function OpeningCard({ opening, index }: { opening: Opening; index: number }) {
  return (
    <div className="bg-gray-50 rounded-lg p-3 border border-gray-200 flex justify-between items-center">
      <span className="font-medium">
        {opening.type === "door" ? "🚪" : "🪟"} #{index}
      </span>
      <span className="text-sm text-gray-600">
        {opening.widthM.toFixed(2)}m × {opening.heightM.toFixed(2)}m
      </span>
    </div>
  );
}
