import SwiftUI

/// Detailed view for a single damage item
struct DamageDetailView: View {
    let damage: DetectedDamage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Details
                detailsSection

                // Recommendation
                if let recommendation = damage.recommendation {
                    recommendationSection(recommendation)
                }

                // Technical info
                technicalSection
            }
            .padding()
        }
        .navigationTitle("Damage Details")
        .navigationBarTitleDisplayMode(.inline)
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

                    HStack(spacing: 8) {
                        SeverityBadge(severity: damage.severity)
                        SurfaceTag(surfaceType: damage.surfaceType)
                    }
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

    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Details")
                .font(.headline)

            VStack(spacing: 8) {
                DamageInfoRow(label: "Confidence", value: "\(Int(damage.confidence * 100))%")
                DamageInfoRow(label: "Surface Type", value: damage.surfaceType.displayName)
                DamageInfoRow(label: "Damage Type", value: damage.type.rawValue)
                DamageInfoRow(label: "Severity Level", value: "\(damage.severity.numericValue)/4")

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

// MARK: - Severity Explanation

extension DamageSeverity {
    var explanation: String {
        switch self {
        case .low:
            return "Minor cosmetic issue. Monitor for changes over time."
        case .moderate:
            return "Noticeable damage. Consider addressing in routine maintenance."
        case .high:
            return "Significant damage requiring attention soon."
        case .critical:
            return "Severe damage requiring immediate professional attention."
        }
    }
}

#Preview {
    NavigationStack {
        DamageDetailView(damage: DetectedDamage(
            type: .crack,
            severity: .high,
            description: "A significant crack running diagonally across the wall surface, approximately 30cm in length with visible depth.",
            surfaceType: .wall,
            confidence: 0.92,
            recommendation: "This crack should be inspected by a professional to determine if it's structural. Consider filling with appropriate filler for cosmetic repair if non-structural."
        ))
    }
}
