import SwiftUI

struct MainWindow: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingRecordingSetup = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                PermissionBanner()
                ZStack(alignment: .top) {
                    EditorView()
                    if appState.isRecording {
                        RecordingHUD()
                            .padding(.top, 18)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Permissions") {
                    Task { await appState.requestPermissions() }
                }

                if appState.isRecording {
                    Button("Stop") { Task { await appState.stopRecording() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    Button("Record") {
                        isShowingRecordingSetup = true
                        Task { await appState.loadCaptureTargets() }
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                }

                Button("Export") {
                    Task { await appState.exportSelectedSession() }
                }
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Recording")
                    .font(.title2.bold())
                Text("Choose where to save it and what ReCord should capture.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Save Location") {
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.recordingSaveDirectory?.lastPathComponent ?? "No folder selected")
                            .font(.headline)
                        Text(appState.recordingSaveDirectory?.path ?? "Pick a folder before recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Choose...") {
                        appState.chooseRecordingDirectory()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Capture") {
                VStack(alignment: .leading, spacing: 10) {
                    if appState.captureTargets.isEmpty {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading screens and windows...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Source", selection: $appState.selectedCaptureTargetID) {
                            ForEach(appState.captureTargets) { target in
                                Text("\(target.kind == .display ? "Screen" : "Window"): \(target.label)")
                                    .tag(Optional(target.id))
                            }
                        }
                        .labelsHidden()

                        if let target = appState.selectedCaptureTarget {
                            Label(target.detail, systemImage: target.kind == .display ? "display" : "macwindow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Refresh Sources") {
                    Task { await appState.loadCaptureTargets() }
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
                Button("Start Recording") {
                    isPresented = false
                    Task { await appState.startRecording() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.recordingSaveDirectory == nil || appState.selectedCaptureTarget == nil)
            }
        }
        .padding(24)
        .frame(width: 560)
        .task {
            if appState.captureTargets.isEmpty {
                await appState.loadCaptureTargets()
            }
        }
    }
}

private struct PermissionBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if !appState.requiredPermissionsGranted {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions required before recording")
                        .font(.headline)
                    Text("macOS requires Screen Recording and Accessibility approval for screen capture and mouse-follow zooms.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Screen Recording") { PermissionsManager.openPrivacyPane(.screenRecording) }
                Button("Accessibility") { PermissionsManager.openPrivacyPane(.accessibility) }
                Button("Refresh") { appState.refreshPermissionStatuses() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .onAppear {
                appState.refreshPermissionStatuses()
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ReCord")
                    .font(.largeTitle.bold())
                Text(appState.statusMessage)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            Picker("Tier", selection: Binding(get: { appState.licenseManager.tier }, set: { _ in })) {
                ForEach(LicenseTier.allCases) { tier in
                    Text(tier.rawValue.capitalized).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .disabled(true)
            .padding(.horizontal)

            List(selection: $appState.selectedSessionID) {
                Section("Recordings") {
                    ForEach(appState.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text("\(Int(session.duration))s · \(session.zoomKeyframes.count) zooms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(session.id)
                        .contextMenu {
                            Button("Reveal in Finder") { appState.reveal(session) }
                            Button("Delete", role: .destructive) { appState.delete(session) }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 260)
    }
}
