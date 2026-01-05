import SwiftUI

/// View displaying damage analysis results
struct DamageResultsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedFilter: FilterOption = .all
    @State private var sortOrder: SortOrder = .severityDesc

    private var result: DamageAnalysisResult? {
        appState.damageAnalysisResult
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = result {
                    resultsContent(result)
                } else {
                    noResultsView
                }
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            appState.navigateTo(.report)
                        } label: {
                            Label("View Full Report", systemImage: "doc.text")
                        }

                        Button {
                            appState.startDamageAnalysis()
                        } label: {
                            Label("New Analysis", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        appState.navigateTo(.dimensions)
                    }
                }
            }
        }
    }

    private func resultsContent(_ result: DamageAnalysisResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                AnalysisSummaryCard(result: result)

                if result.hasDamages {
                    // Filter and sort controls
                    filterSortControls

                    // Damage list
                    damageList(result)
                } else {
                    EmptyDamageStateView()
                }

                // Action buttons
                actionButtons
            }
            .padding()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Results Available")
                .font(.title2)
                .fontWeight(.semibold)

            Button("Start Analysis") {
                appState.startDamageAnalysis()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filterSortControls: some View {
        VStack(spacing: 12) {
            // Filter picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.displayName,
                            isSelected: selectedFilter == option
                        ) {
                            selectedFilter = option
                        }
                    }
                }
            }

            // Sort picker
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }
        }
    }

    private func damageList(_ result: DamageAnalysisResult) -> some View {
        let filteredDamages = filterDamages(result.detectedDamages)
        let sortedDamages = sortDamages(filteredDamages)

        return LazyVStack(spacing: 12) {
            ForEach(sortedDamages) { damage in
                NavigationLink {
                    DamageDetailView(damage: damage)
                } label: {
                    DamageCard(damage: damage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                appState.navigateTo(.report)
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Generate Report")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                appState.navigateTo(.dimensions)
            } label: {
                HStack {
                    Image(systemName: "ruler")
                    Text("Back to Dimensions")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Filtering & Sorting

    private func filterDamages(_ damages: [DetectedDamage]) -> [DetectedDamage] {
        switch selectedFilter {
        case .all:
            return damages
        case .critical:
            return damages.filter { $0.severity == .critical }
        case .high:
            return damages.filter { $0.severity >= .high }
        case .walls:
            return damages.filter { $0.surfaceType == .wall }
        case .floors:
            return damages.filter { $0.surfaceType == .floor }
        case .ceilings:
            return damages.filter { $0.surfaceType == .ceiling }
        }
    }

    private func sortDamages(_ damages: [DetectedDamage]) -> [DetectedDamage] {
        switch sortOrder {
        case .severityDesc:
            return damages.sorted { $0.severity > $1.severity }
        case .severityAsc:
            return damages.sorted { $0.severity < $1.severity }
        case .confidence:
            return damages.sorted { $0.confidence > $1.confidence }
        case .type:
            return damages.sorted { $0.type.displayName < $1.type.displayName }
        }
    }
}

// MARK: - Filter & Sort Options

private enum FilterOption: CaseIterable {
    case all
    case critical
    case high
    case walls
    case floors
    case ceilings

    var displayName: String {
        switch self {
        case .all: return "All"
        case .critical: return "Critical"
        case .high: return "High+"
        case .walls: return "Walls"
        case .floors: return "Floors"
        case .ceilings: return "Ceilings"
        }
    }
}

private enum SortOrder: CaseIterable {
    case severityDesc
    case severityAsc
    case confidence
    case type

    var displayName: String {
        switch self {
        case .severityDesc: return "Severity (High to Low)"
        case .severityAsc: return "Severity (Low to High)"
        case .confidence: return "Confidence"
        case .type: return "Type"
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    DamageResultsView()
        .environmentObject(AppState())
}
