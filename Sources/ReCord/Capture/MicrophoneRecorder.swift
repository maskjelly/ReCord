import AVFoundation
import Foundation

final class MicrophoneRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var outputURL: URL?

    func start(to url: URL) throws {
        stop()
        outputURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
    }

    func stop() {
        recorder?.stop()
        recorder = nil
    }
}
