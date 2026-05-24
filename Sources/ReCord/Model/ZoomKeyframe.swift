import Foundation

enum ZoomKeyframeSource: String, Codable, Sendable {
    case automatic
    case manual
}

struct ZoomKeyframe: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var timestamp: TimeInterval
    var position: Point2D
    var zoom: Double
    var duration: Double
    var hold: Double
    var source: ZoomKeyframeSource

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        position: Point2D,
        zoom: Double = 1.8,
        duration: Double = 0.45,
        hold: Double = 1.2,
        source: ZoomKeyframeSource
    ) {
        self.id = id
        self.timestamp = timestamp
        self.position = position
        self.zoom = zoom
        self.duration = duration
        self.hold = hold
        self.source = source
    }
}
