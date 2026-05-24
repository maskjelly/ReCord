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
                        .background(MC.background)

                    TimelineView(session: session)
                        .frame(height: 120)
                        .background(MC.surface)
                }
                .safeAreaInset(edge: .trailing) {
                    InspectorView(session: session)
                        .frame(width: 260)
                        .background(MC.elevated)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(MC.textMuted)
                    Text("No Recording")
                        .mcHeadline(size: 20)
                    Text("Start a recording to create an editable project.")
                        .mcBody(size: 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MC.background)
            }
        }
        .overlay(alignment: .bottom) {
            if appState.isExporting {
                ExportProgressOverlay()
                    .padding(.bottom, 28)
            }
        }
    }
}

private struct ExportProgressOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exporting")
                    .font(MC.label(13))
                    .foregroundStyle(MC.textPrimary)
                Spacer()
                Text("\(Int(appState.exportProgress * 100))%")
                    .font(MC.label(13).monospacedDigit())
                    .foregroundStyle(MC.textMuted)
            }

            ProgressView(value: appState.exportProgress)
                .progressViewStyle(.linear)
                .tint(MC.signal)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(appState.exportLogLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(MC.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .frame(height: 72)
                .onChange(of: appState.exportLogLines.count) { _ in
                    if let last = appState.exportLogLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(MC.card)
        .clipShape(RoundedRectangle(cornerRadius: MC.radiusCard))
        .mcNavShadow()
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
                HStack(spacing: 6) {
                    Circle()
                        .fill(session.exportedVideoURL == nil ? MC.textMuted : MC.success)
                        .frame(width: 6, height: 6)
                    Text(session.exportedVideoURL == nil ? "Preview" : "Exported")
                        .font(MC.label(11))
                        .foregroundStyle(MC.textPrimary.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MC.background.opacity(0.7))
                .clipShape(Capsule())
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
            configuration: .default(
                outputSize: session.displaySize.cgSize,
                zoomRampMultiplier: ReCordStorage.zoomRampMultiplier,
                zoomSmoothingWindow: ReCordStorage.zoomSmoothingWindow,
                cameraSmoothingWindow: ReCordStorage.cameraSmoothingWindow
            )
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
                    .strokeBorder(MC.textPrimary.opacity(0.06), lineWidth: 1)
                    .frame(width: fitted.width, height: fitted.height)
                    .offset(x: fitted.minX, y: fitted.minY)

                Rectangle()
                    .stroke(MC.textPrimary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(MC.textPrimary.opacity(0.04))
                    .frame(width: viewport.width, height: viewport.height)
                    .offset(x: viewport.minX, y: viewport.minY)

                Circle()
                    .fill(state.clickPulse > 0 ? MC.lightSignal.opacity(0.4) : Color.clear)
                    .frame(width: 38 + state.clickPulse * 24, height: 38 + state.clickPulse * 24)
                    .offset(x: cursor.x - 19 - state.clickPulse * 12, y: cursor.y - 19 - state.clickPulse * 12)

                Circle()
                    .fill(MC.textPrimary)
                    .frame(width: 6, height: 6)
                    .shadow(radius: 3)
                    .offset(x: cursor.x - 3, y: cursor.y - 3)

                Text("\(String(format: "%.1f", state.zoom))×")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MC.textPrimary.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MC.background.opacity(0.7))
                    .clipShape(Capsule())
                    .offset(x: fitted.minX + 10, y: fitted.maxY - 30)
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
