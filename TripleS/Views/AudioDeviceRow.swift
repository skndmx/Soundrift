import SwiftUI

enum DeviceListKind {
    case output
    case input
}

struct AudioDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    let kind: DeviceListKind

    private var isSelected: Bool {
        switch kind {
        case .output: audioManager.isOutputDeviceSelected(device)
        case .input: audioManager.isInputDeviceSelected(device)
        }
    }

    private var isCurrentDevice: Bool {
        switch kind {
        case .output:
            device.id == audioManager.currentDevice?.id || device.name == audioManager.currentDevice?.name
        case .input:
            device.id == audioManager.currentInputDevice?.id || device.name == audioManager.currentInputDevice?.name
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                guard device.isConnected else { return }
                setSelected(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.cyan : .secondary)
                    .font(.system(size: 16))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!device.isConnected)
            .help(device.isConnected ? "Include in shortcut rotation" : "Connect device to include in rotation")

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                    .foregroundStyle(device.isConnected ? .primary : .secondary)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if device.isConnected, isCurrentDevice {
                Image(systemName: kind == .output ? "speaker.wave.3.fill" : "mic.fill")
                    .foregroundStyle(.blue)
                    .help("Currently active")
            }

            Button {
                hideDevice()
            } label: {
                Label("Hide", systemImage: "eye.slash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Hide this device from the list")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .opacity(device.isConnected ? 1 : 0.55)
        .padding(.horizontal)
    }

    private func setSelected(_ selected: Bool) {
        switch kind {
        case .output: audioManager.setOutputDeviceSelected(device, selected: selected)
        case .input: audioManager.setInputDeviceSelected(device, selected: selected)
        }
    }

    private func hideDevice() {
        switch kind {
        case .output: audioManager.hideOutputDevice(device)
        case .input: audioManager.hideInputDevice(device)
        }
    }
}

struct DeviceListHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text("Check devices to include in your shortcut. Tap the eye icon to hide ones you don't need.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
