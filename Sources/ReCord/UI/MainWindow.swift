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
                        .padding(.top, 24)
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
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .help("Stop")
                    .buttonStyle(.borderedProminent)
                    .tint(MC.signal)
                } else {
                    Button {
                        isShowingRecordingSetup = true
                        Task { await appState.loadCaptureTargets() }
                    } label: {
                        Image(systemName: "record.circle")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .help("Record")
                    .buttonStyle(.borderedProminent)
                    .tint(MC.signal)
                }

                Button {
                    Task { await appState.exportSelectedSession() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(MC.signal)
                        .frame(width: 8, height: 8)
                    Text("New Recording")
                        .mcEyebrow()
                }
                Text("Choose where to save and what to capture.")
                    .mcBody(size: 14)
            }

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save Location")
                        .font(MC.label(13))
                        .foregroundStyle(MC.textPrimary)
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundStyle(MC.textMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.recordingSaveDirectory?.lastPathComponent ?? "No folder")
                                .font(MC.label(14))
                                .foregroundStyle(MC.textPrimary)
                            Text(appState.recordingSaveDirectory?.path ?? "Choose a folder")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(MC.textMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Choose...") {
                            appState.chooseRecordingDirectory()
                        }
                        .buttonStyle(SmallPillButton())
                    }
                    .padding(12)
                    .background(MC.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Source")
                        .font(MC.label(13))
                        .foregroundStyle(MC.textPrimary)
                    if appState.captureTargets.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading screens and windows...")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(MC.textMuted)
                        }
                        .padding(12)
                        .background(MC.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
                    } else {
                        Picker("", selection: $appState.selectedCaptureTargetID) {
                            ForEach(appState.captureTargets) { target in
                                Text("\(target.kind == .display ? "Screen" : "Window"): \(target.label)")
                                    .tag(Optional(target.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(MC.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
                    }
                }
            }

            Spacer()

            HStack {
                Button("Refresh") {
                    Task { await appState.loadCaptureTargets() }
                }
                .buttonStyle(SmallPillButton())
                Spacer()
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                .buttonStyle(SmallPillButton())
                Button("Start") {
                    isPresented = false
                    Task { await appState.startRecording() }
                }
                .buttonStyle(SignalPillButton())
                .disabled(appState.recordingSaveDirectory == nil || appState.selectedCaptureTarget == nil)
            }
        }
        .padding(32)
        .frame(width: 520, height: 360)
        .background(MC.surface)
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
            VStack(alignment: .leading, spacing: 6) {
                Text("ReCord")
                    .mcHeadline(size: 24)
                Text(appState.statusMessage)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(MC.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            PermissionsPanel()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()
                .background(MC.border)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            List(selection: $appState.selectedSessionID) {
                Section {
                    ForEach(appState.sessions) { session in
                        SessionRow(session: session)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(MC.signal)
                                .frame(width: 4, height: 4)
                            Text("Recordings")
                                .mcEyebrow()
                        }
                        Spacer()
                        Text("\(appState.sessions.count)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(MC.textMuted)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: appState.licenseManager.tier == .pro ? "checkmark.seal.fill" : "person")
                    .font(.system(size: 10))
                    .foregroundStyle(appState.licenseManager.tier == .pro ? MC.signal : MC.textMuted)
                Text(appState.licenseManager.tier.rawValue.capitalized)
                    .font(MC.label(11))
                    .foregroundStyle(MC.textMuted)
                Spacer()
            }
            .padding(12)
            .background(MC.elevated)
            .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 260)
        .background(MC.surface)
    }
}

private struct SessionRow: View {
    let session: RecordingSession
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.exportedVideoURL != nil ? MC.signal.opacity(0.15) : MC.elevated)
                    .frame(width: 36, height: 36)
                Image(systemName: session.exportedVideoURL != nil ? "checkmark" : "film")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(session.exportedVideoURL != nil ? MC.signal : MC.textMuted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(MC.label(13))
                    .foregroundStyle(MC.textPrimary)
                    .lineLimit(1)
                Text("\(Int(session.duration))s  ·  \(session.zoomKeyframes.count) markers")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(MC.textMuted)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(appState.selectedSessionID == session.id ? MC.elevated : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: MC.radiusSmall))
        .contextMenu {
            Button("Reveal in Finder") { appState.reveal(session) }
            Button("Delete", role: .destructive) { appState.delete(session) }
        }
    }
}

private struct PermissionsPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(MC.textMuted)
                Text("Permissions")
                    .mcEyebrow()
                Spacer()
                Button {
                    Task { await appState.requestPermissions() }
                } label: {
                    Text("Request")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .buttonStyle(SmallPillButton())
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
        .padding(12)
        .background(MC.elevated)
        .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
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
                .fill(granted ? MC.success : MC.signal)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(MC.textSecondary)
            Spacer()
            if !granted {
                Button {
                    PermissionsManager.openPrivacyPane(pane)
                } label: {
                    Text("Open")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .buttonStyle(SmallPillButton())
            }
        }
    }
}
