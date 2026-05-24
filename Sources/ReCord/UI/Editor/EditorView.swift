import AVKit
import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let session = appState.selectedSession {
                VStack(spacing: 0) {
                    VideoPreview(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.92))

                    TimelineView(session: session)
                        .frame(height: 132)
                        .background(.regularMaterial)
                }
                .safeAreaInset(edge: .trailing) {
                    InspectorView(session: session)
                        .frame(width: 280)
                        .background(.thinMaterial)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No Recording Selected")
                        .font(.title2.bold())
                    Text("Start a recording to create an editable ReCord project.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            if appState.isExporting {
                ExportProgressOverlay(progress: appState.exportProgress, logs: appState.exportLogLines)
                    .padding(.bottom, 24)
            }
        }
    }
}

private struct ExportProgressOverlay: View {
    let progress: Double
    let logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exporting")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .frame(height: 96)
                .onChange(of: logs.count) { _ in
                    if let last = logs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 18)
    }
}

private struct VideoPreview: View {
    let session: RecordingSession
    @State private var player: AVPlayer?
    @State private var currentTime: TimeInterval = 0
    private let timer = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common).autoconnect()

    var body: some View {
        PlayerView(player: player)
            .onAppear { configurePlayer() }
            .onChange(of: session.id) { _ in configurePlayer() }
            .onReceive(timer) { _ in
                currentTime = player?.currentTime().seconds ?? 0
            }
            .overlay {
                ZoomPreviewOverlay(session: session, currentTime: currentTime)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.exportedVideoURL == nil ? "Raw Preview" : "Exported Preview")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    Text(session.rawVideoURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
    }

    private func configurePlayer() {
        let url = session.exportedVideoURL ?? session.rawVideoURL
        let item = AVPlayerItem(asset: previewAsset(for: session, url: url))
        item.forwardPlaybackEndTime = CMTime(seconds: session.duration, preferredTimescale: 600)
        let player = AVPlayer(playerItem: item)
        self.player = player
        currentTime = 0
    }

    private func previewAsset(for session: RecordingSession, url: URL) -> AVAsset {
        guard session.exportedVideoURL == nil else {
            return AVURLAsset(url: url)
        }

        let source = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        let previewDuration = CMTime(seconds: max(session.duration, 0.001), preferredTimescale: 600)

        if let sourceVideo = source.tracks(withMediaType: .video).first,
           let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let sourceRange = sourceVideo.timeRange
            let range = CMTimeRange(start: sourceRange.start, duration: min(previewDuration, sourceRange.duration))
            try? videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
            videoTrack.preferredTransform = sourceVideo.preferredTransform
        }

        if let sourceAudio = source.tracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let sourceRange = sourceAudio.timeRange
            let range = CMTimeRange(start: sourceRange.start, duration: min(previewDuration, sourceRange.duration))
            try? audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
        }

        return composition
    }
}

private struct PlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

private struct ZoomPreviewOverlay: View {
    let session: RecordingSession
    let currentTime: TimeInterval

    private var frameState: ZoomFrameState {
        let engine = ZoomEngine(
            displaySize: session.displaySize.cgSize,
            cursorEvents: session.cursorEvents,
            keyframes: session.zoomKeyframes,
            configuration: .default(outputSize: session.displaySize.cgSize)
        )
        return engine.state(at: currentTime)
    }

    var body: some View {
        GeometryReader { proxy in
            let fitted = fittedRect(source: session.displaySize.cgSize, in: proxy.size)
            let state = frameState
            let viewport = map(rect: state.viewport, from: session.displaySize.cgSize, to: fitted)
            let cursor = map(point: state.cursorPosition, from: session.displaySize.cgSize, to: fitted)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: fitted.width, height: fitted.height)
                    .offset(x: fitted.minX, y: fitted.minY)

                Rectangle()
                    .stroke(.yellow.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .background(Color.yellow.opacity(0.08))
                    .frame(width: viewport.width, height: viewport.height)
                    .offset(x: viewport.minX, y: viewport.minY)

                Circle()
                    .fill(state.clickPulse > 0 ? Color.orange.opacity(0.35) : Color.clear)
                    .frame(width: 42 + state.clickPulse * 28, height: 42 + state.clickPulse * 28)
                    .offset(x: cursor.x - 21 - state.clickPulse * 14, y: cursor.y - 21 - state.clickPulse * 14)

                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                    .shadow(radius: 4)
                    .offset(x: cursor.x - 4, y: cursor.y - 4)

                Text("\(String(format: "%.1f", state.zoom))x zoom preview")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(x: fitted.minX + 12, y: fitted.maxY - 38)
            }
        }
    }

    private func fittedRect(source: CGSize, in container: CGSize) -> CGRect {
        guard source.width > 0, source.height > 0, container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / source.width, container.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func map(rect: CGRect, from source: CGSize, to fitted: CGRect) -> CGRect {
        let scaleX = fitted.width / max(source.width, 1)
        let scaleY = fitted.height / max(source.height, 1)
        return CGRect(
            x: fitted.minX + rect.minX * scaleX,
            y: fitted.minY + rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    private func map(point: CGPoint, from source: CGSize, to fitted: CGRect) -> CGPoint {
        CGPoint(
            x: fitted.minX + point.x / max(source.width, 1) * fitted.width,
            y: fitted.minY + point.y / max(source.height, 1) * fitted.height
        )
    }
}
