import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var appState: AppState
    let session: RecordingSession
    @State private var titleDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: $titleDraft)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onSubmit {
                        appState.rename(session, to: titleDraft)
                    }
                Text("\(Int(session.displaySize.width))×\(Int(session.displaySize.height)) · \(Int(session.duration))s")
                    .foregroundStyle(.secondary)
            }

            Divider()

            GroupBox("Zoom") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Follow mouse during zoom", systemImage: "cursorarrow.motionlines")
                    Label("Auto zoom on clicks", systemImage: "plus.magnifyingglass")
                    Label("Drag keyframes on timeline", systemImage: "diamond")
                    Text("The preview overlay shows the export crop, cursor, and click pulse while the video plays.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Shortcut: Cmd+Shift+Z drops a manual zoom marker while recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Export") {
                VStack(alignment: .leading, spacing: 10) {
                    let gate = FeatureGate(tier: appState.licenseManager.tier)
                    Picker("Preset", selection: $appState.exportPreset) {
                        ForEach(ExportPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appState.exportPreset.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(gate.includesWatermark ? "Watermark enabled" : "No watermark", systemImage: gate.includesWatermark ? "drop" : "checkmark.seal")

                    Button("Export MP4") {
                        Task { await appState.exportSelectedSession() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isExporting || (appState.exportPreset.requiresPro && appState.licenseManager.tier != .pro))

                    if appState.isExporting {
                        ProgressView(value: appState.exportProgress) {
                            Text("Exporting \(Int(appState.exportProgress * 100))%")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !appState.exportLogLines.isEmpty {
                GroupBox("Export Log") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(appState.exportLogLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 110)
                }
            }

            if let exported = session.exportedVideoURL {
                GroupBox("Last Export") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exported.path)
                            .font(.caption)
                            .textSelection(.enabled)
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([exported])
                        }
                    }
                }
            }

            GroupBox("Library") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Reveal Recording") {
                        appState.reveal(session)
                    }
                    Button("Delete Recording", role: .destructive) {
                        appState.delete(session)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            titleDraft = session.title
        }
        .onChange(of: session.id) { _ in
            titleDraft = session.title
        }
    }
}
