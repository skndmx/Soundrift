import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var audioManager = AudioManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioDeviceSwitched(_:)),
            name: NSNotification.Name("AudioDeviceSwitched"),
            object: nil
        )
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🔊"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Current Device: None", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit Triple S", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitMenuItem.target = NSApp
        menu.addItem(quitMenuItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc private func audioDeviceSwitched(_ notification: Notification) {
        if let device = notification.object as? AudioDevice {
            statusItem?.menu?.items[0].title = "Current Device: \(device.name)"
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running when windows are closed
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }
} 