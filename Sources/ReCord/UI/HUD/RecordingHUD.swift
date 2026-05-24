import SwiftUI

struct RecordingHUD: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: .red.opacity(0.6), radius: 6)
                Text("Recording")
                    .font(.subheadline.weight(.medium))
            }

            Button {
                Task { await appState.stopRecording() }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 16)
    }
}
