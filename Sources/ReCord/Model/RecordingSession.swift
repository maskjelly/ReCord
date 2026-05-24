import Foundation

struct RecordingSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var displaySize: Size2D
    var rawVideoURL: URL
    var microphoneAudioURL: URL?
    var exportedVideoURL: URL?
    var cursorEvents: [CursorEvent]
    var zoomKeyframes: [ZoomKeyframe]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        displaySize: Size2D,
        rawVideoURL: URL,
        microphoneAudioURL: URL? = nil,
        exportedVideoURL: URL? = nil,
        cursorEvents: [CursorEvent],
        zoomKeyframes: [ZoomKeyframe]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.displaySize = displaySize
        self.rawVideoURL = rawVideoURL
        self.microphoneAudioURL = microphoneAudioURL
        self.exportedVideoURL = exportedVideoURL
        self.cursorEvents = cursorEvents
        self.zoomKeyframes = zoomKeyframes
    }
}
