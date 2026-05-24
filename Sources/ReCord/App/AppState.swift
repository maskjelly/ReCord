import AppKit
import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var sessions: [RecordingSession] = []
    @Published var selectedSessionID: RecordingSession.ID?
    @Published var isRecording = false
    @Published var isExporting = false
    @Published var exportProgress = 0.0
    @Published var exportLogLines: [String] = []
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var exportPreset: ExportPreset = .fullHD
    @Published var captureTargets: [CaptureTarget] = []
    @Published var selectedCaptureTargetID: CaptureTarget.ID?
    @Published var recordingSaveDirectory: URL? = ReCordStorage.configuredRecordingDirectory
    @Published var screenRecordingStatus: PermissionStatus = PermissionsManager.screenRecordingStatus
    @Published var accessibilityStatus: PermissionStatus = PermissionsManager.accessibilityStatus
    @Published var microphoneStatus: PermissionStatus = PermissionsManager.microphoneStatus
    @Published var zoomRampMultiplier: Double = ReCordStorage.zoomRampMultiplier
    @Published var zoomSmoothingWindow: Double = ReCordStorage.zoomSmoothingWindow
    @Published var cameraSmoothingWindow: Double = ReCordStorage.cameraSmoothingWindow

    let licenseManager = LicenseManager()

    private let screenRecorder = ScreenRecorder()
    private let cursorTracker = CursorTracker()
    private let microphoneRecorder = MicrophoneRecorder()
    private let videoExporter = VideoExporter()
    private var recordingStartDate: Date?
    private var activeFolder: URL?
    private var activeRawVideoURL: URL?
    private var activeMicURL: URL?
    private var activeCaptureTarget: CaptureTarget?
    private var pendingManualKeyframes: [ZoomKeyframe] = []

    var selectedSession: RecordingSession? {
        guard let selectedSessionID else { return sessions.first }
        return sessions.first { $0.id == selectedSessionID }
    }

    init() {
        sessions = ReCordStorage.loadSessions()
            .filter { Self.isUsableRecordingFile($0.rawVideoURL) }
            .sorted { $0.createdAt > $1.createdAt }
        selectedSessionID = sessions.first?.id
        try? ReCordStorage.saveSessions(sessions)
    }

    var selectedCaptureTarget: CaptureTarget? {
        guard let selectedCaptureTargetID else { return captureTargets.first }
        return captureTargets.first { $0.id == selectedCaptureTargetID }
    }

    var requiredPermissionsGranted: Bool {
        screenRecordingStatus == .granted && accessibilityStatus == .granted
    }

    func requestPermissions() async {
        _ = PermissionsManager.requestScreenRecording()
        PermissionsManager.requestAccessibilityPrompt()
        _ = await PermissionsManager.requestMicrophone()
        refreshPermissionStatuses()
        statusMessage = "Permission prompts requested"
    }

    func refreshPermissionStatuses() {
        screenRecordingStatus = PermissionsManager.screenRecordingStatus
        accessibilityStatus = PermissionsManager.accessibilityStatus
        microphoneStatus = PermissionsManager.microphoneStatus
    }

    func setZoomRampMultiplier(_ value: Double) {
        let clamped = max(0.2, min(4.0, value))
        ReCordStorage.zoomRampMultiplier = clamped
        zoomRampMultiplier = clamped
    }

    func setZoomSmoothingWindow(_ value: Double) {
        let clamped = max(0.0, min(2.0, value))
        ReCordStorage.zoomSmoothingWindow = clamped
        zoomSmoothingWindow = clamped
    }

    func setCameraSmoothingWindow(_ value: Double) {
        let clamped = max(0.05, min(4.0, value))
        ReCordStorage.cameraSmoothingWindow = clamped
        cameraSmoothingWindow = clamped
    }

    func loadCaptureTargets() async {
        refreshPermissionStatuses()
        do {
            captureTargets = try await ScreenRecorder.availableTargets()
            if selectedCaptureTargetID == nil || !captureTargets.contains(where: { $0.id == selectedCaptureTargetID }) {
                selectedCaptureTargetID = captureTargets.first?.id
            }
            statusMessage = captureTargets.isEmpty ? "No screens or windows found" : "Choose what to record"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Capture targets unavailable"
        }
    }

    func chooseRecordingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose where ReCord saves recordings"
        panel.prompt = "Use This Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let recordingSaveDirectory {
            panel.directoryURL = recordingSaveDirectory
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        ReCordStorage.setRecordingsDirectory(url)
        recordingSaveDirectory = url
        statusMessage = "Save location set"
    }

    func startRecording() async {
        if captureTargets.isEmpty {
            await loadCaptureTargets()
        }
        await startRecording(target: selectedCaptureTarget, saveDirectory: recordingSaveDirectory)
    }

    func startRecording(target: CaptureTarget?, saveDirectory: URL?) async {
        guard !isRecording else { return }
        refreshPermissionStatuses()
        guard let saveDirectory else {
            statusMessage = "Choose a save location"
            errorMessage = "Choose a folder before recording so ReCord knows where to save the raw recording and project files."
            return
        }
        guard let target else {
            statusMessage = "Choose a screen or window"
            errorMessage = "Choose the screen or window you want to record."
            return
        }
        guard screenRecordingStatus == .granted else {
            statusMessage = "Screen Recording permission required"
            errorMessage = "Open System Settings > Privacy & Security > Screen Recording and enable ReCord. You may need to quit and reopen ReCord after granting it."
            PermissionsManager.openPrivacyPane(.screenRecording)
            return
        }
        guard accessibilityStatus == .granted else {
            statusMessage = "Accessibility permission required"
            errorMessage = "Open System Settings > Privacy & Security > Accessibility and enable ReCord so it can follow your mouse for zoom effects."
            PermissionsManager.openPrivacyPane(.accessibility)
            return
        }
        do {
            ReCordStorage.setRecordingsDirectory(saveDirectory)
            recordingSaveDirectory = saveDirectory
            try ReCordStorage.ensureDirectories()
            let id = UUID()
            let folder = ReCordStorage.recordingsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let rawURL = folder.appendingPathComponent("raw.mov")
            let micURL = folder.appendingPathComponent("microphone.m4a")
            let start = Date()
            pendingManualKeyframes = []

            if microphoneStatus == .granted {
                try microphoneRecorder.start(to: micURL)
                activeMicURL = micURL
            } else {
                activeMicURL = nil
            }

            try cursorTracker.start(referenceDate: start)
            try await screenRecorder.start(to: rawURL, target: target)

            recordingStartDate = start
            activeFolder = folder
            activeRawVideoURL = rawURL
            activeCaptureTarget = target
            isRecording = true
            statusMessage = "Recording \(target.title)..."
        } catch {
            microphoneRecorder.stop()
            _ = cursorTracker.stop()
            activeCaptureTarget = nil
            errorMessage = error.localizedDescription
            statusMessage = "Recording failed"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        do {
            microphoneRecorder.stop()
            let rawCursorEvents = cursorTracker.stop()
            guard let result = try await screenRecorder.stop() else {
                isRecording = false
                recordingStartDate = nil
                activeFolder = nil
                activeRawVideoURL = nil
                activeMicURL = nil
                activeCaptureTarget = nil
                pendingManualKeyframes = []
                statusMessage = "Recording stopped"
                return
            }
            let cursorEvents = normalizeCursorEvents(rawCursorEvents, target: activeCaptureTarget, displaySize: result.displaySize)
            let manualKeyframes = pendingManualKeyframes.compactMap { normalize($0, target: activeCaptureTarget, displaySize: result.displaySize) }

            let keyframes = (generateAutomaticKeyframes(from: cursorEvents) + manualKeyframes)
                .sorted { $0.timestamp < $1.timestamp }
            let title = "Recording \(sessions.count + 1)"
            let session = RecordingSession(
                title: title,
                duration: result.duration,
                displaySize: Size2D(result.displaySize),
                rawVideoURL: result.url,
                microphoneAudioURL: activeMicURL,
                cursorEvents: cursorEvents,
                zoomKeyframes: keyframes
            )

            sessions.insert(session, at: 0)
            selectedSessionID = session.id
            try ReCordStorage.saveSessions(sessions)

            isRecording = false
            recordingStartDate = nil
            activeFolder = nil
            activeRawVideoURL = nil
            activeMicURL = nil
            activeCaptureTarget = nil
            pendingManualKeyframes = []
            statusMessage = "Recording saved"
        } catch {
            isRecording = false
            activeCaptureTarget = nil
            errorMessage = error.localizedDescription
            statusMessage = "Stop failed"
        }
    }

    func exportSelectedSession() async {
        guard var session = selectedSession, !isExporting else { return }
        guard Self.isUsableRecordingFile(session.rawVideoURL) else {
            errorMessage = "This recording file is empty or missing. Make a new recording with the latest build."
            statusMessage = "Export blocked"
            return
        }
        if exportPreset.requiresPro && licenseManager.tier != .pro {
            errorMessage = "4K export requires ReCord Pro. Choose 1080p, Vertical, or Square for the free tier."
            statusMessage = "Export blocked"
            return
        }
        isExporting = true
        exportProgress = 0
        exportLogLines = []
        statusMessage = "Exporting \(exportPreset.title)..."
        appendExportLog("Export started")

        do {
            let outputURL = try await videoExporter.export(
                session: session,
                options: exportPreset.options(for: licenseManager.tier),
                progress: { [weak self] value in
                    Task { @MainActor in self?.exportProgress = value }
                },
                log: { [weak self] message in
                    Task { @MainActor in self?.appendExportLog(message) }
                }
            )
            session.exportedVideoURL = outputURL
            replace(session)
            try ReCordStorage.saveSessions(sessions)
            statusMessage = "Export complete"
        } catch {
            appendExportLog("Export failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            statusMessage = "Export failed"
        }

        isExporting = false
    }

    private func appendExportLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        exportLogLines.append("[\(formatter.string(from: Date()))] \(message)")
        if exportLogLines.count > 80 {
            exportLogLines.removeFirst(exportLogLines.count - 80)
        }
    }

    func addManualZoom(at timestamp: TimeInterval, position: Point2D? = nil) {
        guard var session = selectedSession else { return }
        let fallback = Point2D(x: session.displaySize.width / 2, y: session.displaySize.height / 2)
        let keyframe = ZoomKeyframe(
            timestamp: timestamp,
            position: position ?? nearestCursorPosition(in: session, at: timestamp) ?? fallback,
            zoom: 2.1,
            duration: 0.45,
            hold: 1.35,
            source: .manual
        )
        session.zoomKeyframes.append(keyframe)
        session.zoomKeyframes.sort { $0.timestamp < $1.timestamp }
        replace(session)
        try? ReCordStorage.saveSessions(sessions)
    }

    func addManualZoomCommand() {
        if isRecording, let recordingStartDate {
            let timestamp = Date().timeIntervalSince(recordingStartDate)
            let events = cursorTracker.snapshot()
            let position = events.last?.location ?? activeCaptureTarget.map {
                Point2D(x: $0.globalFrame.midX, y: $0.globalFrame.midY)
            } ?? Point2D(x: 0, y: 0)
            pendingManualKeyframes.append(
                ZoomKeyframe(
                    timestamp: max(0, timestamp - 0.1),
                    position: position,
                    zoom: 2.2,
                    duration: 0.42,
                    hold: 1.4,
                    source: .manual
                )
            )
            statusMessage = "Manual zoom marker added"
        } else if let session = selectedSession {
            addManualZoom(at: session.duration * 0.5)
        }
    }

    func deleteKeyframe(_ keyframe: ZoomKeyframe) {
        guard var session = selectedSession else { return }
        session.zoomKeyframes.removeAll { $0.id == keyframe.id }
        replace(session)
        try? ReCordStorage.saveSessions(sessions)
    }

    func moveKeyframe(_ keyframe: ZoomKeyframe, to timestamp: TimeInterval) {
        guard var session = selectedSession,
              let index = session.zoomKeyframes.firstIndex(where: { $0.id == keyframe.id }) else { return }
        session.zoomKeyframes[index].timestamp = max(0, min(session.duration, timestamp))
        session.zoomKeyframes.sort { $0.timestamp < $1.timestamp }
        replace(session)
        try? ReCordStorage.saveSessions(sessions)
    }

    func rename(_ session: RecordingSession, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var updated = sessions.first(where: { $0.id == session.id }) else { return }
        updated.title = trimmed
        replace(updated)
        try? ReCordStorage.saveSessions(sessions)
    }

    func delete(_ session: RecordingSession) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.first?.id
        }
        try? ReCordStorage.saveSessions(sessions)

        let folder = session.rawVideoURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        statusMessage = "Recording deleted"
    }

    func reveal(_ session: RecordingSession) {
        let url = session.exportedVideoURL ?? session.rawVideoURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func nearestCursorPosition(in session: RecordingSession, at timestamp: TimeInterval) -> Point2D? {
        session.cursorEvents.min { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }?.location
    }

    private func replace(_ session: RecordingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        selectedSessionID = session.id
    }

    private static func isUsableRecordingFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        return size.int64Value > 0
    }

    private func normalizeCursorEvents(_ events: [CursorEvent], target: CaptureTarget?, displaySize: CGSize) -> [CursorEvent] {
        guard let target else { return events }
        return events.compactMap { event in
            normalize(event, target: target, displaySize: displaySize)
        }
    }

    private func normalize(_ event: CursorEvent, target: CaptureTarget, displaySize: CGSize) -> CursorEvent? {
        let frame = target.globalFrame
        let point = event.location.cgPoint
        let isInside = frame.insetBy(dx: -2, dy: -2).contains(point)

        if !isInside {
            return nil
        }

        let localX = (point.x - frame.minX) / max(frame.width, 1) * displaySize.width
        let localY = (point.y - frame.minY) / max(frame.height, 1) * displaySize.height
        let normalized = Point2D(
            x: min(max(localX, 0), displaySize.width),
            y: min(max(localY, 0), displaySize.height)
        )

        return CursorEvent(id: event.id, timestamp: event.timestamp, location: normalized, kind: event.kind)
    }

    private func normalize(_ keyframe: ZoomKeyframe, target: CaptureTarget?, displaySize: CGSize) -> ZoomKeyframe? {
        guard let target else { return keyframe }
        let event = CursorEvent(timestamp: keyframe.timestamp, location: keyframe.position, kind: .leftDown)
        guard let normalizedEvent = normalize(event, target: target, displaySize: displaySize) else { return nil }
        var updated = keyframe
        updated.position = normalizedEvent.location
        return updated
    }
}
