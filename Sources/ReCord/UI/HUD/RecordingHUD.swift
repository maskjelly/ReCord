import SwiftUI

struct RecordingHUD: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(MC.signal)
                    .frame(width: 8, height: 8)
                    .shadow(color: MC.signal.opacity(0.5), radius: 6)
                Text("Recording")
                    .font(MC.label(13))
                    .foregroundStyle(MC.textPrimary)
            }

            Button {
                Task { await appState.stopRecording() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MC.textPrimary)
            }
            .buttonStyle(.borderedProminent)
            .tint(MC.signal)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(MC.card)
        .clipShape(Capsule())
        .mcNavShadow()
    }
}
