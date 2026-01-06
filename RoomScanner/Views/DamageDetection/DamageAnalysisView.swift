import SwiftUI

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

/// View for initiating damage analysis and displaying results
struct DamageAnalysisView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var analysisService: DamageAnalysisService

    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var autoCapturedPreviews: [UIImage] = []

    // Results filter/sort state
    @State private var selectedFilter: FilterOption = .all
    @State private var sortOrder: SortOrder = .severityDesc

    init() {
        // Initialize with a placeholder, will be replaced by EnvironmentObject
        _analysisService = ObservedObject(wrappedValue: DamageAnalysisService())
    }

    private var hasResults: Bool {
        appState.damageAnalysisResult != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isDamageAnalysisConfigured {
                    NotConfiguredView()
                } else if let result = appState.damageAnalysisResult {
                    resultsContent(result)
                } else {
                    preAnalysisContent
                }
            }
            .navigationTitle(hasResults ? "Analysis Results" : "Damage Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if hasResults {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                appState.navigateTo(.report)
                            } label: {
                                Label("View Full Report", systemImage: "doc.text")
                            }

                            Button {
                                appState.damageAnalysisResult = nil
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
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            appState.cancelDamageAnalysis()
                        }
                    }
                }
            }
            .alert("Analysis Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
        .onAppear {
            loadAutoCapturedImages()
        }
    }

    // MARK: - Pre-Analysis Content

    private var preAnalysisContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                autoCapturedSection
            }
            .padding()
        }
        .overlay {
            if isAnalyzing {
                analysisOverlay
            }
        }
        .safeAreaInset(edge: .bottom) {
            analyzeButton
                .padding()
                .background(.ultraThinMaterial)
        }
    }

    private func loadAutoCapturedImages() {
        // Load preview images from captured frames
        let frames = appState.frameCaptureService.capturedFrames
        autoCapturedPreviews = frames.compactMap { frame in
            UIImage(data: frame.imageData)
        }
    }

    private var autoCapturedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Image preview grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Captured Images")
                    .font(.headline)

                if autoCapturedPreviews.isEmpty {
                    Text("No images captured during scan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 8
                    ) {
                        ForEach(Array(autoCapturedPreviews.enumerated()), id: \.offset) {
                            index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var analyzeButton: some View {
        let hasImages = !autoCapturedPreviews.isEmpty

        return Button {
            Task {
                await startAnalysis()
            }
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                Text(hasImages ? "Analyze \(autoCapturedPreviews.count) Images" : "Analyze for Damage")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasImages ? Color.green : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!hasImages || isAnalyzing)
    }

    private var analysisOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(appState.damageAnalysisService.status.displayText)
                    .font(.headline)
                    .foregroundColor(.white)

                if case .analyzing(let progress) = appState.damageAnalysisService.status {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Results Content

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

    // MARK: - Analysis

    private func startAnalysis() async {
        isAnalyzing = true
        errorMessage = nil

        do {
            let result: DamageAnalysisResult

            // Check if we have captured frames with depth data (from ARSession during scan)
            let capturedFrames = appState.frameCaptureService.capturedFrames
            let framesWithDepth = capturedFrames.filter { $0.hasDepthData }

            if !framesWithDepth.isEmpty {
                // Use frames with depth for accurate size measurement
                print(
                    "DamageAnalysisView: Analyzing \(framesWithDepth.count) frames with depth data")
                result = try await appState.damageAnalysisService.analyzeWithFrames(framesWithDepth)
            } else if !capturedFrames.isEmpty {
                // Use captured frames without depth (screenshot fallback)
                print("DamageAnalysisView: Analyzing \(capturedFrames.count) frames without depth")
                result = try await appState.damageAnalysisService.analyzeWithFrames(capturedFrames)
            } else {
                // Use auto-captured images from pending (legacy flow)
                result = try await appState.damageAnalysisService.analyzeWithPendingImages()
            }

            await MainActor.run {
                isAnalyzing = false
                appState.damageAnalysisResult = result
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    DamageAnalysisView()
        .environmentObject(AppState())
}
