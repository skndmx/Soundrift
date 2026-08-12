import Carbon
import Cocoa

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var inputHotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?
    private var inputCallback: (() -> Void)?
    
    private init() {}
    
    func register(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Output Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")
        
        // Convert AppKit modifiers to Carbon modifiers
        var carbonModifiers = 0
        if modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { carbonModifiers |= cmdKey }
        if modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { carbonModifiers |= controlKey }
        if modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0 { carbonModifiers |= optionKey }
        if modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbonModifiers |= shiftKey }
        
        print("Carbon Modifiers: \(carbonModifiers)")
        
        // Unregister existing hotkey if any
        unregister()
        
        self.callback = callback
        
        setupEventHandler()
        
        // Register hotkey
        let gMyHotKeyID = EventHotKeyID(signature: OSType("TSSO".fourCharCodeValue), id: 1)
        
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            gMyHotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
        
        print("Output hotkey registration status: \(registerStatus)")
    }
    
    func registerInput(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Input Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")
        
        var carbonModifiers = 0
        if modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { carbonModifiers |= cmdKey }
        if modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { carbonModifiers |= controlKey }
        if modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0 { carbonModifiers |= optionKey }
        if modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbonModifiers |= shiftKey }
        
        unregisterInput()
        
        self.inputCallback = callback
        
        // Register input hotkey
        let gMyHotKeyID = EventHotKeyID(signature: OSType("TSSI".fourCharCodeValue), id: 2)
        
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            gMyHotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &inputHotKeyRef
        )
        
        print("Input hotkey registration status: \(registerStatus)")
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    func unregisterInput() {
        if let hotKeyRef = inputHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.inputHotKeyRef = nil
        }
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr {
                    if hotKeyID.signature == OSType("TSSO".fourCharCodeValue) {
                        print("Hotkey detected! (output)")
                        manager.callback?()
                    } else if hotKeyID.signature == OSType("TSSI".fourCharCodeValue) {
                        print("Hotkey detected! (input)")
                        manager.inputCallback?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }
}

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