import SwiftUI
import PhotosUI

/// View for initiating and monitoring damage analysis
struct DamageAnalysisView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var analysisService: DamageAnalysisService

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [ImageItem] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedSurfaceType: SurfaceType = .wall
    @State private var useAutoCapturedImages = true
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
                Button("OK") { }
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

        // If we have auto-captured images, use them by default
        useAutoCapturedImages = !frames.isEmpty
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Show auto-captured images or manual selection
                if !autoCapturedPreviews.isEmpty {
                    autoCapturedSection
                } else {
                    // Instructions
                    instructionsCard

                    // Surface type picker
                    surfaceTypePicker

                    // Image picker
                    imagePickerSection

                    // Selected images
                    if !loadedImages.isEmpty {
                        selectedImagesSection
                    }
                }

                // Analyze button
                analyzeButton
            }
            .padding()
        }
        .overlay {
            if isAnalyzing {
                analysisOverlay
            }
        }
    }

    private var autoCapturedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Success banner
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images Captured Automatically")
                        .font(.headline)
                    Text("\(autoCapturedPreviews.count) images captured during scan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Image preview grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Captured Images")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(autoCapturedPreviews.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Option to add manual photos
            Button {
                useAutoCapturedImages = false
                autoCapturedPreviews = []
                appState.damageAnalysisService.clearPendingImages()
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Select Different Photos Instead")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.top, 8)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How it works")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: 1, text: "Select the surface type you're analyzing")
                InstructionRow(number: 2, text: "Add photos of walls, floors, or ceilings")
                InstructionRow(number: 3, text: "Tap 'Analyze' to detect damage")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var surfaceTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Surface Type")
                .font(.headline)

            Picker("Surface Type", selection: $selectedSurfaceType) {
                ForEach(SurfaceType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Images")
                .font(.headline)

            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose from Library")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await loadImages(from: newValue)
                }
            }

            Text("Select up to 10 images for analysis")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var selectedImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Images (\(loadedImages.count))")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    loadedImages.removeAll()
                    selectedPhotos.removeAll()
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(loadedImages) { item in
                        ImageThumbnail(item: item) {
                            removeImage(item)
                        }
                    }
                }
            }
        }
    }

    private var analyzeButton: some View {
        let hasImages = !autoCapturedPreviews.isEmpty || !loadedImages.isEmpty
        let imageCount = autoCapturedPreviews.isEmpty ? loadedImages.count : autoCapturedPreviews.count

        return Button {
            Task {
                await startAnalysis()
            }
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                Text(hasImages ? "Analyze \(imageCount) Images" : "Analyze for Damage")
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

    private func loadImages(from items: [PhotosPickerItem]) async {
        var newImages: [ImageItem] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(ImageItem(image: image, data: data))
            }
        }

        await MainActor.run {
            loadedImages = newImages
        }
    }

    private func removeImage(_ item: ImageItem) {
        loadedImages.removeAll { $0.id == item.id }
    }

    private func startAnalysis() async {
        isAnalyzing = true
        errorMessage = nil

        // If using manually selected images, add them to service
        if autoCapturedPreviews.isEmpty && !loadedImages.isEmpty {
            appState.damageAnalysisService.clearPendingImages()
            for item in loadedImages {
                appState.damageAnalysisService.addImageData(
                    item.data,
                    surfaceType: selectedSurfaceType
                )
            }
        }
        // Auto-captured images are already loaded in AppState.startDamageAnalysis()

        do {
            let result = try await appState.damageAnalysisService.analyzeWithPendingImages()
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

// MARK: - Supporting Views

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(text)
        }
    }
}

private struct ImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}

private struct ImageThumbnail: View {
    let item: ImageItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .offset(x: 4, y: -4)
        }
    }
}

#Preview {
    DamageAnalysisView()
        .environmentObject(AppState())
}
