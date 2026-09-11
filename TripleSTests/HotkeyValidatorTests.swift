import AppKit
import Testing
@testable import Soundrift

struct HotkeyValidatorTests {
    private let commandShift = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    private let option = Int(NSEvent.ModifierFlags.option.rawValue)

    @Test func rejectsCommandV() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_V,
            modifiers: Int(NSEvent.ModifierFlags.command.rawValue),
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            assigningToInput: false
        )

        guard case .failure(.reservedSystemShortcut) = result else {
            Issue.record("Expected reserved system shortcut failure")
            return
        }
    }

    @Test func allowsCommandShiftUpArrow() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_UpArrow,
            modifiers: commandShift,
            outputKeyCode: kVK_DownArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            assigningToInput: false
        )

        guard case .failure(.duplicateWithInput) = result else {
            Issue.record("Expected duplicate-with-input failure")
            return
        }
    }

    @Test func rejectsDuplicateInputShortcut() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_UpArrow,
            modifiers: commandShift,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            assigningToInput: true
        )

        guard case .failure(.duplicateWithOutput) = result else {
            Issue.record("Expected duplicate-with-output failure")
            return
        }
    }

    @Test func rejectsDuplicateMuteShortcut() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_M,
            modifiers: option,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            muteKeyCode: kVK_ANSI_M,
            muteModifiers: option,
            assigningTo: .output
        )

        guard case .failure(.duplicateWithMute) = result else {
            Issue.record("Expected duplicate-with-mute failure")
            return
        }
    }

    @Test func allowsDistinctMuteShortcut() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_M,
            modifiers: option,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            muteKeyCode: kVK_ANSI_N,
            muteModifiers: option,
            assigningTo: .mute
        )

        guard case .success = result else {
            Issue.record("Expected option-M to be accepted for mute")
            return
        }
    }
}

struct HotkeyDisplayTests {
    private let commandShift = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    private let option = Int(NSEvent.ModifierFlags.option.rawValue)

    @Test func outputDefaultUsesSeparateKeycaps() {
        #expect(
            HotkeyDisplay.keycaps(modifiers: commandShift, keyCode: kVK_UpArrow) == ["⇧", "⌘", "↑"]
        )
        #expect(HotkeyDisplay.string(modifiers: commandShift, keyCode: kVK_UpArrow) == "⇧⌘↑")
    }

    @Test func inputDefaultUsesDownArrow() {
        #expect(
            HotkeyDisplay.keycaps(modifiers: commandShift, keyCode: kVK_DownArrow) == ["⇧", "⌘", "↓"]
        )
    }

    @Test func muteDefaultUsesOptionM() {
        #expect(
            HotkeyDisplay.keycaps(modifiers: option, keyCode: kVK_ANSI_M) == ["⌥", "M"]
        )
        #expect(HotkeyDisplay.string(modifiers: option, keyCode: kVK_ANSI_M) == "⌥M")
    }
}
