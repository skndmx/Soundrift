import AppKit
import Testing
@testable import Soundrift

struct HotkeyChordTests {
    @Test func tokensForCommandShiftUpArrow() {
        let modifiers = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let chord = HotkeyChord(modifiers: modifiers, keyCode: kVK_UpArrow)
        #expect(chord.tokens == ["⇧", "⌘", "↑"])
        #expect(chord.displayString == "⇧⌘↑")
    }

    @Test func tokensForOptionM() {
        let chord = HotkeyChord(
            modifiers: Int(NSEvent.ModifierFlags.option.rawValue),
            keyCode: kVK_ANSI_M
        )
        #expect(chord.tokens == ["⌥", "M"])
    }
}
