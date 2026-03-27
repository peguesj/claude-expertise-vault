import SwiftUI
import AppKit

@main
struct ExpertiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Lifted to App level so the menubar label can observe connectivity & badge state.
    @StateObject private var viewModel = SearchViewModel()

    var body: some Scene {
        MenuBarExtra {
            SearchView(viewModel: viewModel)
                .frame(width: 500, height: 660)
        } label: {
            MenuBarLabel(
                serverOnline: viewModel.serverOnline,
                insightsBadge: viewModel.newInsightsCount
            )
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalHotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupGlobalHotkey()
    }

    // MARK: - Global hotkey ⌘⇧E

    private func setupGlobalHotkey() {
        // Use the raw key string to avoid Swift 6 concurrency issue with kAXTrustedCheckOptionPrompt global
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            let alreadyPrompted = UserDefaults.standard.bool(forKey: "accessibilityPrompted")
            if !alreadyPrompted {
                UserDefaults.standard.set(true, forKey: "accessibilityPrompted")
                showAccessibilityAlert()
            }
            return
        }

        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌘⇧E — activate Claude Expertise
            guard event.modifierFlags.contains([.command, .shift]),
                  event.charactersIgnoringModifiers?.lowercased() == "e" else { return }
            self?.activateApp()
        }
    }

    private func activateApp() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Enable Global Shortcut ⌘⇧E"
            alert.informativeText = "To activate Claude Expertise from anywhere, grant Accessibility access in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
