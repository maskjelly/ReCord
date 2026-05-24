import Foundation

enum CursorEventKind: String, Codable, Sendable {
    case move
    case leftDown
    case leftUp
    case rightDown
    case rightUp
    case scroll
}

struct CursorEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var timestamp: TimeInterval
    var location: Point2D
    var kind: CursorEventKind

    init(
        id: UUID = UUID(),
        timestamp: TimeInterval,
        location: Point2D,
        kind: CursorEventKind
    ) {
        self.id = id
        self.timestamp = timestamp
        self.location = location
        self.kind = kind
    }
}
