import SwiftUI
import RoomPlan
import SceneKit
import UIKit

/// 3D viewer for CapturedRoom using inline SceneKit
struct RoomModelViewer: View {
    let capturedRoom: CapturedRoom
    let damages: [DetectedDamage]?
    let capturedFrames: [CapturedFrame]?

    @State private var modelURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var damagePositions: [DamageWorldPosition] = []

    private let positionCalculator = DamagePositionCalculator()

    init(
        capturedRoom: CapturedRoom,
        damages: [DetectedDamage]? = nil,
        capturedFrames: [CapturedFrame]? = nil
    ) {
        self.capturedRoom = capturedRoom
        self.damages = damages
        self.capturedFrames = capturedFrames
    }

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
                SceneKitView(
                    modelURL: url,
                    damagePositions: damagePositions,
                    damages: damages ?? []
                )
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
            calculateDamagePositions()
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

    private func calculateDamagePositions() {
        guard let damages = damages, !damages.isEmpty else {
            return
        }
        // Use room-based positioning (same coordinate system as USDZ export)
        damagePositions = positionCalculator.calculatePositionsFromRoom(
            damages: damages,
            room: capturedRoom
        )
    }
}

/// SceneKit wrapper to display USDZ model inline with damage markers
struct SceneKitView: UIViewRepresentable {
    let modelURL: URL
    let damagePositions: [DamageWorldPosition]
    let damages: [DetectedDamage]

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

            // Add damage markers
            addDamageMarkers(to: scene)
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Damage Markers

    private func addDamageMarkers(to scene: SCNScene) {
        guard !damagePositions.isEmpty else { return }

        let markersNode = SCNNode()
        markersNode.name = "DamageMarkers"

        for position in damagePositions {
            let damage = damages.first { $0.id == position.damageId }
            let markerNode = createMarkerNode(
                at: position.position,
                severity: damage?.severity ?? .moderate
            )
            markersNode.addChildNode(markerNode)
        }

        scene.rootNode.addChildNode(markersNode)
    }

    private func createMarkerNode(at position: simd_float3, severity: DamageSeverity) -> SCNNode {
        // Create sphere marker
        let sphere = SCNSphere(radius: 0.03)

        let material = SCNMaterial()
        material.diffuse.contents = colorForSeverity(severity)
        material.emission.contents = colorForSeverity(severity).withAlphaComponent(0.3)
        sphere.materials = [material]

        let markerNode = SCNNode(geometry: sphere)
        markerNode.position = SCNVector3(position.x, position.y, position.z)

        // Add billboard constraint so marker always faces camera
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = .all
        markerNode.constraints = [constraint]

        return markerNode
    }

    private func colorForSeverity(_ severity: DamageSeverity) -> UIColor {
        switch severity {
        case .low:
            return .systemGreen
        case .moderate:
            return .systemYellow
        case .high:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}
