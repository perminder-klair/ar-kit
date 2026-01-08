import SwiftUI

/// Detailed view for a single damage item
struct DamageDetailView: View {
    let damage: DetectedDamage
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var damageImage: UIImage? {
        let frames = appState.frameCaptureService.capturedFrames
        guard damage.imageIndex < frames.count else { return nil }
        return UIImage(data: frames[damage.imageIndex].imageData)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Captured image with bounding box
                if let image = damageImage {
                    imageSection(image)
                }

                // Header
                headerSection

                Divider()

                // Details
                detailsSection

                // Recommendation
                if let recommendation = damage.recommendation {
                    recommendationSection(recommendation)
                }

                // Size measurements (if available)
                if damage.hasMeasurements {
                    measurementsSection
                }

                // Technical info
                technicalSection
            }
            .padding()
        }
        .navigationTitle("Damage Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func imageSection(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Bounding box overlay
            if let bbox = damage.boundingBox {
                GeometryReader { geo in
                    Rectangle()
                        .stroke(Color.orange, lineWidth: 3)
                        .frame(
                            width: CGFloat(bbox.width) * geo.size.width,
                            height: CGFloat(bbox.height) * geo.size.height
                        )
                        .position(
                            x: CGFloat(bbox.x + bbox.width / 2) * geo.size.width,
                            y: CGFloat(bbox.y + bbox.height / 2) * geo.size.height
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Large icon
                DamageTypeIcon(damageType: damage.type, size: 40)
                    .frame(width: 72, height: 72)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text(damage.type.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    SurfaceTag(surfaceType: damage.surfaceType, wallName: damage.wallName)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)

            Text(damage.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func recommendationSection(_ recommendation: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Recommendation")
                    .font(.headline)
            }

            Text(recommendation)
                .font(.body)
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.blue)
                Text("Size Measurements")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                if let area = damage.formattedArea {
                    HStack {
                        Text("Area")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(area)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }

                if let dimensions = damage.formattedDimensions {
                    DamageInfoRow(label: "Dimensions", value: dimensions)
                }

                if let distance = damage.distanceFromCamera {
                    DamageInfoRow(
                        label: "Distance from camera",
                        value: String(format: "%.1f m", distance)
                    )
                }

                if let confidence = damage.measurementConfidence {
                    DamageInfoRow(
                        label: "Measurement accuracy",
                        value: "\(Int(confidence * 100))%"
                    )
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Details")
                .font(.headline)

            VStack(spacing: 8) {
                DamageInfoRow(label: "Confidence", value: "\(Int(damage.confidence * 100))%")
                DamageInfoRow(label: "Surface", value: damage.wallName ?? damage.surfaceType.displayName)
                DamageInfoRow(label: "Damage Type", value: damage.type.rawValue)

                if let bbox = damage.boundingBox {
                    DamageInfoRow(
                        label: "Location",
                        value: String(format: "x: %.2f, y: %.2f", bbox.x, bbox.y)
                    )
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Damage Detail Row

private struct DamageInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview("Wall A Damage") {
    NavigationStack {
        DamageDetailView(damage: DetectedDamage(
            type: .crack,
            severity: .low,
            description: "A significant crack running diagonally across the wall surface, approximately 30cm in length with visible depth.",
            surfaceType: .wall,
            wallName: "Wall A",
            confidence: 0.92,
            recommendation: "This crack should be inspected by a professional to determine if it's structural. Consider filling with appropriate filler for cosmetic repair if non-structural."
        ))
    }
    .environmentObject(AppState())
}

#Preview("With Measurements") {
    NavigationStack {
        DamageDetailView(damage: DetectedDamage(
            type: .waterDamage,
            severity: .low,
            description: "Water stain on ceiling with visible discoloration and potential mold growth around edges.",
            surfaceType: .ceiling,
            confidence: 0.88,
            recommendation: "Identify and fix the source of water leak. Clean affected area with mold treatment solution.",
            realWidth: 0.32,
            realHeight: 0.18,
            realArea: 0.0576,
            distanceFromCamera: 2.1,
            measurementConfidence: 0.92
        ))
    }
    .environmentObject(AppState())
}
