import CoreGraphics
import Foundation

enum CaptureTargetKind: String, Codable, Sendable {
    case display
    case window
}

struct CaptureTarget: Identifiable, Hashable, Sendable {
    var id: String
    var kind: CaptureTargetKind
    var numericID: UInt32
    var title: String
    var detail: String
    var size: Size2D
    var globalOrigin: Point2D
    var globalSize: Size2D

    var label: String {
        "\(title) - \(Int(size.width))x\(Int(size.height))"
    }

    var globalFrame: CGRect {
        CGRect(
            x: globalOrigin.x,
            y: globalOrigin.y,
            width: globalSize.width,
            height: globalSize.height
        )
    }
}
