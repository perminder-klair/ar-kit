import SwiftUI
import RoomPlan

/// Home screen with scan options
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeviceAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Icon
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            // Title
            VStack(spacing: 8) {
                Text("Room Scanner")
                    .font(.largeTitle.bold())
                Text("Scan rooms with LiDAR to get accurate dimensions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Main Action Button
            Button {
                if RoomCaptureService.isSupported {
                    appState.startNewScan()
                } else {
                    showDeviceAlert = true
                }
            } label: {
                Label("Start Scanning", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)

            // Features List
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "ruler", text: "Accurate room dimensions")
                FeatureRow(icon: "square.3.layers.3d", text: "3D room model export")
                FeatureRow(icon: "doc.text", text: "PDF & JSON reports")
            }
            .padding(.horizontal, 40)

            Spacer()

            // Device Requirements
            HStack {
                Image(systemName: "iphone.radiowaves.left.and.right")
                Text("Requires iPhone 12 Pro or later with LiDAR")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .alert("Device Not Supported", isPresented: $showDeviceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Room scanning requires a device with LiDAR sensor (iPhone 12 Pro or later, iPad Pro with LiDAR).")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
