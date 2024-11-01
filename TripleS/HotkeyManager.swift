import Carbon
import Cocoa

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?
    
    private init() {}
    
    func register(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")
        
        // Convert to Carbon modifier flags if needed
        var carbonModifiers = modifiers
        if carbonModifiers == 0 {
            // If no modifiers are set, default to Command + Control
            carbonModifiers = Int(cmdKey | controlKey)
        }
        
        print("Carbon Modifiers: \(carbonModifiers)")
        
        // Unregister existing hotkey if any
        unregister()
        
        self.callback = callback
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Store callback
        let userData = UnsafeMutableRawPointer(Unmanaged.passRetained(CallbackWrapper(callback)).toOpaque())
        
        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                print("Hotkey detected!")
                let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(userData!).takeUnretainedValue()
                wrapper.callback()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        
        // Register hotkey
        let gMyHotKeyID = EventHotKeyID(signature: OSType("TSSS".fourCharCodeValue), id: 1)
        
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            gMyHotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
        
        print("Hotkey registration final status: \(registerStatus)")
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private class CallbackWrapper {
        let callback: () -> Void
        
        init(_ callback: @escaping () -> Void) {
            self.callback = callback
        }
    }
}

// Helper extension to convert string to fourCharCode
extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        let chars = Array(utf8)
        for i in 0..<min(chars.count, 4) {
            result = result << 8 + UInt32(chars[i])
        }
        return result
    }
} 