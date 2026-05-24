import AppKit
import SwiftUI

extension Notification.Name {
    static let reCordToggleRecording = Notification.Name("reCordToggleRecording")
    static let reCordAddManualZoom = Notification.Name("reCordAddManualZoom")
}

@main
struct ReCordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .frame(minWidth: 1120, minHeight: 720)
                .onReceive(NotificationCenter.default.publisher(for: .reCordToggleRecording)) { _ in
                    Task {
                        if appState.isRecording {
                            await appState.stopRecording()
                        } else {
                            await appState.startRecording()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .reCordAddManualZoom)) { _ in
                    appState.addManualZoomCommand()
                }
        }
        .commands {
            CommandMenu("Recording") {
                Button(appState.isRecording ? "Stop Recording" : "Start Recording") {
                    Task {
                        if appState.isRecording {
                            await appState.stopRecording()
                        } else {
                            await appState.startRecording()
                        }
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Export Selected") {
                    Task { await appState.exportSelectedSession() }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var shortcutMonitor: ShortcutMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ReCord"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start/Stop Recording", action: #selector(toggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ReCord", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        shortcutMonitor = ShortcutMonitor()
        shortcutMonitor?.start()
    }

    @objc private func toggleRecording() {
        NotificationCenter.default.post(name: .reCordToggleRecording, object: nil)
    }
}

final class ShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private static func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), flags.contains(.shift) else { return }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "r":
            NotificationCenter.default.post(name: .reCordToggleRecording, object: nil)
        case "z":
            NotificationCenter.default.post(name: .reCordAddManualZoom, object: nil)
        default:
            break
        }
    }
}
