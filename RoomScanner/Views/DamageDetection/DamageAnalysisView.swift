import SwiftUI

/// View for initiating and monitoring damage analysis
struct DamageAnalysisView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var analysisService: DamageAnalysisService

    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var autoCapturedPreviews: [UIImage] = []

    init() {
        // Initialize with a placeholder, will be replaced by EnvironmentObject
        _analysisService = ObservedObject(wrappedValue: DamageAnalysisService())
    }

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isDamageAnalysisConfigured {
                    NotConfiguredView()
                } else {
                    mainContent
                }
            }
            .navigationTitle("Damage Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.cancelDamageAnalysis()
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

    private func loadAutoCapturedImages() {
        // Load preview images from captured frames
        let frames = appState.frameCaptureService.capturedFrames
        autoCapturedPreviews = frames.compactMap { frame in
            UIImage(data: frame.imageData)
        }
    }

    private var mainContent: some View {
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

    // MARK: - Methods

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
                appState.completeDamageAnalysis(with: result)
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
