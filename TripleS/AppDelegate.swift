import Cocoa
import SwiftUI

extension Notification.Name {
    static let showSoundriftMainWindow = Notification.Name("showSoundriftMainWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillCloseNotification(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
        window.isReleasedWhenClosed = false
        window.title = "Soundrift"
    }

    func requestShowMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.post(name: .showSoundriftMainWindow, object: nil)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = self.mainWindow ?? NSApp.windows.first(where: { $0.title == "Soundrift" }) {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    @objc private func windowWillCloseNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window === mainWindow || window.title == "Soundrift" else { return }

        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            requestShowMainWindow()
        }
        return true
    }
}
