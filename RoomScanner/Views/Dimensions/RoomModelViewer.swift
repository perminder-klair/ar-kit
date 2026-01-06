import SwiftUI
import RoomPlan
import SceneKit

/// 3D viewer for CapturedRoom using inline SceneKit
struct RoomModelViewer: View {
    let capturedRoom: CapturedRoom

    @State private var modelURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading 3D Model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let url = modelURL {
                SceneKitView(modelURL: url)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Could not load 3D model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
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

/// SceneKit wrapper to display USDZ model inline
struct SceneKitView: UIViewRepresentable {
    let modelURL: URL

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true

        if let scene = try? SCNScene(url: modelURL) {
            scnView.scene = scene

            // Calculate bounding box to position camera
            let (minBound, maxBound) = scene.rootNode.boundingBox
            let center = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )
            let size = max(maxBound.x - minBound.x, max(maxBound.y - minBound.y, maxBound.z - minBound.z))

            // Camera setup to view the model from above at an angle
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.automaticallyAdjustsZRange = true
            cameraNode.position = SCNVector3(
                center.x,
                center.y + size * 1.5,
                center.z + size * 1.5
            )
            cameraNode.look(at: center)
            scene.rootNode.addChildNode(cameraNode)
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
