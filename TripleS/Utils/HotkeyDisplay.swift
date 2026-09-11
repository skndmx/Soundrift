import AppKit
import Carbon

enum HotkeyDisplay {
    static func keycaps(modifiers: Int, keyCode: Int) -> [String] {
        var parts: [String] = []
        let flags = UInt(bitPattern: HotkeyValidator.normalizedModifiers(modifiers))

        if flags & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { parts.append("⌃") }
        if flags & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { parts.append("⌥") }
        if flags & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { parts.append("⇧") }
        if flags & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { parts.append("⌘") }

        if let key = keySymbol(keyCode) {
            parts.append(key)
        }

        return parts
    }

    static func string(modifiers: Int, keyCode: Int) -> String {
        let parts = keycaps(modifiers: modifiers, keyCode: keyCode)
        return parts.isEmpty ? "Click to record" : parts.joined()
    }

    private static func keySymbol(_ keyCode: Int) -> String? {
        switch keyCode {
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_Tab: return "⇥"
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
            return keyMap[keyCode] ?? "?"
        }
    }
}
