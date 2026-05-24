import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var licenseKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MC.signal)
                            .frame(width: 4, height: 4)
                        Text("Smoothness")
                            .mcEyebrow()
                    }
                    Text("Control how zooms and camera follow behave.")
                        .mcBody(size: 13)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 28) {
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
                    .background(MC.border)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(MC.signal)
                            .frame(width: 4, height: 4)
                        Text("License")
                            .mcEyebrow()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tier")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(MC.textMuted)
                        Spacer()
                        Text(appState.licenseManager.tier.rawValue.capitalized)
                            .font(MC.label(14))
                            .foregroundStyle(MC.textPrimary)
                    }
                    if !appState.licenseManager.licensedEmail.isEmpty {
                        HStack {
                            Text("Licensed To")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(MC.textMuted)
                            Spacer()
                            Text(appState.licenseManager.licensedEmail)
                                .font(MC.label(14))
                                .foregroundStyle(MC.textPrimary)
                        }
                    }
                    TextField("Paste license token", text: $licenseKey, axis: .vertical)
                        .font(.system(size: 13, design: .rounded))
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(MC.textPrimary)
                    HStack(spacing: 12) {
                        Button("Activate") {
                            do {
                                try appState.licenseManager.activate(key: licenseKey)
                                licenseKey = ""
                            } catch {
                                appState.errorMessage = error.localizedDescription
                            }
                        }
                        .buttonStyle(SmallPillButton())
                        Button("Deactivate") {
                            try? appState.licenseManager.deactivate()
                        }
                        .buttonStyle(SmallPillButton())
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 480)
        .background(MC.surface)
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
                    .font(MC.label(13))
                    .foregroundStyle(MC.textPrimary)
                Spacer()
                Text(formatter(value.wrappedValue))
                    .font(MC.label(13).monospacedDigit())
                    .foregroundStyle(MC.textMuted)
            }
            Slider(value: value, in: range, step: step) { _ in
                onChange(value.wrappedValue)
            }
            .tint(MC.signal)
            Text(description)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(MC.textMuted)
        }
    }
}
