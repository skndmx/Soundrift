import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private var mainHostingController: NSViewController?
    private var keyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
        installCloseKeyMonitor()
    }

    private func setupMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SoundriftTheme.windowWidth, height: SoundriftTheme.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Soundrift"
        window.minSize = NSSize(width: 560, height: 440)
        window.isReleasedWhenClosed = false

        let hostingController = NSHostingController(rootView: MainView())
        hostingController.safeAreaRegions = []
        mainHostingController = hostingController
        SoundriftWindowChrome.applyLiquidGlass(to: window, hostingView: hostingController.view)
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
