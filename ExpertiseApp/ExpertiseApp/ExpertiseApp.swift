import SwiftUI
import AppKit

@main
struct ExpertiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SearchView()
                .frame(width: 420, height: 560)
        } label: {
            Label("CE", systemImage: "brain.head.profile")
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let searchView = SearchView()
            .frame(minWidth: 480, minHeight: 600)

        let hostingController = NSHostingController(rootView: searchView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = "Claude Expertise"
        win.setContentSize(NSSize(width: 480, height: 640))
        win.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        win.center()
        win.makeKeyAndOrderFront(nil)

        self.window = win

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
