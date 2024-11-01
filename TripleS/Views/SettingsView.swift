import SwiftUI

struct SettingsView: View {
    @StateObject private var audioManager = AudioManager.shared
    @AppStorage("selectedHotkey") private var hotkey = "⌘⌥S"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Devices Section
            GroupBox(label: Text("Audio Devices")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(audioManager.availableDevices) { device in
                        Toggle(isOn: binding(for: device)) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(.secondary)
                                Text(device.name)
                            }
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Hotkey Section
            GroupBox(label: Text("Hotkey")) {
                HStack {
                    TextField("Hotkey", text: $hotkey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                    
                    Button("Record") {
                        // TODO: Implement hotkey recording
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private func binding(for device: AudioDevice) -> Binding<Bool> {
        Binding(
            get: { audioManager.selectedDevices.contains(device) },
            set: { isSelected in
                if isSelected {
                    audioManager.selectedDevices.insert(device)
                } else {
                    audioManager.selectedDevices.remove(device)
                }
            }
        )
    }
} 