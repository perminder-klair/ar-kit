import SwiftUI
import RoomPlan
import QuickLook

/// 3D viewer for CapturedRoom using Quick Look
struct RoomModelViewer: View {
    let capturedRoom: CapturedRoom

    @State private var modelURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showQuickLook = false

    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Preparing 3D Model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if modelURL != nil {
                // Show preview button and thumbnail
                VStack(spacing: 16) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("3D Room Model")
                        .font(.headline)

                    Text("Tap to view in 3D")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showQuickLook = true
                    } label: {
                        HStack {
                            Image(systemName: "arkit")
                            Text("Open 3D Viewer")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    showQuickLook = true
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Could not load 3D model")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .quickLookPreview($modelURL)
        .task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
            // Export to temp file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("room_preview_\(UUID().uuidString).usdz")

            try capturedRoom.export(to: tempURL, exportOptions: .mesh)

            await MainActor.run {
                self.modelURL = tempURL
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// Preview not available - CapturedRoom requires LiDAR scan data
