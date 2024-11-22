import SwiftUI
import Carbon
import AppKit

struct MainView: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var isSettingsPresented = false
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = Int(modifierCmdKey | modifierShiftKey)
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = Int(kVK_UpArrow)
    @State private var isRecordingHotkey = false
    @State private var localEventMonitor: Any?
    @AppStorage("inputHotkeyModifiers") private var inputHotkeyModifiers = Int(modifierCmdKey | modifierShiftKey)
    @AppStorage("inputHotkeyKeyCode") private var inputHotkeyKeyCode = Int(kVK_DownArrow)
    @State private var isRecordingInputHotkey = false
    
    private var sortedDevices: [AudioDevice] {
        audioManager.availableDevices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private var sortedInputDevices: [AudioDevice] {
        audioManager.availableInputDevices
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private func updateDefaultHotkeyIfNeeded() {
        // Register output hotkey
        HotkeyManager.shared.register(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .output)
        }
        
        // Register input hotkey
        HotkeyManager.shared.registerInput(keyCode: inputHotkeyKeyCode, modifiers: inputHotkeyModifiers) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .input)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel
            VStack(spacing: 20) {
                Text("Soundrift")
                    .font(.largeTitle)
                    .bold()
                
                Image("AppIcon2")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("Version 1.2.8")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Created by Kevin Jin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Spacer()
                Text("How to use:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Select your audio devices from the list")
                    Text("2. Set up a keyboard shortcut below")
                    Text("3. Use the shortcut to quickly switch between devices")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            }
            .frame(width: 200)
            .padding()
            .background(Color("SettingsV1"))
            
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(1))
                .frame(width: 1)
            
            // Right Panel
            VStack(spacing: 0) {
                CustomTabView(content: [
                    (
                        title: "Output",
                        icon: "speaker.wave.3",
                        view: AnyView(
                            ScrollView {
                                VStack(spacing: 20) {
                                    if let currentDevice = audioManager.currentDevice {
                                        HStack {
                                            Image(systemName: "speaker.wave.3")
                                                .font(.title)
                                            Text("Current Output:")
                                                .font(.headline)
                                            Text(currentDevice.name)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1)))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Available Output Devices")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        ForEach(sortedDevices) { device in
                                            DeviceRow(device: device)
                                        }
                                    }
                                    
                                    VStack(spacing: 12) {
                                        Text("Quick Switch Shortcut")
                                            .font(.headline)
                                        
                                        HStack {
                                            Text(getHotkeyString())
                                                .padding(8)
                                                .frame(minWidth: 120)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.1))
                                                )
                                            
                                            Button(isRecordingHotkey ? "Press any key..." : "Record") {
                                                toggleHotkeyRecording()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                        
                                        Text("Click 'Record' and press your desired key combination")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1)))
                                }
                                .padding()
                            }
                        )
                    ),
                    (
                        title: "Input",
                        icon: "mic",
                        view: AnyView(
                            ScrollView {
                                VStack(spacing: 20) {
                                    if let currentInput = audioManager.currentInputDevice {
                                        HStack {
                                            Image(systemName: "mic")
                                                .font(.title)
                                            Text("Current Input:")
                                                .font(.headline)
                                            Text(currentInput.name)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1)))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Available Input Devices")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        ForEach(sortedInputDevices) { device in
                                            InputDeviceRow(device: device)
                                        }
                                    }
                                    
                                    VStack(spacing: 12) {
                                        Text("Input Switch Shortcut")
                                            .font(.headline)
                                        
                                        HStack {
                                            Text(getInputHotkeyString())
                                                .padding(8)
                                                .frame(minWidth: 120)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.1))
                                                )
                                            
                                            Button(isRecordingInputHotkey ? "Press any key..." : "Record") {
                                                toggleInputHotkeyRecording()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                        
                                        Text("Click 'Record' and press your desired key combination")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1)))
                                }
                                .padding()
                            }
                        )
                    ),
                    (
                        title: "Settings",
                        icon: "gear",
                        view: AnyView(
                            VStack {
                                SettingsView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding()
                            }
                        )
                    )
                ])
            }
            .background(Color("MainBackground"))
        }
        .frame(minWidth: 900, minHeight: 800)
        .onAppear {
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: hotkeyKeyCode) { _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: hotkeyModifiers) { _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: inputHotkeyKeyCode) { _ in
            updateDefaultHotkeyIfNeeded()
        }
        .onChange(of: inputHotkeyModifiers) { _ in
            updateDefaultHotkeyIfNeeded()
        }
    }
    
    private func getHotkeyString() -> String {
        var str = ""
        let flags = UInt(hotkeyModifiers)
        
        // Add modifier symbols in a consistent order
        if flags & modifierControlKey != 0 { str += "⌃" }
        if flags & modifierOptionKey != 0 { str += "⌥" }
        if flags & modifierShiftKey != 0 { str += "⇧" }
        if flags & modifierCmdKey != 0 { str += "⌘" }
        
        // Convert key code to character
        switch hotkeyKeyCode {
        case kVK_DownArrow:
            str += "↓"
        case kVK_UpArrow:
            str += "↑"
        case kVK_LeftArrow:
            str += "←"
        case kVK_RightArrow:
            str += "→"
        case kVK_Space:
            str += "Space"
        case kVK_Return:
            str += "↩"
        case kVK_Delete:
            str += "⌫"
        case kVK_Escape:
            str += "⎋"
        case kVK_Tab:
            str += "⇥"
        default:
            // Convert other keys to characters
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
            str += keyMap[hotkeyKeyCode] ?? "?"
        }
        
        return str.isEmpty ? "Click to record" : str
    }
    
    private func getInputHotkeyString() -> String {
        var str = ""
        let flags = UInt(inputHotkeyModifiers)
        
        // Add modifier symbols in a consistent order
        if flags & modifierControlKey != 0 { str += "⌃" }
        if flags & modifierOptionKey != 0 { str += "⌥" }
        if flags & modifierShiftKey != 0 { str += "⇧" }
        if flags & modifierCmdKey != 0 { str += "⌘" }
        
        // Convert key code to character
        switch inputHotkeyKeyCode {
        case kVK_DownArrow:
            str += "↓"
        case kVK_UpArrow:
            str += "↑"
        case kVK_LeftArrow:
            str += "←"
        case kVK_RightArrow:
            str += "→"
        case kVK_Space:
            str += "Space"
        case kVK_Return:
            str += "↩"
        case kVK_Delete:
            str += "⌫"
        case kVK_Escape:
            str += "⎋"
        case kVK_Tab:
            str += "⇥"
        default:
            // Convert other keys to characters
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
            str += keyMap[inputHotkeyKeyCode] ?? "?"
        }
        
        return str.isEmpty ? "Click to record" : str
    }
    
    private func toggleHotkeyRecording() {
        isRecordingHotkey.toggle()
        if isRecordingHotkey {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
                handleKeyEvent(event)
                return nil
            }
        } else {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
        }
    }
    
    private func toggleInputHotkeyRecording() {
        isRecordingInputHotkey.toggle()
        if isRecordingInputHotkey {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
                handleInputKeyEvent(event)
                return nil
            }
        } else {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if isRecordingHotkey {
            print("Recording hotkey...")
            print("Key code: \(event.keyCode)")
            print("Key: \(event.characters ?? "unknown")")
            print("Raw modifiers: \(event.modifierFlags.rawValue)")
            
            // Only allow combinations with at least one modifier
            let validModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let currentModifiers = event.modifierFlags.intersection(validModifiers)
            
            guard !currentModifiers.isEmpty else {
                print("Rejected: No modifier keys pressed")
                return
            }
            
            hotkeyModifiers = Int(currentModifiers.rawValue)
            hotkeyKeyCode = Int(event.keyCode)
            
            // Clean up the monitor
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
            isRecordingHotkey = false
            
            // Update the hotkey immediately
            DispatchQueue.main.async {
                self.updateHotkey()
            }
        }
    }
    
    private func handleInputKeyEvent(_ event: NSEvent) {
        if isRecordingInputHotkey {
            // Only allow combinations with at least one modifier
            let validModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let currentModifiers = event.modifierFlags.intersection(validModifiers)
            
            guard !currentModifiers.isEmpty else {
                print("Rejected: No modifier keys pressed")
                return
            }
            
            inputHotkeyModifiers = Int(currentModifiers.rawValue)
            inputHotkeyKeyCode = Int(event.keyCode)
            
            // Clean up the monitor
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
            isRecordingInputHotkey = false
            
            // Update the hotkey immediately
            DispatchQueue.main.async {
                self.updateInputHotkey()
            }
        }
    }
    
    private func updateHotkey() {
        HotkeyManager.shared.unregister()
        HotkeyManager.shared.register(
            keyCode: hotkeyKeyCode,
            modifiers: hotkeyModifiers
        ) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .output)
        }
    }
    
    private func updateInputHotkey() {
        HotkeyManager.shared.unregisterInput()
        HotkeyManager.shared.registerInput(
            keyCode: inputHotkeyKeyCode,
            modifiers: inputHotkeyModifiers
        ) {
            DeviceSwitchManager.shared.switchToNextDevice(type: .input)
        }
    }
}

#Preview {
    MainView()
        .frame(width: 600, height: 1200)
} 