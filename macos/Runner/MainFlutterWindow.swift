import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {

    override func awakeFromNib() {
        super.awakeFromNib()

        self.delegate = self
        self.configureFlutterWindow()
    }

    static func createConfigured() -> MainFlutterWindow {
        let window = MainFlutterWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1600, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.delegate = window
        window.configureFlutterWindow()
        window.center()

        return window
    }

    private func configureFlutterWindow() {
        guard contentViewController == nil else { return }

        // Important: prevents macOS from restoring the "no window" state.
        self.isRestorable = false

        // Set title and size after a delay so the XIB doesn't override them.
        DispatchQueue.main.async {
            self.title = "Maskr"
            self.setFrame(NSRect(x: 0, y: 0, width: 1300, height: 850), display: true)
            self.center()
        }
        self.minSize = NSSize(width: 1000, height: 650)

        let flutterViewController = FlutterViewController()
        self.contentViewController = flutterViewController

        RegisterGeneratedPlugins(registry: flutterViewController)
    }

    func windowWillClose(_ notification: Notification) {
        // Quit the app when no other visible window remains.
        let remainingVisibleWindows = NSApp.windows.filter {
            $0.isVisible && $0 !== self
        }

        if remainingVisibleWindows.isEmpty {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    override var canBecomeKey: Bool {
        return true
    }
}
