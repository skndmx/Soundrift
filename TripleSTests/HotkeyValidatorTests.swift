import AppKit
import Testing
@testable import Soundrift

struct HotkeyValidatorTests {
    private let commandShift = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    private let controlOption = Int(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)

    @Test func rejectsCommandV() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_V,
            modifiers: Int(NSEvent.ModifierFlags.command.rawValue),
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            muteKeyCode: kVK_ANSI_M,
            muteModifiers: controlOption,
            assigningTo: .output
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
            muteKeyCode: kVK_ANSI_M,
            muteModifiers: controlOption,
            assigningTo: .output
        )

        guard case .success = result else {
            Issue.record("Expected Command-Shift-Up to be allowed")
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
            muteKeyCode: kVK_ANSI_M,
            muteModifiers: controlOption,
            assigningTo: .input
        )

        guard case .failure(.duplicateWithOutput) = result else {
            Issue.record("Expected duplicate-with-output failure")
            return
        }
    }

    @Test func rejectsDuplicateMuteShortcut() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_M,
            modifiers: controlOption,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            muteKeyCode: kVK_ANSI_M,
            muteModifiers: controlOption,
            assigningTo: .output
        )

        guard case .failure(.duplicateWithMute) = result else {
            Issue.record("Expected duplicate-with-mute failure")
            return
        }
    }

    @Test func allowsControlOptionMForMute() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_M,
            modifiers: controlOption,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: commandShift,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: commandShift,
            muteKeyCode: kVK_ANSI_N,
            muteModifiers: controlOption,
            assigningTo: .mute
        )

        guard case .success = result else {
            Issue.record("Expected Control-Option-M to be allowed for mute")
            return
        }
    }
}
