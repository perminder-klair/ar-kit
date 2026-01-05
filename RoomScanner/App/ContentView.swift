import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                switch appState.currentScreen {
                case .home:
                    HomeView()
                case .scanning:
                    RoomScanView()
                case .processing:
                    ProcessingView()
                case .dimensions:
                    if let room = appState.capturedRoom {
                        DimensionsView(capturedRoom: room)
                    } else {
                        ErrorView(message: "No room data available")
                    }
                case .report:
                    if let room = appState.capturedRoom {
                        ReportView(capturedRoom: room)
                    } else {
                        ErrorView(message: "No room data available")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
