import SwiftUI
import Carbon
import AppKit

struct MainView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var audioManager = AudioManager.shared
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = Int(modifierCmdKey | modifierShiftKey)
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = Int(kVK_UpArrow)
    @State private var isRecordingHotkey = false
    @State private var localEventMonitor: Any?
    @AppStorage("inputHotkeyModifiers") private var inputHotkeyModifiers = Int(modifierCmdKey | modifierShiftKey)
    @AppStorage("inputHotkeyKeyCode") private var inputHotkeyKeyCode = Int(kVK_DownArrow)
    @State private var isRecordingInputHotkey = false
    @State private var outputHotkeyError: String?
    @State private var inputHotkeyError: String?

    private var visibleOutputDevices: [AudioDevice] {
        audioManager.visibleOutputDevices
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var hiddenOutputDevices: [AudioDevice] {
        audioManager.hiddenOutputDevices
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var visibleInputDevices: [AudioDevice] {
        audioManager.visibleInputDevices
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var hiddenInputDevices: [AudioDevice] {
        audioManager.hiddenInputDevices
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            TabView {
                Tab("Output", systemImage: "speaker.wave.3") {
                    outputTab
                }
                Tab("Input", systemImage: "mic") {
                    inputTab
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(MainWindowAccessor().frame(width: 0, height: 0))
        .task {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.openWindowAction = openWindow
            }
        }
        .onAppear {
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: hotkeyKeyCode) { _, _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: hotkeyModifiers) { _, _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: inputHotkeyKeyCode) { _, _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: inputHotkeyModifiers) { _, _ in
            updateDefaultHotkeyIfNeeded()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 20) {
            Text("Soundrift")
                .font(.largeTitle)
                .bold()

            Image("AppIcon2")
                .resizable()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 4) {
                Text("Version 1.3.13")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Created by Kevin Jin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Spacer()

            Text("How to use:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Check devices to include in your shortcut")
                Text("2. Use the bolt icon for auto-switch or Bluetooth reconnect")
                Text("3. Tap the eye icon to hide devices you don't need")
                Text("4. Set up a keyboard shortcut below")
                Text("5. Use the shortcut to quickly switch between devices")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var outputTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let currentDevice = audioManager.currentDevice {
                    currentDeviceBanner(
                        icon: "speaker.wave.3",
                        label: "Current Output:",
                        name: currentDevice.name
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    DeviceListHeader(title: "Available Output Devices")

                    ForEach(visibleOutputDevices) { device in
                        AudioDeviceRow(device: device, kind: .output)
                    }

                    HiddenDevicesSection(devices: hiddenOutputDevices) { device in
                        audioManager.showOutputDevice(device)
                    }
                }

                hotkeySection(
                    title: "Quick Switch Shortcut",
                    hotkeyString: getHotkeyString(),
                    isRecording: isRecordingHotkey,
                    errorMessage: outputHotkeyError,
                    recordAction: toggleHotkeyRecording
                )
            }
            .padding()
        }
    }

    private var inputTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let currentInput = audioManager.currentInputDevice {
                    currentDeviceBanner(
                        icon: "mic",
                        label: "Current Input:",
                        name: currentInput.name
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    DeviceListHeader(title: "Available Input Devices")

                    ForEach(visibleInputDevices) { device in
                        AudioDeviceRow(device: device, kind: .input)
                    }

                    HiddenDevicesSection(devices: hiddenInputDevices) { device in
                        audioManager.showInputDevice(device)
                    }
                }

                hotkeySection(
                    title: "Input Switch Shortcut",
                    hotkeyString: getInputHotkeyString(),
                    isRecording: isRecordingInputHotkey,
                    errorMessage: inputHotkeyError,
                    recordAction: toggleInputHotkeyRecording
                )
            }
            .padding()
        }
    }

    private func currentDeviceBanner(icon: String, label: String, name: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
            Text(label)
                .font(.headline)
            Text(name)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentCardBackground()
    }

    private func hotkeySection(
        title: String,
        hotkeyString: String,
        isRecording: Bool,
        errorMessage: String?,
        recordAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)

            HStack {
                Text(hotkeyString)
                    .padding(8)
                    .frame(minWidth: 120)
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))

                Button(isRecording ? "Press any key..." : "Record", action: recordAction)
                    .buttonStyle(.glassProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Click 'Record' and press your desired key combination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .contentCardBackground()
    }

    private func updateDefaultHotkeyIfNeeded() {
        HotkeyManager.shared.register(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .output)
        }

        HotkeyManager.shared.registerInput(keyCode: inputHotkeyKeyCode, modifiers: inputHotkeyModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .input)
        }
    }

    private func getHotkeyString() -> String {
        hotkeyString(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
    }

    private func getInputHotkeyString() -> String {
        hotkeyString(modifiers: inputHotkeyModifiers, keyCode: inputHotkeyKeyCode)
    }

    private func hotkeyString(modifiers: Int, keyCode: Int) -> String {
        var str = ""
        let flags = UInt(modifiers)

        if flags & modifierControlKey != 0 { str += "⌃" }
        if flags & modifierOptionKey != 0 { str += "⌥" }
        if flags & modifierShiftKey != 0 { str += "⇧" }
        if flags & modifierCmdKey != 0 { str += "⌘" }

        switch keyCode {
        case kVK_DownArrow: str += "↓"
        case kVK_UpArrow: str += "↑"
        case kVK_LeftArrow: str += "←"
        case kVK_RightArrow: str += "→"
        case kVK_Space: str += "Space"
        case kVK_Return: str += "↩"
        case kVK_Delete: str += "⌫"
        case kVK_Escape: str += "⎋"
        case kVK_Tab: str += "⇥"
        default:
            let keyMap: [Int: String] = [
                kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
                kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
                kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
                kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
                kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
                kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
                kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
                kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
                kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
                kVK_ANSI_8: "8", kVK_ANSI_9: "9"
            ]
            str += keyMap[keyCode] ?? "?"
        }

        return str.isEmpty ? "Click to record" : str
    }

    private func toggleHotkeyRecording() {
        if isRecordingHotkey {
            stopHotkeyRecording()
        } else {
            beginHotkeyRecording(forInput: false)
        }
    }

    private func toggleInputHotkeyRecording() {
        if isRecordingInputHotkey {
            stopHotkeyRecording()
        } else {
            beginHotkeyRecording(forInput: true)
        }
    }

    private func beginHotkeyRecording(forInput: Bool) {
        stopHotkeyRecording(restoreHotkeys: false)
        suspendRegisteredHotkeys()

        if forInput {
            inputHotkeyError = nil
            isRecordingInputHotkey = true
        } else {
            outputHotkeyError = nil
            isRecordingHotkey = true
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            Task { @MainActor in
                if forInput {
                    handleInputKeyEvent(event)
                } else {
                    handleKeyEvent(event)
                }
            }
            return nil
        }
    }

    private func suspendRegisteredHotkeys() {
        HotkeyManager.shared.unregister()
        HotkeyManager.shared.unregisterInput()
    }

    private func stopHotkeyRecording(restoreHotkeys: Bool = true) {
        isRecordingHotkey = false
        isRecordingInputHotkey = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if restoreHotkeys {
            updateDefaultHotkeyIfNeeded()
        }
    }

    @MainActor
    private func assignHotkey(keyCode: Int, modifiers: Int, toInput: Bool) {
        let normalizedModifiers = HotkeyValidator.normalizedModifiers(modifiers)
        let result = HotkeyValidator.validate(
            keyCode: keyCode,
            modifiers: normalizedModifiers,
            outputKeyCode: hotkeyKeyCode,
            outputModifiers: hotkeyModifiers,
            inputKeyCode: inputHotkeyKeyCode,
            inputModifiers: inputHotkeyModifiers,
            assigningToInput: toInput
        )

        stopHotkeyRecording()

        switch result {
        case .success:
            if toInput {
                inputHotkeyError = nil
                inputHotkeyModifiers = normalizedModifiers
                inputHotkeyKeyCode = keyCode
            } else {
                outputHotkeyError = nil
                hotkeyModifiers = normalizedModifiers
                hotkeyKeyCode = keyCode
            }
            updateDefaultHotkeyIfNeeded()
        case .failure(let error):
            if toInput {
                inputHotkeyError = error.message
            } else {
                outputHotkeyError = error.message
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecordingHotkey else { return }
        processRecordedEvent(event, toInput: false)
    }

    private func handleInputKeyEvent(_ event: NSEvent) {
        guard isRecordingInputHotkey else { return }
        processRecordedEvent(event, toInput: true)
    }

    private func processRecordedEvent(_ event: NSEvent, toInput: Bool) {
        let validModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let currentModifiers = event.modifierFlags.intersection(validModifiers)
        guard !currentModifiers.isEmpty else { return }

        assignHotkey(
            keyCode: Int(event.keyCode),
            modifiers: Int(currentModifiers.rawValue),
            toInput: toInput
        )
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 800)
}
