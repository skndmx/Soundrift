import Carbon
import AppKit

// Modifier keys
let modifierCmdKey = UInt(NSEvent.ModifierFlags.command.rawValue)
let modifierControlKey = UInt(NSEvent.ModifierFlags.control.rawValue)
let modifierOptionKey = UInt(NSEvent.ModifierFlags.option.rawValue)
let modifierShiftKey = UInt(NSEvent.ModifierFlags.shift.rawValue)

// Virtual key codes for letters
let kVK_ANSI_A                    = 0x00
let kVK_ANSI_S                    = 0x01
let kVK_ANSI_D                    = 0x02
let kVK_ANSI_F                    = 0x03
let kVK_ANSI_H                    = 0x04
let kVK_ANSI_G                    = 0x05
let kVK_ANSI_Z                    = 0x06
let kVK_ANSI_X                    = 0x07
let kVK_ANSI_C                    = 0x08
let kVK_ANSI_V                    = 0x09
let kVK_ANSI_B                    = 0x0B
let kVK_ANSI_Q                    = 0x0C
let kVK_ANSI_W                    = 0x0D
let kVK_ANSI_E                    = 0x0E
let kVK_ANSI_R                    = 0x0F
let kVK_ANSI_Y                    = 0x10
let kVK_ANSI_T                    = 0x11
let kVK_ANSI_1                    = 0x12
let kVK_ANSI_2                    = 0x13
let kVK_ANSI_3                    = 0x14
let kVK_ANSI_4                    = 0x15
let kVK_ANSI_6                    = 0x16
let kVK_ANSI_5                    = 0x17
let kVK_ANSI_9                    = 0x19
let kVK_ANSI_7                    = 0x1A
let kVK_ANSI_8                    = 0x1B
let kVK_ANSI_0                    = 0x1D
let kVK_ANSI_O                    = 0x1F
let kVK_ANSI_U                    = 0x20
let kVK_ANSI_I                    = 0x22
let kVK_ANSI_P                    = 0x23
let kVK_ANSI_L                    = 0x25
let kVK_ANSI_J                    = 0x26
let kVK_ANSI_K                    = 0x28
let kVK_ANSI_N                    = 0x2D
let kVK_ANSI_M                    = 0x2E

// Special keys
let kVK_Return                    = 0x24
let kVK_Tab                       = 0x30
let kVK_Space                     = 0x31
let kVK_Delete                    = 0x33
let kVK_Escape                    = 0x35

// Helper function to convert key code to string
func keyCodeToString(_ keyCode: Int) -> String {
    switch keyCode {
    case kVK_DownArrow:
        return "↓"
    case kVK_UpArrow:
        return "↑"
    case kVK_LeftArrow:
        return "←"
    case kVK_RightArrow:
        return "→"
    case kVK_Space:
        return "Space"
    case kVK_Return:
        return "⏎"
    case kVK_Delete:
        return "⌫"
    case kVK_Tab:
        return "⇥"
    case kVK_Escape:
        return "⎋"
    default:
        let str = String(format: "%c", keyCode).uppercased()
        return str.isEmpty ? "Key \(keyCode)" : str
    }
}