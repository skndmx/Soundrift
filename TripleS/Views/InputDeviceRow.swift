import SwiftUI

struct InputDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: audioManager.selectedInputDevices.contains(device) ? "checkmark.square.fill" : "square")
                .foregroundColor(audioManager.selectedInputDevices.contains(device) ? Color.cyan : Color.gray)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.id == audioManager.currentInputDevice?.id {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if audioManager.selectedInputDevices.contains(device) {
                audioManager.selectedInputDevices.remove(device)
            } else {
                audioManager.selectedInputDevices.insert(device)
            }
            audioManager.saveSelectedInputDevices()
        }
        .padding(.horizontal)
    }
} 