import AppKit
import Testing
@testable import Soundrift

struct HotkeyValidatorTests {
    @Test func rejectsCommandV() {
        let result = HotkeyValidator.validate(
            keyCode: kVK_ANSI_V,
            modifiers: Int(NSEvent.ModifierFlags.command.rawValue),
            outputKeyCode: kVK_UpArrow,
            outputModifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            inputKeyCode: kVK_DownArrow,
            inputModifiers: Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            assigningToInput: false
        )

        guard case .failure(.reservedSystemShortcut) = result else {
            Issue.record("Expected reserved system shortcut failure")
            return
        }
    }

    @Test func allowsCommandShiftUpArrow() {
        let modifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let result = HotkeyValidator.validate(
            keyCode: kVK_UpArrow,
            modifiers: modifiers,
            outputKeyCode: kVK_DownArrow,
            outputModifiers: modifiers,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: modifiers,
            assigningToInput: false
        )

        guard case .failure(.duplicateWithInput) = result else {
            Issue.record("Expected duplicate-with-input failure")
            return
        }
    }

    @Test func rejectsDuplicateInputShortcut() {
        let modifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let result = HotkeyValidator.validate(
            keyCode: kVK_UpArrow,
            modifiers: modifiers,
            outputKeyCode: kVK_UpArrow,
            outputModifiers: modifiers,
            inputKeyCode: kVK_DownArrow,
            inputModifiers: modifiers,
            assigningToInput: true
        )

        guard case .failure(.duplicateWithOutput) = result else {
            Issue.record("Expected duplicate-with-output failure")
            return
        }
    }
}
