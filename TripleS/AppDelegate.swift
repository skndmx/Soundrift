import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDeviceSwitched(_:)),
            name: NSNotification.Name("AudioDeviceSwitched"),
            object: nil
        )
    }

    func registerMainWindow(_ window: NSWindow) {
        if mainWindow !== window {
            mainWindow?.delegate = nil
            mainWindow = window
            window.delegate = self
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Current Device: None", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: "m"))
        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit Soundrift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitMenuItem.target = NSApp
        menu.addItem(quitMenuItem)

        statusItem?.menu = menu
    }

    @objc private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow ?? NSApp.windows.first(where: { $0.title == "Soundrift" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let openWindow = openWindowAction {
            openWindow(id: "main")
        }
    }

    @objc private func audioDeviceSwitched(_ notification: Notification) {
        if let device = notification.object as? AudioDevice {
            statusItem?.menu?.items[0].title = "Current Device: \(device.name)"
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    var openWindowAction: OpenWindowAction?
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
