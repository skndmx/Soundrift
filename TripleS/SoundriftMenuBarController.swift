import AppKit

/// AppKit status item that rebuilds on open. Device lists, mute, then the window.
final class SoundriftMenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let showMainWindow: () -> Void
    private var devicePicks: [DevicePick] = []
    private var switchObserver: NSObjectProtocol?

    init(showMainWindow: @escaping () -> Void) {
        self.showMainWindow = showMainWindow
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuBarIconImage
            button.image?.isTemplate = true
            button.toolTip = "Soundrift"
        }

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        updateTooltip()

        switchObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AudioDeviceSwitched"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTooltip()
        }
    }

    deinit {
        if let switchObserver {
            NotificationCenter.default.removeObserver(switchObserver)
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
        updateTooltip()
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        devicePicks.removeAll()

        let manager = AudioManager.shared

        addSection(menu, title: "Output")
        addDeviceRows(
            menu,
            devices: manager.visibleOutputDevices,
            current: manager.currentDevice ?? AudioDevice.getCurrentDefault(),
            kind: .output
        )

        menu.addItem(.separator())

        addSection(menu, title: "Input")
        addDeviceRows(
            menu,
            devices: manager.visibleInputDevices,
            current: manager.currentInputDevice ?? AudioDevice.getCurrentDefaultInput(),
            kind: .input
        )

        menu.addItem(.separator())

        let muted = manager.isCurrentInputMuted()
        let muteItem = NSMenuItem(
            title: muted ? "Unmute Microphone" : "Mute Microphone",
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        muteItem.image = menuSymbolImage(muted ? "mic.slash" : "mic")
        menu.addItem(muteItem)

        menu.addItem(.separator())

        let showItem = NSMenuItem(
            title: "Show Main Window",
            action: #selector(showWindow),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Soundrift",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addSection(_ menu: NSMenu, title: String) {
        menu.addItem(.sectionHeader(title: title))
    }

    private func addDeviceRows(
        _ menu: NSMenu,
        devices: [AudioDevice],
        current: AudioDevice?,
        kind: DeviceType
    ) {
        let rows = SoundriftMenuBarModel.deviceRows(
            devices: devices,
            current: current,
            kind: kind,
            isEnabled: { SoundriftMenuBarModel.isDeviceSwitchable($0, kind: kind) }
        )

        guard !rows.isEmpty else {
            let empty = NSMenuItem(
                title: kind == .output ? "No Output Devices" : "No Input Devices",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for row in rows {
            let pick = DevicePick(device: row.device, kind: kind)
            devicePicks.append(pick)

            let item = NSMenuItem(
                title: row.title,
                action: #selector(selectDevice(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = pick
            item.state = row.isCurrent ? .on : .off
            item.isEnabled = row.isEnabled
            item.image = menuSymbolImage(row.symbolName)
            if !row.isEnabled {
                item.toolTip = row.device.isConnected
                    ? "macOS cannot set this device as the system default."
                    : "Disconnected"
            }
            menu.addItem(item)
        }
    }

    private func updateTooltip() {
        let name = AudioManager.shared.currentDevice?.name
            ?? AudioDevice.getCurrentDefault()?.name
        statusItem.button?.toolTip = name ?? "Soundrift"
    }

    private func menuSymbolImage(_ systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        let configured = image.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        ) ?? image
        configured.isTemplate = true
        return configured
    }

    private static var menuBarIconImage: NSImage {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let pick = sender.representedObject as? DevicePick else { return }
        switch pick.kind {
        case .output:
            AudioManager.shared.selectOutputDevice(pick.device)
        case .input:
            AudioManager.shared.selectInputDevice(pick.device)
        }
        updateTooltip()
    }

    @objc private func toggleMute() {
        DeviceSwitchManager.shared.toggleMicrophoneMute()
    }

    @objc private func showWindow() {
        showMainWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private final class DevicePick: NSObject {
    let device: AudioDevice
    let kind: DeviceType

    init(device: AudioDevice, kind: DeviceType) {
        self.device = device
        self.kind = kind
    }
}
