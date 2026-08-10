import SwiftUI

struct InputDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice

    private var isSelected: Bool {
        audioManager.isInputDeviceSelected(device)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(isSelected ? Color.cyan : .secondary)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if device.isConnected,
               device.id == audioManager.currentInputDevice?.id || device.name == audioManager.currentInputDevice?.name {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .opacity(device.isConnected ? 1 : 0.45)
        .allowsHitTesting(device.isConnected)
        .onTapGesture {
            audioManager.setInputDeviceSelected(device, selected: !isSelected)
        }
        .contextMenu {
            Button("Hide Device") {
                audioManager.hideInputDevice(device)
            }
        }
        .padding(.horizontal)
    }
}
