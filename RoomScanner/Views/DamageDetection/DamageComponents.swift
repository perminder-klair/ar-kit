import SwiftUI

// MARK: - Severity Badge

struct SeverityBadge: View {
    let severity: DamageSeverity

    var body: some View {
        Text(severity.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor)
            .clipShape(Capsule())
    }

    private var severityColor: Color {
        switch severity {
        case .low:
            return .green
        case .moderate:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: OverallCondition

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: conditionIcon)
            Text(condition.displayName)
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(conditionColor)
        .clipShape(Capsule())
    }

    private var conditionColor: Color {
        switch condition {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .yellow
        case .poor:
            return .orange
        case .critical:
            return .red
        }
    }

    private var conditionIcon: String {
        switch condition {
        case .excellent:
            return "checkmark.circle.fill"
        case .good:
            return "hand.thumbsup.fill"
        case .fair:
            return "exclamationmark.circle.fill"
        case .poor:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Surface Tag

struct SurfaceTag: View {
    let surfaceType: SurfaceType
    var wallName: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: surfaceIcon)
            Text(displayText)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }

    private var displayText: String {
        if surfaceType == .wall, let name = wallName {
            return name // "Wall A", "Wall B", etc.
        }
        return surfaceType.displayName
    }

    private var surfaceIcon: String {
        switch surfaceType {
        case .wall:
            return "square.fill"
        case .floor:
            return "square.bottomhalf.filled"
        case .ceiling:
            return "square.tophalf.filled"
        case .door:
            return "door.left.hand.closed"
        case .window:
            return "window.horizontal"
        case .unknown:
            return "questionmark.square"
        }
    }
}

// MARK: - Damage Type Icon

struct DamageTypeIcon: View {
    let damageType: DamageType
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: damageType.icon)
            .font(.system(size: size))
            .foregroundColor(iconColor)
    }

    private var iconColor: Color {
        switch damageType {
        case .crack:
            return .orange
        case .waterDamage:
            return .blue
        case .hole:
            return .gray
        case .weathering:
            return .yellow
        case .mold:
            return .green
        case .peeling:
            return .brown
        case .stain:
            return .purple
        case .structuralDamage:
            return .red
        case .other:
            return .secondary
        }
    }
}

// MARK: - Damage Card

struct DamageCard: View {
    let damage: DetectedDamage

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            DamageTypeIcon(damageType: damage.type, size: 28)
                .frame(width: 44, height: 44)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(damage.type.displayName)
                    .font(.headline)

                Text(damage.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                SurfaceTag(surfaceType: damage.surfaceType, wallName: damage.wallName)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Analysis Summary Card

struct AnalysisSummaryCard: View {
    let result: DamageAnalysisResult

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Analysis Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Stats
            HStack(spacing: 20) {
                StatItem(
                    value: "\(result.detectedDamages.count)",
                    label: "Issues Found",
                    icon: "exclamationmark.circle",
                    color: .orange
                )

                StatItem(
                    value: "\(result.analyzedImageCount)",
                    label: "Images Analyzed",
                    icon: "photo",
                    color: .blue
                )
            }

            // Analysis time
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Analyzed in \(String(format: "%.1f", result.processingTimeSeconds))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(result.analysisDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty State View

struct EmptyDamageStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("No Damage Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The analyzed surfaces appear to be in good condition.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Not Configured View

struct NotConfiguredView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("API Key Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please add your Gemini API key to enable damage detection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Add your key to:\nGeminiAPIKey.plist")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(32)
    }
}

// MARK: - Previews

#Preview("Severity Badges") {
    HStack(spacing: 8) {
        SeverityBadge(severity: .low)
        SeverityBadge(severity: .moderate)
        SeverityBadge(severity: .high)
        SeverityBadge(severity: .critical)
    }
    .padding()
}

#Preview("Condition Badges") {
    VStack(spacing: 8) {
        ConditionBadge(condition: .excellent)
        ConditionBadge(condition: .good)
        ConditionBadge(condition: .fair)
        ConditionBadge(condition: .poor)
        ConditionBadge(condition: .critical)
    }
    .padding()
}
