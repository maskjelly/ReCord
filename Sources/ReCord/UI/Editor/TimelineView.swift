import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var appState: AppState
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                Spacer()
                Button("Add Manual Zoom") {
                    appState.addManualZoom(at: session.duration * 0.5)
                }
                .buttonStyle(.bordered)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.16))
                        .frame(height: 54)

                    ForEach(session.zoomKeyframes) { keyframe in
                        KeyframeMarker(keyframe: keyframe, session: session, width: proxy.size.width)
                    }

                    ForEach(session.cursorEvents.filter { $0.kind == .leftDown || $0.kind == .rightDown }.prefix(80)) { event in
                        Rectangle()
                            .fill(.blue.opacity(0.35))
                            .frame(width: 2, height: 30)
                            .offset(x: xOffset(for: event.timestamp, width: proxy.size.width), y: 12)
                    }
                }
            }
            .frame(height: 62)
        }
        .padding()
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
            .frame(width: 18, height: 18)
            .shadow(radius: 4)
            .offset(x: xOffset - 9, y: 18)
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
