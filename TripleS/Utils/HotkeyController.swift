import AppKit
import Carbon
import SwiftUI

@MainActor
final class HotkeyController: ObservableObject {
    private enum DefaultsKey {
        static let outputModifiers = "hotkeyModifiers"
        static let outputKeyCode = "hotkeyKeyCode"
        static let inputModifiers = "inputHotkeyModifiers"
        static let inputKeyCode = "inputHotkeyKeyCode"
        static let muteModifiers = "muteHotkeyModifiers"
        static let muteKeyCode = "muteHotkeyKeyCode"
    }

    @Published var outputModifiers: Int {
        didSet { UserDefaults.standard.set(outputModifiers, forKey: DefaultsKey.outputModifiers) }
    }
    @Published var outputKeyCode: Int {
        didSet { UserDefaults.standard.set(outputKeyCode, forKey: DefaultsKey.outputKeyCode) }
    }
    @Published var inputModifiers: Int {
        didSet { UserDefaults.standard.set(inputModifiers, forKey: DefaultsKey.inputModifiers) }
    }
    @Published var inputKeyCode: Int {
        didSet { UserDefaults.standard.set(inputKeyCode, forKey: DefaultsKey.inputKeyCode) }
    }
    @Published var muteModifiers: Int {
        didSet { UserDefaults.standard.set(muteModifiers, forKey: DefaultsKey.muteModifiers) }
    }
    @Published var muteKeyCode: Int {
        didSet { UserDefaults.standard.set(muteKeyCode, forKey: DefaultsKey.muteKeyCode) }
    }

    @Published private(set) var recordingTarget: HotkeyAssignment?
    @Published var outputError: String?
    @Published var inputError: String?
    @Published var muteError: String?

    private var localEventMonitor: Any?

    init() {
        let defaults = UserDefaults.standard
        outputModifiers = defaults.object(forKey: DefaultsKey.outputModifiers) as? Int
            ?? Int(modifierCmdKey | modifierShiftKey)
        outputKeyCode = defaults.object(forKey: DefaultsKey.outputKeyCode) as? Int
            ?? Int(kVK_UpArrow)
        inputModifiers = defaults.object(forKey: DefaultsKey.inputModifiers) as? Int
            ?? Int(modifierCmdKey | modifierShiftKey)
        inputKeyCode = defaults.object(forKey: DefaultsKey.inputKeyCode) as? Int
            ?? Int(kVK_DownArrow)
        muteModifiers = defaults.object(forKey: DefaultsKey.muteModifiers) as? Int
            ?? Int(modifierOptionKey)
        muteKeyCode = defaults.object(forKey: DefaultsKey.muteKeyCode) as? Int
            ?? Int(kVK_ANSI_M)
    }

    var outputKeycaps: [String] {
        HotkeyDisplay.keycaps(modifiers: outputModifiers, keyCode: outputKeyCode)
    }

    var inputKeycaps: [String] {
        HotkeyDisplay.keycaps(modifiers: inputModifiers, keyCode: inputKeyCode)
    }

    var muteKeycaps: [String] {
        HotkeyDisplay.keycaps(modifiers: muteModifiers, keyCode: muteKeyCode)
    }

    func error(for target: HotkeyAssignment) -> String? {
        switch target {
        case .output: outputError
        case .input: inputError
        case .mute: muteError
        }
    }

    func registerAll() {
        HotkeyManager.shared.register(keyCode: outputKeyCode, modifiers: outputModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .output)
        }
        HotkeyManager.shared.registerInput(keyCode: inputKeyCode, modifiers: inputModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .input)
        }
        HotkeyManager.shared.registerMute(keyCode: muteKeyCode, modifiers: muteModifiers) {
            DeviceSwitchManager.shared.toggleMicrophoneMute()
        }
    }

    func beginRecording(_ target: HotkeyAssignment) {
        stopRecording(restoreHotkeys: false)
        HotkeyManager.shared.unregisterAll()
        setError(nil, for: target)
        recordingTarget = target

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleRecordedEvent(event)
            }
            return nil
        }
    }

    func stopRecording(restoreHotkeys: Bool = true) {
        recordingTarget = nil
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if restoreHotkeys {
            registerAll()
        }
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        guard let target = recordingTarget else { return }

        if event.keyCode == UInt16(kVK_Escape),
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            stopRecording()
            return
        }

        let validModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let currentModifiers = event.modifierFlags.intersection(validModifiers)
        guard !currentModifiers.isEmpty else { return }

        assign(
            keyCode: Int(event.keyCode),
            modifiers: Int(currentModifiers.rawValue),
            to: target
        )
    }

    private func assign(keyCode: Int, modifiers: Int, to target: HotkeyAssignment) {
        let normalizedModifiers = HotkeyValidator.normalizedModifiers(modifiers)
        let result = HotkeyValidator.validate(
            keyCode: keyCode,
            modifiers: normalizedModifiers,
            outputKeyCode: outputKeyCode,
            outputModifiers: outputModifiers,
            inputKeyCode: inputKeyCode,
            inputModifiers: inputModifiers,
            muteKeyCode: muteKeyCode,
            muteModifiers: muteModifiers,
            assigningTo: target
        )

        stopRecording()

        switch result {
        case .success:
            setError(nil, for: target)
            switch target {
            case .output:
                outputModifiers = normalizedModifiers
                outputKeyCode = keyCode
            case .input:
                inputModifiers = normalizedModifiers
                inputKeyCode = keyCode
            case .mute:
                muteModifiers = normalizedModifiers
                muteKeyCode = keyCode
            }
            registerAll()
        case .failure(let error):
            setError(error.message, for: target)
        }
    }

    private func setError(_ message: String?, for target: HotkeyAssignment) {
        switch target {
        case .output: outputError = message
        case .input: inputError = message
        case .mute: muteError = message
        }
    }
}
