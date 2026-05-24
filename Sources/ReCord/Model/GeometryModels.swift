import CoreGraphics
import Foundation

struct Point2D: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

struct Size2D: Codable, Hashable, Sendable {
    var width: Double
    var height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}
