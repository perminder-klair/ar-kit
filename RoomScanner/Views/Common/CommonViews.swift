import SwiftUI

/// Loading/Processing view
struct ProcessingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Processing Room Data...")
                .font(.headline)

            Text("Creating 3D model and extracting dimensions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Error view with retry option
struct ErrorView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let retry = onRetry {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Permission request view for camera access
struct PermissionRequestView: View {
    let title: String
    let message: String
    let icon: String
    var onRequest: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let request = onRequest {
                Button("Grant Access", action: request)
                    .buttonStyle(.borderedProminent)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Loading overlay modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

/// Toast overlay modifier for non-blocking notifications
struct ToastOverlay: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String
    let duration: Double

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if isShowing {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(message)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation { isShowing = false }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", duration: Double = 2.0) -> some View {
        modifier(ToastOverlay(isShowing: isShowing, message: message, icon: icon, duration: duration))
    }
}

#Preview("Processing") {
    ProcessingView()
        .environmentObject(AppState())
}

#Preview("Error") {
    ErrorView(message: "Failed to process room data. Please try scanning again.")
}

#Preview("Permission") {
    PermissionRequestView(
        title: "Camera Access Required",
        message: "Room scanning needs access to your camera and LiDAR sensor.",
        icon: "camera"
    )
}
