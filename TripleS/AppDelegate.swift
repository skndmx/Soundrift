import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private var keyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
        installCloseKeyMonitor()
    }

    private func setupMainWindow() {
        // fullSizeContentView + unified toolbar are required for NavigationSplitView's
        // sidebar collapse control to sit in the correct leading titlebar position.
        // Without them (plain NSHostingView chrome), the toggle jumps to the wrong place.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Soundrift"
        window.minSize = NSSize(width: 600, height: 500)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.contentViewController = NSHostingController(
            rootView: MainView()
                .frame(minWidth: 600, minHeight: 500)
        )
        window.delegate = self
        window.setFrameAutosaveName("SoundriftMainWindow")
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    /// SwiftUI `.commands` are unreliable for AppKit-hosted windows; intercept ⌘W directly.
    private func installCloseKeyMonitor() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let isCommandW = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(.command)
                && !event.modifierFlags.contains(.shift)
                && !event.modifierFlags.contains(.option)
                && !event.modifierFlags.contains(.control)
                && event.charactersIgnoringModifiers?.lowercased() == "w"
            guard isCommandW else { return event }
            guard let window = self.mainWindow, window.isVisible else { return event }
            self.hideMainWindow()
            return nil
        }
    }

    func requestShowMainWindow() {
        // MenuBarExtra still holds key window until the menu finishes closing.
        DispatchQueue.main.async { [weak self] in
            self?.presentMainWindow()
        }
    }

    private func presentMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window = mainWindow else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc func hideMainWindow() {
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of destroying so we never spawn a second window,
        // and drop to accessory so the Dock dot disappears.
        hideMainWindow()
        return false
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
