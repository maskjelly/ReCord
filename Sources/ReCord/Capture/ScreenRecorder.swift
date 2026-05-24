import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

struct ScreenRecordingResult: Sendable {
    var url: URL
    var displaySize: CGSize
    var duration: TimeInterval
}

enum ScreenRecorderError: LocalizedError {
    case screenPermissionRequired
    case displayUnavailable
    case targetUnavailable
    case writerUnavailable
    case streamUnavailable
    case noVideoFramesCaptured
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenPermissionRequired: return "ReCord needs Screen Recording permission."
        case .displayUnavailable: return "No display was available for recording."
        case .targetUnavailable: return "The selected screen or window is no longer available."
        case .writerUnavailable: return "Could not prepare the screen recording writer."
        case .streamUnavailable: return "ScreenCaptureKit stream could not be started."
        case .noVideoFramesCaptured: return "No video frames were captured. Check Screen Recording permission, then try recording a screen instead of a minimized or protected window."
        case .writerFailed(let message): return "Recording writer failed: \(message)"
        }
    }
}

final class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {
    private let sampleQueue = DispatchQueue(label: "ReCord.ScreenRecorder.SampleQueue")
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var didStartWriting = false
    private var firstVideoTime: CMTime?
    private var firstAudioTime: CMTime?
    private var capturedVideoFrameCount = 0
    private var writerFailureMessage: String?
    private var recordingStartedAt: Date?
    private var outputURL: URL?
    private var displaySize: CGSize = .zero

    var isRecording: Bool { stream != nil }

    static func availableTargets() async throws -> [CaptureTarget] {
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw ScreenRecorderError.screenPermissionRequired
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displays = content.displays.enumerated().map { index, display in
            let bounds = CGDisplayBounds(display.displayID)
            return CaptureTarget(
                id: "display-\(display.displayID)",
                kind: .display,
                numericID: display.displayID,
                title: "Screen \(index + 1)",
                detail: "Full display",
                size: Size2D(width: Double(display.width), height: Double(display.height)),
                globalOrigin: Point2D(x: bounds.minX, y: bounds.minY),
                globalSize: Size2D(width: bounds.width, height: bounds.height)
            )
        }

        let windows = content.windows
            .filter { window in
                window.frame.width >= 80 && window.frame.height >= 80 && window.owningApplication != nil
            }
            .map { window in
                let appName = window.owningApplication?.applicationName ?? "App"
                let windowTitle = window.title ?? ""
                let title = windowTitle.isEmpty ? appName : windowTitle
                return CaptureTarget(
                    id: "window-\(window.windowID)",
                    kind: .window,
                    numericID: window.windowID,
                    title: title,
                    detail: appName,
                    size: Size2D(width: Double(window.frame.width), height: Double(window.frame.height)),
                    globalOrigin: Point2D(x: window.frame.minX, y: window.frame.minY),
                    globalSize: Size2D(width: window.frame.width, height: window.frame.height)
                )
            }

        return displays + windows
    }

    func start(to url: URL, target: CaptureTarget?) async throws {
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw ScreenRecorderError.screenPermissionRequired
        }

        try await stopIfNeeded()
        outputURL = url
        recordingStartedAt = Date()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let filter: SCContentFilter
        let captureWidth: Int
        let captureHeight: Int

        switch target?.kind {
        case .window:
            guard let selectedWindow = content.windows.first(where: { $0.windowID == target?.numericID }) else {
                throw ScreenRecorderError.targetUnavailable
            }
            filter = SCContentFilter(desktopIndependentWindow: selectedWindow)
            captureWidth = max(2, Int(selectedWindow.frame.width))
            captureHeight = max(2, Int(selectedWindow.frame.height))
        case .display, .none:
            let selectedDisplay: SCDisplay?
            if let target, target.kind == .display {
                selectedDisplay = content.displays.first { $0.displayID == target.numericID }
            } else {
                selectedDisplay = content.displays.first
            }
            guard let display = selectedDisplay else { throw ScreenRecorderError.displayUnavailable }
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            captureWidth = display.width
            captureHeight = display.height
        }

        displaySize = CGSize(width: captureWidth, height: captureHeight)

        let configuration = SCStreamConfiguration()
        configuration.width = captureWidth
        configuration.height = captureHeight
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 8
        configuration.showsCursor = false
        configuration.capturesAudio = true
        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        try prepareWriter(outputURL: url, width: captureWidth, height: captureHeight)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws -> ScreenRecordingResult? {
        guard let stream else { return nil }
        try await stream.stopCapture()
        self.stream = nil

        if let writer {
            if didStartWriting {
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                await withCheckedContinuation { continuation in
                    writer.finishWriting {
                        continuation.resume()
                    }
                }
            } else {
                writer.cancelWriting()
            }
        }

        if let writerFailureMessage {
            cleanupWriterState()
            throw ScreenRecorderError.writerFailed(writerFailureMessage)
        }

        if capturedVideoFrameCount == 0 {
            cleanupWriterState()
            throw ScreenRecorderError.noVideoFramesCaptured
        }

        let result = ScreenRecordingResult(
            url: outputURL ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording.mov"),
            displaySize: displaySize,
            duration: recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        )

        cleanupWriterState()
        return result
    }

    private func stopIfNeeded() async throws {
        if isRecording {
            _ = try await stop()
        }
    }

    private func prepareWriter(outputURL: URL, width: Int, height: Int) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(12_000_000, width * height * 5),
                    AVVideoMaxKeyFrameIntervalKey: 60
                ]
            ]
        )
        videoInput.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000
            ]
        )
        audioInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw ScreenRecorderError.writerUnavailable
        }
        writer.add(videoInput)
        writer.add(audioInput)
        self.writer = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor
        self.audioInput = audioInput
        didStartWriting = false
        firstVideoTime = nil
        firstAudioTime = nil
        capturedVideoFrameCount = 0
        writerFailureMessage = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard CMSampleBufferDataIsReady(sampleBuffer), let writer else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch outputType {
        case .screen:
            guard isCompleteScreenFrame(sampleBuffer),
                  let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                  let videoInput,
                  let pixelBufferAdaptor else {
                return
            }
            if !didStartWriting {
                guard writer.startWriting() else {
                    writerFailureMessage = writer.error?.localizedDescription ?? "Could not start writing."
                    return
                }
                writer.startSession(atSourceTime: .zero)
                didStartWriting = true
            }
            guard videoInput.isReadyForMoreMediaData else { return }
            if firstVideoTime == nil { firstVideoTime = presentationTime }
            let normalizedTime = CMTimeSubtract(presentationTime, firstVideoTime ?? presentationTime)
            if pixelBufferAdaptor.append(imageBuffer, withPresentationTime: normalizedTime) {
                capturedVideoFrameCount += 1
            } else if let error = writer.error {
                writerFailureMessage = error.localizedDescription
            }
        case .audio, .microphone:
            guard didStartWriting, audioInput?.isReadyForMoreMediaData == true else { return }
            if firstAudioTime == nil { firstAudioTime = presentationTime }
            let timingAnchor = firstVideoTime ?? firstAudioTime ?? presentationTime
            if let adjusted = sampleBuffer.copyWithTimingOffset(timingAnchor) {
                audioInput?.append(adjusted)
            }
        @unknown default:
            break
        }
    }

    private func isCompleteScreenFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int else {
            return true
        }
        return status == SCFrameStatus.complete.rawValue
    }

    private func cleanupWriterState() {
        writer = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        audioInput = nil
        didStartWriting = false
        firstVideoTime = nil
        firstAudioTime = nil
        capturedVideoFrameCount = 0
        writerFailureMessage = nil
        outputURL = nil
        recordingStartedAt = nil
    }
}

private extension CMSampleBuffer {
    func copyWithTimingOffset(_ offset: CMTime) -> CMSampleBuffer? {
        var count = 0
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        guard count > 0 else { return self }

        var timing = Array(repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(self, entryCount: count, arrayToFill: &timing, entriesNeededOut: &count)
        for index in timing.indices {
            if timing[index].decodeTimeStamp.isValid {
                timing[index].decodeTimeStamp = CMTimeSubtract(timing[index].decodeTimeStamp, offset)
            }
            if timing[index].presentationTimeStamp.isValid {
                timing[index].presentationTimeStamp = CMTimeSubtract(timing[index].presentationTimeStamp, offset)
            }
        }

        var adjusted: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: count,
            sampleTimingArray: timing,
            sampleBufferOut: &adjusted
        )
        return adjusted
    }
}
