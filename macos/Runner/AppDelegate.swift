import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    private var mainWindow: MainFlutterWindow?

    override func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)

        // Kurz warten, damit XIB/State Restoration abgeschlossen ist.
        // Danach sicherstellen, dass ein Hauptfenster sichtbar ist.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ensureMainWindowVisible()
        }
    }

    override func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            ensureMainWindowVisible()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        return true
    }

    private func refreshMainWindowReference() {
        mainWindow =
            (NSApp.windows.first { $0 is MainFlutterWindow && $0.isVisible } as? MainFlutterWindow)
            ?? (NSApp.windows.first { $0 is MainFlutterWindow } as? MainFlutterWindow)
    }

    private func ensureMainWindowVisible() {
        refreshMainWindowReference()

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            let window = MainFlutterWindow.createConfigured()
            mainWindow = window
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
