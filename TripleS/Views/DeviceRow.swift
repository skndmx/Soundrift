import SwiftUI

struct DeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { audioManager.selectedDevices.contains(device) },
                set: { isSelected in
                    if isSelected {
                        audioManager.selectedDevices.insert(device)
                    } else {
                        audioManager.selectedDevices.remove(device)
                    }
                    UserDefaults.standard.set(
                        Array(audioManager.selectedDevices).map { $0.id },
                        forKey: "SelectedDevices"
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
            
            if device.id == audioManager.currentDevice?.id {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.05)))
        .padding(.horizontal)
    }
} 