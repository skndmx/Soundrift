import Carbon
import AppKit

enum HotkeyAssignment: Equatable {
    case output
    case input
    case mute
}

enum HotkeyValidationError: Equatable, Error {
    case requiresModifier
    case reservedSystemShortcut(String)
    case duplicateWithOutput
    case duplicateWithInput
    case duplicateWithMute

    var message: String {
        switch self {
        case .requiresModifier:
            return "Include at least one modifier key (⌘, ⌃, ⌥, or ⇧)."
        case .reservedSystemShortcut(let reason):
            return reason
        case .duplicateWithOutput:
            return "This shortcut is already used for output switching."
        case .duplicateWithInput:
            return "This shortcut is already used for input switching."
        case .duplicateWithMute:
            return "This shortcut is already used for microphone mute."
        }
    }
}

enum HotkeyValidator {
    static func normalizedModifiers(_ modifiers: Int) -> Int {
        if modifiers > 0 && modifiers < 65_536 {
            return carbonModifiersToAppKit(modifiers)
        }

        return Int(
            NSEvent.ModifierFlags(rawValue: UInt(bitPattern: modifiers))
                .intersection([.command, .control, .option, .shift])
                .rawValue
        )
    }

    static func hotkeysMatch(
        keyCode lhsKeyCode: Int,
        modifiers lhsModifiers: Int,
        keyCode rhsKeyCode: Int,
        modifiers rhsModifiers: Int
    ) -> Bool {
        lhsKeyCode == rhsKeyCode
            && normalizedModifiers(lhsModifiers) == normalizedModifiers(rhsModifiers)
    }

    private static func carbonModifiersToAppKit(_ modifiers: Int) -> Int {
        var result: UInt = 0
        if modifiers & cmdKey != 0 { result |= NSEvent.ModifierFlags.command.rawValue }
        if modifiers & shiftKey != 0 { result |= NSEvent.ModifierFlags.shift.rawValue }
        if modifiers & optionKey != 0 { result |= NSEvent.ModifierFlags.option.rawValue }
        if modifiers & controlKey != 0 { result |= NSEvent.ModifierFlags.control.rawValue }
        return Int(result)
    }

    static func validate(
        keyCode: Int,
        modifiers: Int,
        outputKeyCode: Int,
        outputModifiers: Int,
        inputKeyCode: Int,
        inputModifiers: Int,
        muteKeyCode: Int = 0,
        muteModifiers: Int = 0,
        assigningTo: HotkeyAssignment
    ) -> Result<Void, HotkeyValidationError> {
        let normalized = normalizedModifiers(modifiers)
        guard normalized != 0 else {
            return .failure(.requiresModifier)
        }

        if let reason = reservedReason(keyCode: keyCode, modifiers: normalized) {
            return .failure(.reservedSystemShortcut(reason))
        }

        let candidate = (keyCode, normalized)
        let output = (outputKeyCode, normalizedModifiers(outputModifiers))
        let input = (inputKeyCode, normalizedModifiers(inputModifiers))
        let mute = (muteKeyCode, normalizedModifiers(muteModifiers))

        if assigningTo != .output, matches(candidate, output) {
            return .failure(.duplicateWithOutput)
        }
        if assigningTo != .input, matches(candidate, input) {
            return .failure(.duplicateWithInput)
        }
        if assigningTo != .mute, muteKeyCode != 0, matches(candidate, mute) {
            return .failure(.duplicateWithMute)
        }

        return .success(())
    }

    /// Compatibility wrapper for the previous `assigningToInput` flag.
    static func validate(
        keyCode: Int,
        modifiers: Int,
        outputKeyCode: Int,
        outputModifiers: Int,
        inputKeyCode: Int,
        inputModifiers: Int,
        assigningToInput: Bool
    ) -> Result<Void, HotkeyValidationError> {
        validate(
            keyCode: keyCode,
            modifiers: modifiers,
            outputKeyCode: outputKeyCode,
            outputModifiers: outputModifiers,
            inputKeyCode: inputKeyCode,
            inputModifiers: inputModifiers,
            assigningTo: assigningToInput ? .input : .output
        )
    }

    private static func matches(
        _ lhs: (Int, Int),
        _ rhs: (Int, Int)
    ) -> Bool {
        hotkeysMatch(
            keyCode: lhs.0,
            modifiers: lhs.1,
            keyCode: rhs.0,
            modifiers: rhs.1
        )
    }

    private static func reservedReason(keyCode: Int, modifiers: Int) -> String? {
        let hasCommand = modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0
        let hasShift = modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0
        let hasOption = modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0
        let hasControl = modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0

        if hasCommand && !hasShift && !hasOption && !hasControl {
            if isLetterOrNumber(keyCode) || isEditingKey(keyCode) {
                return "⌘ plus a letter, number, or editing key is reserved by macOS (for example, ⌘V pastes)."
            }
            if isNavigationKey(keyCode) {
                return "⌘ plus an arrow key is reserved by macOS for text navigation."
            }
        }

        if matches(keyCode: keyCode, modifiers: modifiers, command: true, shift: false, option: false, control: false, key: kVK_Space) {
            return "⌘Space opens Spotlight and cannot be used."
        }

        if matches(keyCode: keyCode, modifiers: modifiers, command: true, shift: false, option: false, control: false, key: kVK_ANSI_Q) {
            return "⌘Q quits applications and cannot be used."
        }

        if matches(keyCode: keyCode, modifiers: modifiers, command: true, shift: false, option: false, control: false, key: kVK_ANSI_W) {
            return "⌘W closes windows and cannot be used."
        }

        if matches(keyCode: keyCode, modifiers: modifiers, command: true, shift: false, option: true, control: false, key: kVK_Escape) {
            return "⌘⌥Esc opens Force Quit and cannot be used."
        }

        return nil
    }

    private static func matches(
        keyCode: Int,
        modifiers: Int,
        command: Bool,
        shift: Bool,
        option: Bool,
        control: Bool,
        key: Int
    ) -> Bool {
        guard keyCode == key else { return false }

        let hasCommand = modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0
        let hasShift = modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0
        let hasOption = modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0
        let hasControl = modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0

        return hasCommand == command
            && hasShift == shift
            && hasOption == option
            && hasControl == control
    }

    private static func isLetterOrNumber(_ keyCode: Int) -> Bool {
        let letterAndNumberKeys = [
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F,
            kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
            kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
            kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X,
            kVK_ANSI_Y, kVK_ANSI_Z,
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
            kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        ]
        return letterAndNumberKeys.contains(keyCode)
    }

    private static func isEditingKey(_ keyCode: Int) -> Bool {
        [kVK_Space, kVK_Tab, kVK_Return, kVK_Delete, kVK_Escape].contains(keyCode)
    }

    private static func isNavigationKey(_ keyCode: Int) -> Bool {
        [kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_RightArrow].contains(keyCode)
    }
}
