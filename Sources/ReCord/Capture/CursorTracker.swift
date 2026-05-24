import AppKit
import Foundation

enum CursorTrackerError: LocalizedError {
    case accessibilityPermissionRequired
    case cannotCreateEventTap

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "ReCord needs Accessibility permission to follow mouse movement and clicks."
        case .cannotCreateEventTap:
            return "Could not create a global mouse event tap."
        }
    }
}

private let cursorEventCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tracker = Unmanaged<CursorTracker>.fromOpaque(refcon).takeUnretainedValue()
    tracker.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

final class CursorTracker {
    private var events: [CursorEvent] = []
    private var startedAt = Date()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private let lock = NSLock()

    func start(referenceDate: Date = Date()) throws {
        guard AXIsProcessTrusted() else {
            PermissionsManager.requestAccessibilityPrompt()
            throw CursorTrackerError.accessibilityPermissionRequired
        }

        _ = stop()
        startedAt = referenceDate
        events = []

        let thread = Thread { [weak self] in
            self?.installEventTap()
        }
        thread.name = "ReCord.CursorTracker"
        self.thread = thread
        thread.start()
    }

    func stop() -> [CursorEvent] {
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        eventTap = nil
        runLoopSource = nil
        thread = nil

        lock.lock()
        let snapshot = events
        lock.unlock()
        return snapshot
    }

    func snapshot() -> [CursorEvent] {
        lock.lock()
        let snapshot = events
        lock.unlock()
        return snapshot
    }

    private func installEventTap() {
        let eventTypes: [CGEventType] = [
            .mouseMoved,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .scrollWheel
        ]
        let rawMask = eventTypes.reduce(UInt64(0)) { partial, type in
            partial | (UInt64(1) << UInt64(type.rawValue))
        }
        let mask = CGEventMask(rawMask)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: cursorEventCallback,
            userInfo: refcon
        ) else {
            return
        }

        eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        let kind: CursorEventKind
        switch type {
        case .mouseMoved: kind = .move
        case .leftMouseDown: kind = .leftDown
        case .leftMouseUp: kind = .leftUp
        case .rightMouseDown: kind = .rightDown
        case .rightMouseUp: kind = .rightUp
        case .scrollWheel: kind = .scroll
        default: return
        }

        let location = event.location
        let timestamp = Date().timeIntervalSince(startedAt)
        let cursorEvent = CursorEvent(timestamp: timestamp, location: Point2D(location), kind: kind)

        lock.lock()
        events.append(cursorEvent)
        lock.unlock()
    }
}
