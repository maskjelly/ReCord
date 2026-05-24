import SwiftUI

struct MainWindow: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingRecordingSetup = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack(alignment: .top) {
                EditorView()
                if appState.isRecording {
                    RecordingHUD()
                        .padding(.top, 20)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.isRecording {
                    Button {
                        Task { await appState.stopRecording() }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop Recording")
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        isShowingRecordingSetup = true
                        Task { await appState.loadCaptureTargets() }
                    } label: {
                        Image(systemName: "record.circle")
                    }
                    .help("Start Recording")
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                Button {
                    Task { await appState.exportSelectedSession() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export")
                .disabled(appState.selectedSession == nil || appState.isExporting)
            }
        }
        .alert("ReCord", isPresented: Binding(get: { appState.errorMessage != nil }, set: { if !$0 { appState.errorMessage = nil } })) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .sheet(isPresented: $isShowingRecordingSetup) {
            RecordingSetupView(isPresented: $isShowingRecordingSetup)
                .environmentObject(appState)
        }
    }
}

private struct RecordingSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Recording")
                    .font(.title2.weight(.semibold))
                Text("Choose where to save and what to capture.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save Location")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.recordingSaveDirectory?.lastPathComponent ?? "No folder")
                                .font(.callout.weight(.medium))
                            Text(appState.recordingSaveDirectory?.path ?? "Choose a folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Choose...") {
                            appState.chooseRecordingDirectory()
                        }
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Source")
                        .font(.subheadline.weight(.medium))
                    if appState.captureTargets.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading screens and windows...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    } else {
                        Picker("", selection: $appState.selectedCaptureTargetID) {
                            ForEach(appState.captureTargets) { target in
                                Text("\(target.kind == .display ? "Screen" : "Window"): \(target.label)")
                                    .tag(Optional(target.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Spacer()

            HStack {
                Button("Refresh") {
                    Task { await appState.loadCaptureTargets() }
                }
                .controlSize(.small)
                Spacer()
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .controlSize(.small)
                Button("Start") {
                    isPresented = false
                    Task { await appState.startRecording() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appState.recordingSaveDirectory == nil || appState.selectedCaptureTarget == nil)
            }
        }
        .padding(28)
        .frame(width: 520, height: 340)
        .task {
            if appState.captureTargets.isEmpty {
                await appState.loadCaptureTargets()
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ReCord")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            PermissionsPanel()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            List(selection: $appState.selectedSessionID) {
                Section {
                    ForEach(appState.sessions) { session in
                        SessionRow(session: session)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Recordings")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(appState.sessions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Spacer()

            HStack {
                Image(systemName: appState.licenseManager.tier == .pro ? "checkmark.seal.fill" : "person")
                    .foregroundStyle(appState.licenseManager.tier == .pro ? .green : .secondary)
                Text(appState.licenseManager.tier.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
        }
        .frame(minWidth: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct SessionRow: View {
    let session: RecordingSession
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(session.exportedVideoURL != nil ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: session.exportedVideoURL != nil ? "checkmark" : "film")
                        .font(.caption)
                        .foregroundStyle(session.exportedVideoURL != nil ? .green : .secondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(Int(session.duration))s · \(session.zoomKeyframes.count) markers")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder") { appState.reveal(session) }
            Button("Delete", role: .destructive) { appState.delete(session) }
        }
    }
}

private struct PermissionsPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Permissions")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await appState.requestPermissions() }
                } label: {
                    Text("Request All")
                        .font(.caption2)
                }
                .controlSize(.mini)
                .disabled(appState.requiredPermissionsGranted)
            }

            VStack(alignment: .leading, spacing: 6) {
                PermissionRow(
                    name: "Screen Recording",
                    granted: PermissionsManager.screenRecordingStatus == .granted,
                    pane: .screenRecording
                )
                PermissionRow(
                    name: "Accessibility",
                    granted: PermissionsManager.accessibilityStatus == .granted,
                    pane: .accessibility
                )
                PermissionRow(
                    name: "Microphone",
                    granted: PermissionsManager.microphoneStatus == .granted,
                    pane: .microphone
                )
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { appState.refreshPermissionStatuses() }
    }
}

private struct PermissionRow: View {
    let name: String
    let granted: Bool
    let pane: PrivacyPane

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(granted ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption)
            Spacer()
            if !granted {
                Button {
                    PermissionsManager.openPrivacyPane(pane)
                } label: {
                    Text("Open")
                        .font(.caption2)
                }
                .controlSize(.mini)
            }
        }
    }
}
