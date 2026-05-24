import SwiftUI

struct RecordingHUD: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .shadow(color: .red.opacity(0.7), radius: 8)

            Text("Recording")
                .font(.headline)

            Button("Stop") {
                Task { await appState.stopRecording() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 18)
    }
}
