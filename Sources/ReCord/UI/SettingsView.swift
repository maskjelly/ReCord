import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var licenseKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header("Smoothness")
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    sliderRow(
                        title: "Zoom Duration",
                        value: $appState.zoomRampMultiplier,
                        range: 0.2...4.0,
                        step: 0.1,
                        formatter: { "\(String(format: "%.1f", $0))×" },
                        description: "Higher values make zooms slower and more gradual."
                    ) { appState.setZoomRampMultiplier($0) }

                    sliderRow(
                        title: "Zoom Smoothing",
                        value: $appState.zoomSmoothingWindow,
                        range: 0...2.0,
                        step: 0.05,
                        formatter: { "\(String(format: "%.2f", $0))s" },
                        description: "Blends zoom transitions so they never snap."
                    ) { appState.setZoomSmoothingWindow($0) }

                    sliderRow(
                        title: "Camera Follow",
                        value: $appState.cameraSmoothingWindow,
                        range: 0.05...4.0,
                        step: 0.05,
                        formatter: { "\(String(format: "%.2f", $0))s" },
                        description: "Higher values make the camera gently lag behind the cursor."
                    ) { appState.setCameraSmoothingWindow($0) }
                }

                Divider()

                header("License")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tier")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(appState.licenseManager.tier.rawValue.capitalized)
                            .fontWeight(.medium)
                    }
                    if !appState.licenseManager.licensedEmail.isEmpty {
                        HStack {
                            Text("Licensed To")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(appState.licenseManager.licensedEmail)
                                .fontWeight(.medium)
                        }
                    }
                    TextField("Paste license token", text: $licenseKey, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
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
                    .controlSize(.small)
                }

                Spacer(minLength: 20)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 480)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, design: .rounded).weight(.semibold))
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        formatter: (Double) -> String,
        description: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(formatter(value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step) { _ in
                onChange(value.wrappedValue)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

}
