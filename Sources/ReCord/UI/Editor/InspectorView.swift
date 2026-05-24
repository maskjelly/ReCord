import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var appState: AppState
    let session: RecordingSession
    @State private var titleDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MC.signal)
                            .frame(width: 4, height: 4)
                        Text("Project")
                            .mcEyebrow()
                    }
                    TextField("Title", text: $titleDraft)
                        .mcHeadline(size: 20)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            appState.rename(session, to: titleDraft)
                        }
                    Text("\(Int(session.displaySize.width))×\(Int(session.displaySize.height))  ·  \(Int(session.duration))s")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(MC.textMuted)
                }

                Divider()
                    .background(MC.border)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MC.signal)
                            .frame(width: 4, height: 4)
                        Text("Export")
                            .mcEyebrow()
                    }

                    HStack {
                        Text("1080p")
                            .font(MC.label(14))
                            .foregroundStyle(MC.textPrimary)
                        Spacer()
                        Text("1920×1080 H.264")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(MC.textMuted)
                    }
                    .padding(10)
                    .background(MC.card)
                    .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))

                    Button {
                        Task { await appState.exportSelectedSession() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Export MP4")
                                .font(MC.label(14))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SignalPillButton())
                    .disabled(appState.isExporting)

                    if appState.isExporting {
                        ProgressView(value: appState.exportProgress)
                            .progressViewStyle(.linear)
                            .tint(MC.signal)
                    }
                }

                if !appState.exportLogLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(MC.signal)
                                .frame(width: 4, height: 4)
                            Text("Log")
                                .mcEyebrow()
                        }
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(appState.exportLogLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(MC.textMuted)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                }

                if let exported = session.exportedVideoURL {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(MC.signal)
                                .frame(width: 4, height: 4)
                            Text("Last Export")
                                .mcEyebrow()
                        }
                        Text(exported.lastPathComponent)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(MC.textMuted)
                            .lineLimit(1)
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([exported])
                        }
                        .buttonStyle(SmallPillButton())
                    }
                }

                Divider()
                    .background(MC.border)

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        appState.reveal(session)
                    } label: {
                        Label("Reveal Recording", systemImage: "folder")
                            .font(MC.label(12))
                    }
                    .buttonStyle(SmallPillButton())

                    Button(role: .destructive) {
                        appState.delete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(MC.label(12))
                    }
                    .buttonStyle(SmallPillButton())
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }
}
