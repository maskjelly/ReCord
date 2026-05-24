import CoreGraphics
import Foundation

struct ZoomFrameState: Sendable {
    var viewport: CGRect
    var zoom: Double
    var cameraCenter: CGPoint
    var cursorPosition: CGPoint
    var cursorVisible: Bool
    var clickPulse: Double
}

struct ZoomEngineConfiguration: Sendable {
    var outputSize: CGSize
    var baseZoom: Double
    var followMouse: Bool
    var cursorIdleHideDelay: TimeInterval
    var cameraSmoothingWindow: TimeInterval
    var maxZoom: Double

    static func `default`(outputSize: CGSize, followMouse: Bool = true) -> ZoomEngineConfiguration {
        ZoomEngineConfiguration(
            outputSize: outputSize,
            baseZoom: 1.0,
            followMouse: followMouse,
            cursorIdleHideDelay: 2.5,
            cameraSmoothingWindow: 0.22,
            maxZoom: 4.0
        )
    }
}

final class ZoomEngine {
    private let displaySize: CGSize
    private let cursorEvents: [CursorEvent]
    private let keyframes: [ZoomKeyframe]
    private let config: ZoomEngineConfiguration

    init(
        displaySize: CGSize,
        cursorEvents: [CursorEvent],
        keyframes: [ZoomKeyframe],
        configuration: ZoomEngineConfiguration
    ) {
        self.displaySize = displaySize
        self.cursorEvents = cursorEvents.sorted { $0.timestamp < $1.timestamp }
        self.keyframes = keyframes.sorted { $0.timestamp < $1.timestamp }
        self.config = configuration
    }

    func state(at time: TimeInterval) -> ZoomFrameState {
        let cursor = cursorPosition(at: time)
        let zoom = zoomLevel(at: time)
        let targetCenter = targetCenter(at: time, cursor: cursor)
        let smoothedCenter = smoothedCameraCenter(at: time, target: targetCenter)
        let viewport = viewportRect(center: smoothedCenter, zoom: zoom)
        let visible = cursorVisible(at: time)
        let pulse = clickPulse(at: time)

        return ZoomFrameState(
            viewport: viewport,
            zoom: zoom,
            cameraCenter: smoothedCenter,
            cursorPosition: cursor,
            cursorVisible: visible,
            clickPulse: pulse
        )
    }

    private func cursorPosition(at time: TimeInterval) -> CGPoint {
        guard !cursorEvents.isEmpty else {
            return CGPoint(x: displaySize.width / 2, y: displaySize.height / 2)
        }

        var previous = cursorEvents[0]
        var next: CursorEvent?
        for event in cursorEvents {
            if event.timestamp <= time {
                previous = event
            } else {
                next = event
                break
            }
        }

        guard let next, next.timestamp > previous.timestamp, next.timestamp - previous.timestamp < 0.35 else {
            return clampedPoint(previous.location.cgPoint)
        }

        let progress = clamped((time - previous.timestamp) / (next.timestamp - previous.timestamp), 0, 1)
        return clampedPoint(
            CGPoint(
                x: lerp(previous.location.x, next.location.x, progress),
                y: lerp(previous.location.y, next.location.y, progress)
            )
        )
    }

    private func targetCenter(at time: TimeInterval, cursor: CGPoint) -> CGPoint {
        guard config.followMouse else {
            return nearestKeyframe(to: time)?.position.cgPoint ?? cursor
        }

        guard activeKeyframe(at: time) != nil else {
            return CGPoint(x: displaySize.width / 2, y: displaySize.height / 2)
        }

        return clampedPoint(cursor)
    }

    private func zoomLevel(at time: TimeInterval) -> Double {
        var result = config.baseZoom

        for keyframe in keyframes {
            let start = keyframe.timestamp
            let rampInEnd = start + keyframe.duration
            let holdEnd = rampInEnd + keyframe.hold
            let rampOutEnd = holdEnd + keyframe.duration

            if time < start || time > rampOutEnd { continue }

            if time <= rampInEnd {
                let p = easeInOutCubic((time - start) / max(keyframe.duration, 0.001))
                result = lerp(config.baseZoom, keyframe.zoom, p)
            } else if time <= holdEnd {
                result = keyframe.zoom
            } else {
                let p = easeInOutCubic((time - holdEnd) / max(keyframe.duration, 0.001))
                result = lerp(keyframe.zoom, config.baseZoom, p)
            }
        }

        return clamped(result, config.baseZoom, config.maxZoom)
    }

    private func smoothedCameraCenter(at time: TimeInterval, target: CGPoint) -> CGPoint {
        guard activeKeyframe(at: time) != nil, config.followMouse else {
            return clampedPoint(target)
        }

        let window = max(config.cameraSmoothingWindow, 0.01)
        let samples = 9
        var weightedX = 0.0
        var weightedY = 0.0
        var totalWeight = 0.0

        for index in 0..<samples {
            let offset = (Double(index) / Double(samples - 1) - 0.5) * window
            let sampleTime = max(0, time + offset)
            let point = cursorPosition(at: sampleTime)
            let normalizedDistance = abs(offset) / (window / 2)
            let weight = max(0.05, 1 - normalizedDistance)
            weightedX += point.x * weight
            weightedY += point.y * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return clampedPoint(target) }
        return clampedPoint(CGPoint(x: weightedX / totalWeight, y: weightedY / totalWeight))
    }

    private func targetCenterWithoutSmoothing(at time: TimeInterval, cursor: CGPoint) -> CGPoint {
        guard config.followMouse else {
            return nearestKeyframe(to: time)?.position.cgPoint ?? cursor
        }
        return activeKeyframe(at: time) == nil ? CGPoint(x: displaySize.width / 2, y: displaySize.height / 2) : clampedPoint(cursor)
    }

    private func viewportRect(center: CGPoint, zoom: Double) -> CGRect {
        let viewportWidth = displaySize.width / zoom
        let viewportHeight = displaySize.height / zoom
        let maxX = max(0, displaySize.width - viewportWidth)
        let maxY = max(0, displaySize.height - viewportHeight)
        let origin = CGPoint(
            x: clamped(center.x - viewportWidth / 2, 0, maxX),
            y: clamped(center.y - viewportHeight / 2, 0, maxY)
        )
        return CGRect(x: origin.x, y: origin.y, width: viewportWidth, height: viewportHeight)
    }

    private func activeKeyframe(at time: TimeInterval) -> ZoomKeyframe? {
        keyframes.last { keyframe in
            let end = keyframe.timestamp + keyframe.duration + keyframe.hold + keyframe.duration
            return time >= keyframe.timestamp && time <= end
        }
    }

    private func clampedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: clamped(point.x, 0, displaySize.width),
            y: clamped(point.y, 0, displaySize.height)
        )
    }

    private func nearestKeyframe(to time: TimeInterval) -> ZoomKeyframe? {
        keyframes.min { abs($0.timestamp - time) < abs($1.timestamp - time) }
    }

    private func cursorVisible(at time: TimeInterval) -> Bool {
        guard let lastMove = cursorEvents.last(where: { $0.timestamp <= time && $0.kind == .move }) else {
            return true
        }
        return time - lastMove.timestamp <= config.cursorIdleHideDelay || activeKeyframe(at: time) != nil
    }

    private func clickPulse(at time: TimeInterval) -> Double {
        guard let click = cursorEvents.last(where: { $0.timestamp <= time && ($0.kind == .leftDown || $0.kind == .rightDown) }) else {
            return 0
        }
        let age = time - click.timestamp
        guard age >= 0 && age <= 0.35 else { return 0 }
        return 1 - easeOutCubic(age / 0.35)
    }
}

func generateAutomaticKeyframes(from events: [CursorEvent]) -> [ZoomKeyframe] {
    var output: [ZoomKeyframe] = []
    var lastClick: TimeInterval = -10

    for event in events where event.kind == .leftDown || event.kind == .rightDown {
        guard event.timestamp - lastClick > 1.8 else { continue }
        lastClick = event.timestamp
        output.append(
            ZoomKeyframe(
                timestamp: max(0, event.timestamp - 0.18),
                position: event.location,
                zoom: 1.75,
                duration: 0.72,
                hold: 1.25,
                source: .automatic
            )
        )
    }

    return output
}

private func easeInOutCubic(_ value: Double) -> Double {
    let t = clamped(value, 0, 1)
    if t < 0.5 { return 4 * t * t * t }
    return 1 - pow(-2 * t + 2, 3) / 2
}

private func easeOutCubic(_ value: Double) -> Double {
    let t = clamped(value, 0, 1)
    return 1 - pow(1 - t, 3)
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func clamped<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
