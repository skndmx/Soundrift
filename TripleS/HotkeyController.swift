import AppKit
import SwiftUI

@MainActor
final class HotkeyController: ObservableObject {
    private enum Keys {
        static let outputModifiers = "hotkeyModifiers"
        static let outputKeyCode = "hotkeyKeyCode"
        static let inputModifiers = "inputHotkeyModifiers"
        static let inputKeyCode = "inputHotkeyKeyCode"
        static let muteModifiers = "muteHotkeyModifiers"
        static let muteKeyCode = "muteHotkeyKeyCode"
    }

    @Published var outputModifiers: Int {
        didSet { UserDefaults.standard.set(outputModifiers, forKey: Keys.outputModifiers) }
    }
    @Published var outputKeyCode: Int {
        didSet { UserDefaults.standard.set(outputKeyCode, forKey: Keys.outputKeyCode) }
    }
    @Published var inputModifiers: Int {
        didSet { UserDefaults.standard.set(inputModifiers, forKey: Keys.inputModifiers) }
    }
    @Published var inputKeyCode: Int {
        didSet { UserDefaults.standard.set(inputKeyCode, forKey: Keys.inputKeyCode) }
    }
    @Published var muteModifiers: Int {
        didSet { UserDefaults.standard.set(muteModifiers, forKey: Keys.muteModifiers) }
    }
    @Published var muteKeyCode: Int {
        didSet { UserDefaults.standard.set(muteKeyCode, forKey: Keys.muteKeyCode) }
    }

    @Published var recordingTarget: ShortcutKind?
    @Published var outputError: String?
    @Published var inputError: String?
    @Published var muteError: String?

    private var localEventMonitor: Any?

    init() {
        let defaults = UserDefaults.standard
        outputModifiers = defaults.object(forKey: Keys.outputModifiers) as? Int
            ?? Int(modifierCmdKey | modifierShiftKey)
        outputKeyCode = defaults.object(forKey: Keys.outputKeyCode) as? Int
            ?? kVK_UpArrow
        inputModifiers = defaults.object(forKey: Keys.inputModifiers) as? Int
            ?? Int(modifierCmdKey | modifierShiftKey)
        inputKeyCode = defaults.object(forKey: Keys.inputKeyCode) as? Int
            ?? kVK_DownArrow
        muteModifiers = defaults.object(forKey: Keys.muteModifiers) as? Int
            ?? Int(modifierOptionKey)
        muteKeyCode = defaults.object(forKey: Keys.muteKeyCode) as? Int
            ?? kVK_ANSI_M
    }

    func chord(for kind: ShortcutKind) -> HotkeyChord {
        switch kind {
        case .output: HotkeyChord(modifiers: outputModifiers, keyCode: outputKeyCode)
        case .input: HotkeyChord(modifiers: inputModifiers, keyCode: inputKeyCode)
        case .mute: HotkeyChord(modifiers: muteModifiers, keyCode: muteKeyCode)
        }
    }

    func error(for kind: ShortcutKind) -> String? {
        switch kind {
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
            AudioManager.shared.toggleCurrentInputMute()
        }
    }

    func beginRecording(_ kind: ShortcutKind) {
        stopRecording(restoreHotkeys: false)
        suspendRegisteredHotkeys()
        clearError(for: kind)
        recordingTarget = kind

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleRecordedEvent(event)
            }
            return nil
        }
    }

    func cancelRecording() {
        stopRecording(restoreHotkeys: true)
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

    private func suspendRegisteredHotkeys() {
        HotkeyManager.shared.unregister()
        HotkeyManager.shared.unregisterInput()
        HotkeyManager.shared.unregisterMute()
    }

    private func clearError(for kind: ShortcutKind) {
        switch kind {
        case .output: outputError = nil
        case .input: inputError = nil
        case .mute: muteError = nil
        }
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        guard let recordingTarget else { return }

        let validModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let currentModifiers = event.modifierFlags.intersection(validModifiers)
        let keyCode = Int(event.keyCode)

        if keyCode == kVK_Escape, currentModifiers.isEmpty {
            cancelRecording()
            return
        }

        guard !currentModifiers.isEmpty else { return }

        assign(
            keyCode: keyCode,
            modifiers: Int(currentModifiers.rawValue),
            to: recordingTarget
        )
    }

    private func assign(keyCode: Int, modifiers: Int, to kind: ShortcutKind) {
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
            assigningTo: kind.hotkeyRole
        )

        stopRecording()

        switch result {
        case .success:
            clearError(for: kind)
            switch kind {
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
            switch kind {
            case .output: outputError = error.message
            case .input: inputError = error.message
            case .mute: muteError = error.message
            }
        }
    }
}

extension ShortcutKind {
    var hotkeyRole: HotkeyRole {
        switch self {
        case .output: .output
        case .input: .input
        case .mute: .mute
        }
    }
}
