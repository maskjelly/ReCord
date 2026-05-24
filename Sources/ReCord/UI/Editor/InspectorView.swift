import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var appState: AppState
    let session: RecordingSession
    @State private var titleDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: $titleDraft)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)
                        .onSubmit {
                            appState.rename(session, to: titleDraft)
                        }
                    Text("\(Int(session.displaySize.width))×\(Int(session.displaySize.height))  ·  \(Int(session.duration))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Export")
                        .font(.subheadline.weight(.semibold))

                    Picker("Preset", selection: $appState.exportPreset) {
                        ForEach(ExportPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    HStack {
                        Text(appState.exportPreset.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if appState.exportPreset.requiresPro && appState.licenseManager.tier != .pro {
                            Text("Pro")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    Button {
                        Task { await appState.exportSelectedSession() }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export MP4")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isExporting)

                    if appState.isExporting {
                        ProgressView(value: appState.exportProgress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                    }
                }

                if !appState.exportLogLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log")
                            .font(.subheadline.weight(.semibold))
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(appState.exportLogLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(height: 90)
                    }
                }

                if let exported = session.exportedVideoURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Export")
                            .font(.subheadline.weight(.semibold))
                        Text(exported.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([exported])
                        }
                        .controlSize(.small)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        appState.reveal(session)
                    } label: {
                        Label("Reveal Recording", systemImage: "folder")
                    }
                    .controlSize(.small)

                    Button(role: .destructive) {
                        appState.delete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .controlSize(.small)
                }

                Spacer(minLength: 20)
            }
            .padding(16)
        }
    }
}
