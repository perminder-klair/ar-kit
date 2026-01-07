import SwiftUI
import RoomPlan

/// View displaying room dimensions and measurements
struct DimensionsView: View {
    @EnvironmentObject var appState: AppState
    let capturedRoom: CapturedRoom

    @State private var dimensions: CapturedRoomProcessor.RoomDimensions?
    @State private var selectedUnit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit = .meters

    private let processor = CapturedRoomProcessor()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                if let dims = dimensions {
                    SummaryCard(dimensions: dims, unit: selectedUnit)
                }

                // Room 3D Model with damage markers
                RoomModelViewer(
                    capturedRoom: capturedRoom,
                    damages: appState.damageAnalysisResult?.detectedDamages,
                    capturedFrames: appState.frameCaptureService.capturedFrames
                )
                .frame(height: 300)
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
