import SwiftUI

struct AudioDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    let kind: DeviceType

    private var isSelected: Bool {
        switch kind {
        case .output: audioManager.isOutputDeviceSelected(device)
        case .input: audioManager.isInputDeviceSelected(device)
        }
    }

    private var isCurrentDevice: Bool {
        switch kind {
        case .output:
            guard let current = audioManager.currentDevice else { return false }
            return liveDevice.isSameAudioEndpoint(as: current)
        case .input:
            guard let current = audioManager.currentInputDevice else { return false }
            return liveDevice.isSameAudioEndpoint(as: current)
        }
    }

    private var liveDevice: AudioDevice {
        let pool = kind == .output ? audioManager.availableDevices : audioManager.availableInputDevices
        return device.matchingDevice(in: pool) ?? device
    }

    private var isDeviceConnected: Bool {
        liveDevice.isConnected
    }

    private var statusText: String {
        if isCurrentDevice, isDeviceConnected {
            return "Active"
        }
        return isDeviceConnected ? "Connected" : "Disconnected"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                guard isDeviceConnected else { return }
                setSelected(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? SoundriftTheme.accent : Color.secondary.opacity(0.7))
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!isDeviceConnected)
            .help(isDeviceConnected ? "Include in shortcut rotation" : "Connect device to include in rotation")
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button(action: switchToThisDevice) {
                        HStack(spacing: 8) {
                            Image(systemName: liveDevice.glyphSystemName(kind: kind))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isDeviceConnected ? .primary : .secondary)
                                .frame(width: 18, height: 18)

                            Text(device.name)
                                .font(.body)
                                .foregroundStyle(isDeviceConnected ? .primary : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDeviceConnected)
                    .help(switchHelp)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                        .frame(minWidth: 72, alignment: .trailing)

                    Button(action: hideDevice) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("Hide this device from the list")
                }

                if isDeviceConnected {
                    DeviceVolumeSlider(device: liveDevice, kind: kind, style: .row)
                        .id("\(kind)-\(liveDevice.endpointID)")
                        .padding(.leading, 26)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .opacity(isDeviceConnected ? 1 : 0.55)
    }

    private var statusColor: Color {
        if isCurrentDevice, isDeviceConnected {
            return SoundriftTheme.accent
        }
        return .secondary
    }

    private var rowBackground: Color {
        if isCurrentDevice, isDeviceConnected {
            return SoundriftTheme.accent.opacity(0.12)
        }
        return .clear
    }

    private var switchHelp: String {
        if !isDeviceConnected {
            return "Connect this device to switch to it"
        }
        if isCurrentDevice {
            return kind == .output ? "Current output" : "Current input"
        }
        return kind == .output ? "Switch output to \(device.name)" : "Switch input to \(device.name)"
    }

    private func switchToThisDevice() {
        guard isDeviceConnected else { return }
        switch kind {
        case .output: audioManager.selectOutputDevice(liveDevice)
        case .input: audioManager.selectInputDevice(liveDevice)
        }
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
