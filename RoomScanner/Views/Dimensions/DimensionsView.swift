import SwiftUI
import RoomPlan
import simd

/// View displaying room dimensions and measurements
struct DimensionsView: View {
    @EnvironmentObject var appState: AppState
    let capturedRoom: CapturedRoom

    @State private var dimensions: CapturedRoomProcessor.RoomDimensions?
    @State private var selectedUnit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit = .meters
    @State private var viewMode: ViewMode = .model3D

    enum ViewMode: String, CaseIterable {
        case floorPlan = "2D Floor Plan"
        case model3D = "3D Model"
    }

    private let processor = CapturedRoomProcessor()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                if let dims = dimensions {
                    SummaryCard(dimensions: dims, unit: selectedUnit)
                }

                // View Mode Picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Room Visualization (2D or 3D)
                Group {
                    switch viewMode {
                    case .floorPlan:
                        FloorPlanPreview(capturedRoom: capturedRoom)
                            .frame(height: 250)
                    case .model3D:
                        RoomModelViewer(capturedRoom: capturedRoom)
                            .frame(height: 300)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                // Detailed Measurements
                if let dims = dimensions {
                    DetailedMeasurements(dimensions: dims, unit: selectedUnit)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Room Dimensions")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.reset()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "house")
                        Text("Home")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.navigateTo(.report)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("Report")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.startDepthCapture()
            } label: {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Capture for Damage Analysis")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .onAppear {
            dimensions = processor.extractDimensions(from: capturedRoom)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let dimensions: CapturedRoomProcessor.RoomDimensions
    let unit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit

    var body: some View {
        VStack(spacing: 16) {
            Text("Room Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                SummaryItem(
                    icon: "square.dashed",
                    title: "Floor Area",
                    value: dimensions.formatArea(dimensions.totalFloorArea, unit: unit)
                )

                SummaryItem(
                    icon: "cube",
                    title: "Volume",
                    value: dimensions.formatVolume(dimensions.roomVolume, unit: unit)
                )

                SummaryItem(
                    icon: "arrow.up.and.down",
                    title: "Ceiling Height",
                    value: dimensions.format(dimensions.ceilingHeight, unit: unit)
                )

                SummaryItem(
                    icon: "rectangle.portrait",
                    title: "Wall Area",
                    value: dimensions.formatArea(dimensions.totalWallArea, unit: unit)
                )
            }

            Divider()

            HStack(spacing: 24) {
                CountItem(count: dimensions.wallCount, label: "Walls")
                CountItem(count: dimensions.doorCount, label: "Doors")
                CountItem(count: dimensions.windowCount, label: "Windows")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct SummaryItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CountItem: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Floor Plan Preview

struct FloorPlanPreview: View {
    let capturedRoom: CapturedRoom

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawFloorPlan(context: context, size: size)
            }
        }
        .padding()
    }

    private func drawFloorPlan(context: GraphicsContext, size: CGSize) {
        // Try floor polygon first, fallback to inferring from walls
        let corners: [simd_float3]

        if let floor = capturedRoom.floors.first, !floor.polygonCorners.isEmpty {
            corners = floor.polygonCorners
        } else if !capturedRoom.walls.isEmpty {
            corners = inferFloorFromWalls(capturedRoom.walls)
        } else {
            // No data - draw placeholder
            drawPlaceholder(context: context, size: size)
            return
        }

        guard !corners.isEmpty else {
            drawPlaceholder(context: context, size: size)
            return
        }

        // Find bounds
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity

        for corner in corners {
            minX = min(minX, corner.x)
            maxX = max(maxX, corner.x)
            minZ = min(minZ, corner.z)
            maxZ = max(maxZ, corner.z)
        }

        let roomWidth = maxX - minX
        let roomDepth = maxZ - minZ

        guard roomWidth > 0, roomDepth > 0 else { return }

        // Calculate scale to fit in view with padding
        let padding: CGFloat = 40
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scale = min(availableWidth / CGFloat(roomWidth), availableHeight / CGFloat(roomDepth))

        // Center offset
        let offsetX = padding + (availableWidth - CGFloat(roomWidth) * scale) / 2
        let offsetY = padding + (availableHeight - CGFloat(roomDepth) * scale) / 2

        // Transform function
        func transform(_ point: simd_float3) -> CGPoint {
            CGPoint(
                x: offsetX + CGFloat(point.x - minX) * scale,
                y: offsetY + CGFloat(point.z - minZ) * scale
            )
        }

        // Draw floor polygon
        var path = Path()
        if let first = corners.first {
            path.move(to: transform(first))
            for corner in corners.dropFirst() {
                path.addLine(to: transform(corner))
            }
            path.closeSubpath()
        }

        context.fill(path, with: .color(.blue.opacity(0.1)))
        context.stroke(path, with: .color(.blue), lineWidth: 2)

        // Draw walls
        for wall in capturedRoom.walls {
            let pos = simd_float3(
                wall.transform.columns.3.x,
                wall.transform.columns.3.y,
                wall.transform.columns.3.z
            )
            let point = transform(pos)
            let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: rect), with: .color(.gray))
        }

        // Draw doors
        for door in capturedRoom.doors {
            let pos = simd_float3(
                door.transform.columns.3.x,
                door.transform.columns.3.y,
                door.transform.columns.3.z
            )
            let point = transform(pos)
            let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(Path(rect), with: .color(.brown))
        }

        // Draw windows
        for window in capturedRoom.windows {
            let pos = simd_float3(
                window.transform.columns.3.x,
                window.transform.columns.3.y,
                window.transform.columns.3.z
            )
            let point = transform(pos)
            let rect = CGRect(x: point.x - 4, y: point.y - 2, width: 8, height: 4)
            context.fill(Path(rect), with: .color(.cyan))
        }
    }

    private func drawPlaceholder(context: GraphicsContext, size: CGSize) {
        // Draw border
        let rect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
        context.stroke(Path(rect), with: .color(.gray.opacity(0.3)), lineWidth: 1)

        // Draw "No floor data" message
        let text = Text("No floor plan data available")
            .font(.caption)
            .foregroundColor(.secondary)
        context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2), anchor: .center)
    }

    /// Infer floor outline from wall positions using convex hull
    private func inferFloorFromWalls(_ walls: [CapturedRoom.Surface]) -> [simd_float3] {
        var points: [simd_float3] = []

        for wall in walls {
            // Wall center position
            let pos = simd_float3(
                wall.transform.columns.3.x,
                0,
                wall.transform.columns.3.z
            )
            points.append(pos)

            // Wall corners based on dimensions and rotation
            let halfWidth = wall.dimensions.x / 2
            let rotation = atan2(wall.transform.columns.0.z, wall.transform.columns.0.x)

            let corner1 = simd_float3(
                pos.x + halfWidth * cos(rotation),
                0,
                pos.z + halfWidth * sin(rotation)
            )
            let corner2 = simd_float3(
                pos.x - halfWidth * cos(rotation),
                0,
                pos.z - halfWidth * sin(rotation)
            )
            points.append(corner1)
            points.append(corner2)
        }

        return convexHull(points)
    }

    /// Compute convex hull using Graham scan algorithm
    private func convexHull(_ points: [simd_float3]) -> [simd_float3] {
        guard points.count >= 3 else { return points }

        // Find lowest point (smallest z, then smallest x)
        var sorted = points.sorted { a, b in
            if a.z != b.z { return a.z < b.z }
            return a.x < b.x
        }

        let pivot = sorted.removeFirst()

        // Sort by polar angle with respect to pivot
        sorted.sort { a, b in
            let angleA = atan2(a.z - pivot.z, a.x - pivot.x)
            let angleB = atan2(b.z - pivot.z, b.x - pivot.x)
            return angleA < angleB
        }

        var hull: [simd_float3] = [pivot]

        for point in sorted {
            while hull.count >= 2 {
                let a = hull[hull.count - 2]
                let b = hull[hull.count - 1]
                let cross = (b.x - a.x) * (point.z - a.z) - (b.z - a.z) * (point.x - a.x)
                if cross <= 0 {
                    hull.removeLast()
                } else {
                    break
                }
            }
            hull.append(point)
        }

        return hull
    }
}

// MARK: - Detailed Measurements

struct DetailedMeasurements: View {
    let dimensions: CapturedRoomProcessor.RoomDimensions
    let unit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Walls Section
            if !dimensions.walls.isEmpty {
                Section {
                    ForEach(Array(dimensions.walls.enumerated()), id: \.element.id) { index, wall in
                        WallRow(wall: wall, index: index + 1, dimensions: dimensions, unit: unit)
                    }
                } header: {
                    SectionHeader(title: "Walls", count: dimensions.wallCount)
                }
            }

            // Doors Section
            if !dimensions.doors.isEmpty {
                Section {
                    ForEach(Array(dimensions.doors.enumerated()), id: \.element.id) { index, door in
                        OpeningRow(opening: door, index: index + 1, dimensions: dimensions, unit: unit)
                    }
                } header: {
                    SectionHeader(title: "Doors", count: dimensions.doorCount)
                }
            }

            // Windows Section
            if !dimensions.windows.isEmpty {
                Section {
                    ForEach(Array(dimensions.windows.enumerated()), id: \.element.id) { index, window in
                        OpeningRow(opening: window, index: index + 1, dimensions: dimensions, unit: unit)
                    }
                } header: {
                    SectionHeader(title: "Windows", count: dimensions.windowCount)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

struct WallRow: View {
    let wall: CapturedRoomProcessor.WallDimension
    let index: Int
    let dimensions: CapturedRoomProcessor.RoomDimensions
    let unit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Wall \(index)")
                        .font(.subheadline.bold())
                    if wall.isCurved {
                        Image(systemName: "circle.dotted")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                HStack(spacing: 16) {
                    Label(dimensions.format(wall.width, unit: unit), systemImage: "arrow.left.and.right")
                    Label(dimensions.format(wall.height, unit: unit), systemImage: "arrow.up.and.down")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dimensions.formatArea(wall.area, unit: unit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OpeningRow: View {
    let opening: CapturedRoomProcessor.OpeningDimension
    let index: Int
    let dimensions: CapturedRoomProcessor.RoomDimensions
    let unit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(opening.type == .door ? "Door" : "Window") \(index)")
                    .font(.subheadline.bold())

                HStack(spacing: 16) {
                    Label(dimensions.format(opening.width, unit: unit), systemImage: "arrow.left.and.right")
                    Label(dimensions.format(opening.height, unit: unit), systemImage: "arrow.up.and.down")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dimensions.formatArea(opening.area, unit: unit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        // Preview requires mock CapturedRoom
        Text("DimensionsView Preview")
    }
}
