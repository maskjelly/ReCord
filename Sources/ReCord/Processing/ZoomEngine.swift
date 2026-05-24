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
    var zoomRampMultiplier: Double
    var zoomSmoothingWindow: TimeInterval

    static func `default`(
        outputSize: CGSize,
        followMouse: Bool = true,
        zoomRampMultiplier: Double = 1.5,
        zoomSmoothingWindow: TimeInterval = 1.0,
        cameraSmoothingWindow: TimeInterval = 2.0
    ) -> ZoomEngineConfiguration {
        ZoomEngineConfiguration(
            outputSize: outputSize,
            baseZoom: 1.0,
            followMouse: followMouse,
            cursorIdleHideDelay: 2.5,
            cameraSmoothingWindow: cameraSmoothingWindow,
            maxZoom: 4.0,
            zoomRampMultiplier: zoomRampMultiplier,
            zoomSmoothingWindow: zoomSmoothingWindow
        )
    }
}

private struct DragPeriod {
    let start: TimeInterval
    let end: TimeInterval
}

final class ZoomEngine {
    private let displaySize: CGSize
    private let cursorEvents: [CursorEvent]
    private let keyframes: [ZoomKeyframe]
    private let config: ZoomEngineConfiguration
    private let dragPeriods: [DragPeriod]

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
        self.dragPeriods = Self.detectDragPeriods(from: cursorEvents)
    }

    func state(at time: TimeInterval) -> ZoomFrameState {
        let cursor = cursorPosition(at: time)
        let rawZoom = zoomTarget(at: time)
        let smoothedZoom = smoothedZoom(at: time, target: rawZoom)
        let targetCenter = targetCenter(at: time, cursor: cursor)
        let smoothedCenter = smoothedCameraCenter(at: time, target: targetCenter)
        let viewport = viewportRect(center: smoothedCenter, zoom: smoothedZoom)
        let visible = cursorVisible(at: time)
        let pulse = clickPulse(at: time)

        return ZoomFrameState(
            viewport: viewport,
            zoom: smoothedZoom,
            cameraCenter: smoothedCenter,
            cursorPosition: cursor,
            cursorVisible: visible,
            clickPulse: pulse
        )
    }

    // MARK: - Drag Detection

    private static func detectDragPeriods(from events: [CursorEvent]) -> [DragPeriod] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        var periods: [DragPeriod] = []
        var downEvent: CursorEvent?
        var moveCount = 0

        for event in sorted {
            switch event.kind {
            case .leftDown, .rightDown:
                downEvent = event
                moveCount = 0
            case .move:
                if downEvent != nil { moveCount += 1 }
            case .leftUp, .rightUp:
                if let down = downEvent, moveCount >= 3 {
                    let duration = event.timestamp - down.timestamp
                    if duration >= 0.12 {
                        periods.append(DragPeriod(start: down.timestamp, end: event.timestamp))
                    }
                }
                downEvent = nil
                moveCount = 0
            default:
                break
            }
        }
        return periods
    }

    private func isDragging(at time: TimeInterval) -> Bool {
        dragPeriods.contains { time >= $0.start && time <= $0.end }
    }

    // MARK: - Cursor Position

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

    // MARK: - Camera / Zoom Targets

    private func targetCenter(at time: TimeInterval, cursor: CGPoint) -> CGPoint {
        guard config.followMouse else {
            return nearestKeyframe(to: time)?.position.cgPoint ?? cursor
        }

        guard activeKeyframe(at: time) != nil else {
            return CGPoint(x: displaySize.width / 2, y: displaySize.height / 2)
        }

        return clampedPoint(cursor)
    }

    private func zoomTarget(at time: TimeInterval) -> Double {
        if isDragging(at: time) { return config.baseZoom }

        var result = config.baseZoom
        let multiplier = max(0.1, config.zoomRampMultiplier)

        for keyframe in keyframes {
            let ramp = max(keyframe.duration * multiplier, 0.1)
            let start = keyframe.timestamp
            let rampInEnd = start + ramp
            let holdEnd = rampInEnd + keyframe.hold
            let rampOutEnd = holdEnd + ramp

            if time < start || time > rampOutEnd { continue }

            let currentZoom: Double
            if time <= rampInEnd {
                let p = easeInOutCubic((time - start) / ramp)
                currentZoom = lerp(config.baseZoom, keyframe.zoom, p)
            } else if time <= holdEnd {
                currentZoom = keyframe.zoom
            } else {
                let p = easeInOutCubic((time - holdEnd) / ramp)
                currentZoom = lerp(keyframe.zoom, config.baseZoom, p)
            }
            result = max(result, currentZoom)
        }

        return clamped(result, config.baseZoom, config.maxZoom)
    }

    // MARK: - Smoothing

    private func smoothedZoom(at time: TimeInterval, target: Double) -> Double {
        let window = max(config.zoomSmoothingWindow, 0.001)
        guard window > 0.001 else { return target }
        let samples = 50
        var weighted = 0.0
        var totalWeight = 0.0

        for index in 0..<samples {
            let offset = -Double(index) / Double(samples - 1) * window
            let sampleTime = max(0, time + offset)
            let zoom = zoomTarget(at: sampleTime)
            let t = Double(index) / Double(samples - 1)
            let weight = exp(-t * 5.0)
            weighted += zoom * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return target }
        return clamped(weighted / totalWeight, config.baseZoom, config.maxZoom)
    }

    private func smoothedCameraCenter(at time: TimeInterval, target: CGPoint) -> CGPoint {
        guard activeKeyframe(at: time) != nil, config.followMouse else {
            return clampedPoint(target)
        }

        let window = max(config.cameraSmoothingWindow, 0.01)
        let samples = 60
        var weightedX = 0.0
        var weightedY = 0.0
        var totalWeight = 0.0

        for index in 0..<samples {
            let offset = -Double(index) / Double(samples - 1) * window
            let sampleTime = max(0, time + offset)
            let point = cursorPosition(at: sampleTime)
            let t = Double(index) / Double(samples - 1)
            let weight = exp(-t * 5.0)
            weightedX += point.x * weight
            weightedY += point.y * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return clampedPoint(target) }
        return clampedPoint(CGPoint(x: weightedX / totalWeight, y: weightedY / totalWeight))
    }

    // MARK: - Viewport

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

    // MARK: - Helpers

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

// MARK: - Automatic Keyframes

func generateAutomaticKeyframes(from events: [CursorEvent]) -> [ZoomKeyframe] {
    let dragPeriods = detectDragPeriodsForGeneration(from: events)
    var output: [ZoomKeyframe] = []
    var lastClick: TimeInterval = -10

    for event in events where event.kind == .leftDown || event.kind == .rightDown {
        guard event.timestamp - lastClick > 1.8 else { continue }
        if dragPeriods.contains(where: { event.timestamp >= $0.start && event.timestamp <= $0.end }) {
            continue
        }
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

private func detectDragPeriodsForGeneration(from events: [CursorEvent]) -> [DragPeriod] {
    let sorted = events.sorted { $0.timestamp < $1.timestamp }
    var periods: [DragPeriod] = []
    var downEvent: CursorEvent?
    var moveCount = 0

    for event in sorted {
        switch event.kind {
        case .leftDown, .rightDown:
            downEvent = event
            moveCount = 0
        case .move:
            if downEvent != nil { moveCount += 1 }
        case .leftUp, .rightUp:
            if let down = downEvent, moveCount >= 3 {
                let duration = event.timestamp - down.timestamp
                if duration >= 0.12 {
                    periods.append(DragPeriod(start: down.timestamp, end: event.timestamp))
                }
            }
            downEvent = nil
            moveCount = 0
        default:
            break
        }
    }
    return periods
}

// MARK: - Easing

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
