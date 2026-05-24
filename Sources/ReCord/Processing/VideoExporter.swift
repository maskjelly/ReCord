import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

struct ExportOptions: Sendable {
    var outputSize: CGSize
    var codec: AVVideoCodecType
    var bitrate: Int
    var includeWatermark: Bool
    var followMouse: Bool
    var frameRate: Int

    static let free1080p = ExportOptions(
        outputSize: CGSize(width: 1920, height: 1080),
        codec: .h264,
        bitrate: 12_000_000,
        includeWatermark: true,
        followMouse: true,
        frameRate: 60
    )

    static let pro4K = ExportOptions(
        outputSize: CGSize(width: 3840, height: 2160),
        codec: .hevc,
        bitrate: 35_000_000,
        includeWatermark: false,
        followMouse: true,
        frameRate: 60
    )
}

enum VideoExporterError: LocalizedError {
    case missingVideoTrack
    case cannotCreateReader
    case cannotCreateWriter
    case cannotCreatePixelBuffer
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack: return "The recording does not contain a video track."
        case .cannotCreateReader: return "Could not create a video reader."
        case .cannotCreateWriter: return "Could not create a video writer."
        case .cannotCreatePixelBuffer: return "Could not allocate an output pixel buffer."
        case .exportFailed(let message): return message
        }
    }
}

final class VideoExporter {
    func export(
        session: RecordingSession,
        options: ExportOptions,
        progress: @escaping @Sendable (Double) -> Void,
        log: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try ReCordStorage.ensureDirectories()
            let folder = ReCordStorage.recordingsDirectory.appendingPathComponent(session.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let renderedURL = folder.appendingPathComponent("rendered.mov")
            let mp4URL = folder.appendingPathComponent("ReCord-export.mp4")
            try Self.removeIfNeeded(renderedURL)
            try Self.removeIfNeeded(mp4URL)

            log("Preparing \(options.frameRate) fps \(Int(options.outputSize.width))x\(Int(options.outputSize.height)) export")
            try await self.renderVideoOnly(session: session, options: options, outputURL: renderedURL, progress: progress, log: log)
            let output = try await self.muxAudio(originalSession: session, renderedVideoURL: renderedURL, outputURL: mp4URL, log: log)
            progress(1.0)
            log("Export complete: \(output.lastPathComponent)")
            return output
        }.value
    }

    private func renderVideoOnly(
        session: RecordingSession,
        options: ExportOptions,
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void,
        log: @escaping @Sendable (String) -> Void
    ) async throws {
        let asset = AVAsset(url: session.rawVideoURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.missingVideoTrack
        }

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else { throw VideoExporterError.cannotCreateReader }
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: options.bitrate,
            AVVideoMaxKeyFrameIntervalKey: options.frameRate,
            AVVideoExpectedSourceFrameRateKey: options.frameRate,
            AVVideoAllowFrameReorderingKey: false
        ]
        if options.codec == .h264 {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: options.codec,
            AVVideoWidthKey: Int(options.outputSize.width),
            AVVideoHeightKey: Int(options.outputSize.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.mediaTimeScale = CMTimeScale(options.frameRate * 10)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(options.outputSize.width),
                kCVPixelBufferHeightKey as String: Int(options.outputSize.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(writerInput) else { throw VideoExporterError.cannotCreateWriter }
        writer.add(writerInput)

        let engine = ZoomEngine(
            displaySize: session.displaySize.cgSize,
            cursorEvents: session.cursorEvents,
            keyframes: session.zoomKeyframes,
            configuration: ZoomEngineConfiguration.default(outputSize: options.outputSize, followMouse: options.followMouse)
        )
        let pipeline = TransformPipeline()
        let videoDuration = try await videoTrack.load(.timeRange).duration.seconds
        let duration: TimeInterval
        if session.duration.isFinite, session.duration > 0 {
            duration = session.duration
        } else if videoDuration.isFinite, videoDuration > 0 {
            duration = videoDuration
        } else {
            duration = 0.001
        }
        log("Source video: \(Int(session.displaySize.width))x\(Int(session.displaySize.height)), \(String(format: "%.1f", duration))s")

        guard reader.startReading() else {
            throw VideoExporterError.exportFailed(reader.error?.localizedDescription ?? "Reader failed to start.")
        }
        guard writer.startWriting() else {
            throw VideoExporterError.exportFailed(writer.error?.localizedDescription ?? "Writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let frameRate = max(options.frameRate, 1)
        let totalFrames = max(1, Int(ceil(duration * Double(frameRate))))
        log("Rendering \(totalFrames) frames")
        var currentSampleBuffer = readerOutput.copyNextSampleBuffer()
        var nextSampleBuffer = readerOutput.copyNextSampleBuffer()
        var lastLoggedPercent = -1

        guard currentSampleBuffer != nil else {
            throw VideoExporterError.missingVideoTrack
        }

        for frameIndex in 0..<totalFrames {
            let outputTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))

            while let candidate = nextSampleBuffer {
                let candidateTime = CMSampleBufferGetPresentationTimeStamp(candidate)
                guard CMTimeCompare(candidateTime, outputTime) <= 0 else { break }
                currentSampleBuffer = candidate
                nextSampleBuffer = readerOutput.copyNextSampleBuffer()
            }

            guard let sampleBuffer = currentSampleBuffer,
                  let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            guard let pool = adaptor.pixelBufferPool else { throw VideoExporterError.cannotCreatePixelBuffer }

            var outBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer)
            guard let outputBuffer = outBuffer else { throw VideoExporterError.cannotCreatePixelBuffer }

            let seconds = outputTime.seconds.isFinite ? outputTime.seconds : 0
            let state = engine.state(at: seconds)
            pipeline.render(
                sourceBuffer: sourceBuffer,
                state: state,
                outputBuffer: outputBuffer,
                outputSize: options.outputSize,
                includeWatermark: options.includeWatermark
            )

            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }

            guard adaptor.append(outputBuffer, withPresentationTime: outputTime) else {
                throw VideoExporterError.exportFailed(writer.error?.localizedDescription ?? "Could not append exported video frame.")
            }
            let value = min(max(seconds / duration, 0), 0.92)
            progress(value)
            let percent = Int(value * 100)
            if percent >= lastLoggedPercent + 10 {
                lastLoggedPercent = percent
                log("Rendered \(min(frameIndex + 1, totalFrames))/\(totalFrames) frames (\(percent)%)")
            }
        }

        writerInput.markAsFinished()
        log("Finalizing rendered video")
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if let error = writer.error {
            throw VideoExporterError.exportFailed(error.localizedDescription)
        }
    }

    private func muxAudio(originalSession session: RecordingSession, renderedVideoURL: URL, outputURL: URL, log: @escaping @Sendable (String) -> Void) async throws -> URL {
        let composition = AVMutableComposition()
        let renderedAsset = AVAsset(url: renderedVideoURL)
        let originalAsset = AVAsset(url: session.rawVideoURL)

        guard let sourceVideo = try await renderedAsset.loadTracks(withMediaType: .video).first else {
            throw VideoExporterError.missingVideoTrack
        }

        let duration = try await renderedAsset.load(.duration)
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try videoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideo, at: .zero)
        videoTrack?.preferredTransform = try await sourceVideo.load(.preferredTransform)

        log("Muxing audio")
        for audioTrack in try await originalAsset.loadTracks(withMediaType: .audio) {
            let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            let sourceRange = try await audioTrack.load(.timeRange)
            let range = CMTimeRange(start: sourceRange.start, duration: min(duration, sourceRange.duration))
            try track?.insertTimeRange(range, of: audioTrack, at: .zero)
        }

        if let micURL = session.microphoneAudioURL {
            let micAsset = AVAsset(url: micURL)
            let micDuration = try await micAsset.load(.duration)
            for audioTrack in try await micAsset.loadTracks(withMediaType: .audio) {
                let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                let sourceRange = try await audioTrack.load(.timeRange)
                let range = CMTimeRange(start: sourceRange.start, duration: min(duration, min(micDuration, sourceRange.duration)))
                try track?.insertTimeRange(range, of: audioTrack, at: .zero)
            }
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExporterError.cannotCreateWriter
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        log("Writing final MP4")

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        if exporter.status == .completed {
            return outputURL
        }

        throw VideoExporterError.exportFailed(exporter.error?.localizedDescription ?? "Audio muxing failed.")
    }

    private static func removeIfNeeded(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
