import Carbon
import Cocoa

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var inputHotKeyRef: EventHotKeyRef?
    private var muteHotKeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?
    private var inputCallback: (() -> Void)?
    private var muteCallback: (() -> Void)?

    private let outputSignature = OSType("TSSO".fourCharCodeValue)
    private let inputSignature = OSType("TSSI".fourCharCodeValue)
    private let muteSignature = OSType("TSSM".fourCharCodeValue)

    private init() {}

    func register(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Output Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")

        unregister()
        self.callback = callback
        setupEventHandler()

        let status = registerHotKey(
            keyCode: keyCode,
            modifiers: modifiers,
            signature: outputSignature,
            id: 1,
            slot: &hotKeyRef
        )
        print("Output hotkey registration status: \(status)")
    }

    func registerInput(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Input Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")

        unregisterInput()
        self.inputCallback = callback

        let status = registerHotKey(
            keyCode: keyCode,
            modifiers: modifiers,
            signature: inputSignature,
            id: 2,
            slot: &inputHotKeyRef
        )
        print("Input hotkey registration status: \(status)")
    }

    func registerMute(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        print("=== Registering Mute Hotkey ===")
        print("KeyCode: \(keyCode)")
        print("Raw Modifiers: \(modifiers)")

        unregisterMute()
        self.muteCallback = callback
        setupEventHandler()

        let status = registerHotKey(
            keyCode: keyCode,
            modifiers: modifiers,
            signature: muteSignature,
            id: 3,
            slot: &muteHotKeyRef
        )
        print("Mute hotkey registration status: \(status)")
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func unregisterInput() {
        if let inputHotKeyRef {
            UnregisterEventHotKey(inputHotKeyRef)
            self.inputHotKeyRef = nil
        }
    }

    func unregisterMute() {
        if let muteHotKeyRef {
            UnregisterEventHotKey(muteHotKeyRef)
            self.muteHotKeyRef = nil
        }
    }

    func unregisterAll() {
        unregister()
        unregisterInput()
        unregisterMute()
    }

    private func carbonModifiers(from modifiers: Int) -> UInt32 {
        var carbonModifiers = 0
        if modifiers & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { carbonModifiers |= cmdKey }
        if modifiers & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { carbonModifiers |= controlKey }
        if modifiers & Int(NSEvent.ModifierFlags.option.rawValue) != 0 { carbonModifiers |= optionKey }
        if modifiers & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbonModifiers |= shiftKey }
        print("Carbon Modifiers: \(carbonModifiers)")
        return UInt32(carbonModifiers)
    }

    private func registerHotKey(
        keyCode: Int,
        modifiers: Int,
        signature: OSType,
        id: UInt32,
        slot: inout EventHotKeyRef?
    ) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        return RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers(from: modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &slot
        )
    }

    private func setupEventHandler() {
        guard eventHandler == nil else { return }

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
                    if hotKeyID.signature == manager.outputSignature {
                        print("Hotkey detected! (output)")
                        manager.callback?()
                    } else if hotKeyID.signature == manager.inputSignature {
                        print("Hotkey detected! (input)")
                        manager.inputCallback?()
                    } else if hotKeyID.signature == manager.muteSignature {
                        print("Hotkey detected! (mute)")
                        manager.muteCallback?()
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
