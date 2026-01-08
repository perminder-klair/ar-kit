import SwiftUI
import RoomPlan

/// Report view with export options
struct ReportView: View {
    @EnvironmentObject var appState: AppState
    let capturedRoom: CapturedRoom

    @State private var dimensions: CapturedRoomProcessor.RoomDimensions?
    @State private var selectedUnit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit = .meters
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?

    // Haptic triggers
    @State private var exportTapHaptic = false
    @State private var exportSuccessHaptic = false
    @State private var exportErrorHaptic = false

    private let processor = CapturedRoomProcessor()
    private let exporter = RoomExporter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Export Options
                    ExportOptionsSection(
                        onExportUSDZ: exportUSDZ,
                        onExportJSON: exportJSON,
                        onExportPDF: exportPDF,
                        onExportThreeJS: exportThreeJS
                    )

                    // Damage Analysis Summary (if available)
                    if let damageResult = appState.damageAnalysisResult {
                        DamageReportSection(damageResult: damageResult)
                    }

                    // 3D Room Model with Damage Markers
                    RoomModelSection(
                        capturedRoom: capturedRoom,
                        damages: appState.damageAnalysisResult?.detectedDamages,
                        capturedFrames: appState.frameCaptureService.capturedFrames,
                        ceilingHeight: dimensions?.ceilingHeight
                    )

                    // Quick Stats
                    if let dims = dimensions {
                        QuickStatsSection(dimensions: dims, unit: selectedUnit)
                    }
                }
                .padding()
            }
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.navigateTo(.dimensions)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.navigateTo(.home)
                    } label: {
                        Image(systemName: "house")
                    }
                }
            }
            .loadingOverlay(isLoading: isExporting, message: "Exporting...")
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .onAppear {
            dimensions = processor.extractDimensions(from: capturedRoom)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: exportTapHaptic)
        .sensoryFeedback(.success, trigger: exportSuccessHaptic)
        .sensoryFeedback(.error, trigger: exportErrorHaptic)
    }

    // MARK: - Export Methods

    private func exportUSDZ() {
        exportTapHaptic.toggle()
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                let url = try await exporter.exportUSDZ(capturedRoom: capturedRoom)
                exportedFileURL = url
                showShareSheet = true
                exportSuccessHaptic.toggle()
            } catch {
                exportError = error.localizedDescription
                exportErrorHaptic.toggle()
            }
        }
    }

    private func exportJSON() {
        exportTapHaptic.toggle()
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                guard let dims = dimensions else { return }
                let url = try exporter.exportJSON(
                    dimensions: dims,
                    damageAnalysis: appState.damageAnalysisResult
                )
                exportedFileURL = url
                showShareSheet = true
                exportSuccessHaptic.toggle()
            } catch {
                exportError = error.localizedDescription
                exportErrorHaptic.toggle()
            }
        }
    }

    private func exportPDF() {
        exportTapHaptic.toggle()
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                guard let dims = dimensions else { return }
                let url = try exporter.exportPDF(
                    dimensions: dims,
                    capturedRoom: capturedRoom,
                    damageAnalysis: appState.damageAnalysisResult,
                    capturedFrames: appState.frameCaptureService.capturedFrames
                )
                exportedFileURL = url
                showShareSheet = true
                exportSuccessHaptic.toggle()
            } catch {
                exportError = error.localizedDescription
                exportErrorHaptic.toggle()
            }
        }
    }

    private func exportThreeJS() {
        exportTapHaptic.toggle()
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                guard let dims = dimensions else { return }
                let url = try exporter.exportThreeJS(
                    capturedRoom: capturedRoom,
                    dimensions: dims,
                    damageAnalysis: appState.damageAnalysisResult,
                    capturedFrames: appState.frameCaptureService.capturedFrames
                )
                exportedFileURL = url
                showShareSheet = true
                exportSuccessHaptic.toggle()
            } catch {
                exportError = error.localizedDescription
                exportErrorHaptic.toggle()
            }
        }
    }
}

// MARK: - Damage Report Section

struct DamageReportSection: View {
    let damageResult: DamageAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Damage Assessment")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("\(damageResult.detectedDamages.count)")
                        .font(.title2.bold())
                    Text("Issues Found")
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if !damageResult.detectedDamages.isEmpty {
                    Divider()

                    // Tappable damage items
                    ForEach(damageResult.detectedDamages.prefix(3)) { damage in
                        NavigationLink {
                            DamageDetailView(damage: damage)
                        } label: {
                            HStack {
                                DamageTypeIcon(damageType: damage.type, size: 16)
                                Text(damage.type.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if damageResult.detectedDamages.count > 3 {
                        Text("+ \(damageResult.detectedDamages.count - 3) more issues")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Export Options

struct ExportOptionsSection: View {
    let onExportUSDZ: () -> Void
    let onExportJSON: () -> Void
    let onExportPDF: () -> Void
    let onExportThreeJS: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Options")
                .font(.headline)

            VStack(spacing: 12) {
                ExportButton(
                    icon: "cube",
                    title: "3D Model (USDZ)",
                    description: "View in AR Quick Look",
                    color: .purple,
                    action: onExportUSDZ
                )

                ExportButton(
                    icon: "globe",
                    title: "Web 3D (JSON)",
                    description: "Three.js compatible geometry",
                    color: .blue,
                    action: onExportThreeJS
                )

                ExportButton(
                    icon: "doc.text",
                    title: "Data (JSON)",
                    description: "Machine-readable dimensions",
                    color: .orange,
                    action: onExportJSON
                )

                ExportButton(
                    icon: "doc.richtext",
                    title: "Report (PDF)",
                    description: "Printable inspection report",
                    color: .red,
                    action: onExportPDF
                )
            }
        }
    }
}

struct ExportButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Stats

struct QuickStatsSection: View {
    let dimensions: CapturedRoomProcessor.RoomDimensions
    let unit: CapturedRoomProcessor.RoomDimensions.MeasurementUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Details")
                .font(.headline)

            VStack(spacing: 8) {
                DetailRow(label: "Floor Area", value: dimensions.formatArea(dimensions.totalFloorArea, unit: unit))
                DetailRow(label: "Wall Area", value: dimensions.formatArea(dimensions.totalWallArea, unit: unit))
                DetailRow(label: "Ceiling Height", value: dimensions.format(dimensions.ceilingHeight, unit: unit))
                DetailRow(label: "Volume", value: dimensions.formatVolume(dimensions.roomVolume, unit: unit))
                Divider()
                DetailRow(label: "Walls", value: "\(dimensions.wallCount)")
                DetailRow(label: "Doors", value: "\(dimensions.doorCount)")
                DetailRow(label: "Windows", value: "\(dimensions.windowCount)")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - 3D Room Model Section

struct RoomModelSection: View {
    let capturedRoom: CapturedRoom
    let damages: [DetectedDamage]?
    let capturedFrames: [CapturedFrame]?
    let ceilingHeight: Float?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3D Room Model")
                .font(.headline)

            RoomModelViewer(
                capturedRoom: capturedRoom,
                damages: damages,
                capturedFrames: capturedFrames,
                ceilingHeight: ceilingHeight
            )
            .frame(height: 250)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            if let damages, !damages.isEmpty {
                Text("\(damages.count) damage locations marked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Text("ReportView Preview")
}
