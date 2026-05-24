import AVFoundation
import CoreGraphics
import Foundation
import ApplicationServices
import AppKit

enum PermissionStatus: String {
    case granted
    case denied
    case unknown
}

enum PrivacyPane {
    case screenRecording
    case accessibility
    case microphone

    var url: URL {
        switch self {
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        }
    }
}

enum PermissionsManager {
    static var screenRecordingStatus: PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .unknown
    }

    static var accessibilityStatus: PermissionStatus {
        AXIsProcessTrusted() ? .granted : .unknown
    }

    static var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    @discardableResult
    static func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static var requiredPermissionsGranted: Bool {
        screenRecordingStatus == .granted && accessibilityStatus == .granted
    }

    static func openPrivacyPane(_ pane: PrivacyPane) {
        NSWorkspace.shared.open(pane.url)
    }
}
