import SwiftUI

struct InputDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { audioManager.selectedInputDevices.contains(device) },
                set: { isSelected in
                    if isSelected {
                        audioManager.selectedInputDevices.insert(device)
                    } else {
                        audioManager.selectedInputDevices.remove(device)
                    }
                    UserDefaults.standard.set(
                        Array(audioManager.selectedInputDevices).map { $0.id },
                        forKey: "SelectedInputDevices"
                    )
                }
            )) {
                HStack {
                    Image(systemName: device.isConnected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(device.isConnected ? .green : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .fontWeight(.medium)
                        Text(device.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if device.id == audioManager.currentInputDevice?.id {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.05)))
        .padding(.horizontal)
    }
} 