import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var licenseKey = ""

    var body: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Screen Recording", value: PermissionsManager.screenRecordingStatus.rawValue.capitalized)
                LabeledContent("Accessibility", value: PermissionsManager.accessibilityStatus.rawValue.capitalized)
                LabeledContent("Microphone", value: PermissionsManager.microphoneStatus.rawValue.capitalized)
                HStack {
                    Button("Request Prompts") {
                        Task { await appState.requestPermissions() }
                    }
                    Button("Open Screen Recording") {
                        PermissionsManager.openPrivacyPane(.screenRecording)
                    }
                    Button("Open Accessibility") {
                        PermissionsManager.openPrivacyPane(.accessibility)
                    }
                }
                Text("After enabling Screen Recording or Accessibility, quit and reopen ReCord if macOS does not update the status immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("License") {
                LabeledContent("Current Tier", value: appState.licenseManager.tier.rawValue.capitalized)
                if !appState.licenseManager.licensedEmail.isEmpty {
                    LabeledContent("Licensed To", value: appState.licenseManager.licensedEmail)
                }
                TextField("Paste signed ReCord license token", text: $licenseKey, axis: .vertical)
                HStack {
                    Button("Activate") {
                        do {
                            try appState.licenseManager.activate(key: licenseKey)
                            licenseKey = ""
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                    Button("Deactivate") {
                        try? appState.licenseManager.deactivate()
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
