import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var appState: AppState
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    appState.addManualZoom(at: session.duration * 0.5)
                } label: {
                    Label("Add Marker", systemImage: "plus.diamond")
                }
                .controlSize(.small)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 48)

                    ForEach(session.zoomKeyframes) { keyframe in
                        KeyframeMarker(keyframe: keyframe, session: session, width: proxy.size.width)
                    }

                    ForEach(session.cursorEvents.filter { $0.kind == .leftDown || $0.kind == .rightDown }.prefix(80)) { event in
                        Rectangle()
                            .fill(.blue.opacity(0.25))
                            .frame(width: 1.5, height: 24)
                            .offset(x: xOffset(for: event.timestamp, width: proxy.size.width), y: 12)
                    }
                }
            }
            .frame(height: 56)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func xOffset(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard session.duration > 0 else { return 0 }
        return CGFloat(time / session.duration) * width
    }
}

private struct KeyframeMarker: View {
    @EnvironmentObject private var appState: AppState
    let keyframe: ZoomKeyframe
    let session: RecordingSession
    let width: CGFloat

    var body: some View {
        Diamond()
            .fill(keyframe.source == .manual ? Color.orange : Color.yellow)
            .frame(width: 14, height: 14)
            .shadow(radius: 3)
            .offset(x: xOffset - 7, y: 17)
            .gesture(
                DragGesture().onChanged { value in
                    let normalized = max(0, min(1, Double((xOffset + value.translation.width) / width)))
                    appState.moveKeyframe(keyframe, to: normalized * session.duration)
                }
            )
            .contextMenu {
                Button("Delete") { appState.deleteKeyframe(keyframe) }
            }
            .help("\(keyframe.source.rawValue.capitalized) zoom at \(String(format: "%.2f", keyframe.timestamp))s")
    }

    private var xOffset: CGFloat {
        guard session.duration > 0 else { return 0 }
        return CGFloat(keyframe.timestamp / session.duration) * width
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
