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
        audioManager.liveDevice(for: device, kind: kind)
    }

    private var isDeviceConnected: Bool {
        liveDevice.isConnected
    }

    private var statusText: String {
        if isCurrentDevice, isDeviceConnected { return "Active" }
        return isDeviceConnected ? "Connected" : "Disconnected"
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { setSelected($0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .fixedSize()
            .disabled(!isDeviceConnected)
            .help(isDeviceConnected ? "Include in shortcut rotation" : "Connect device to include in rotation")
            .accessibilityLabel("Include in shortcut rotation")

            Button(action: switchToThisDevice) {
                HStack(spacing: 10) {
                    Image(systemName: liveDevice.glyphSystemName(kind: kind))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 20)

                    Text(device.name)
                        .font(.body)
                        .foregroundStyle(isDeviceConnected ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isDeviceConnected)
            .help(switchHelp)

            if isCurrentDevice, isDeviceConnected {
                Image(systemName: kind == .output ? "speaker.wave.2.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoundriftTheme.accent)
                    .frame(width: 18)
            }

            Button(action: hideDevice) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Hide this device from the list")
        }
        .padding(.horizontal, 12)
        .frame(height: SoundriftTheme.rowHeight)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(isDeviceConnected ? 1 : 0.55)
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

    private var rowBackground: Color {
        if isCurrentDevice, isDeviceConnected {
            return SoundriftTheme.activeRowFill
        }
        return SoundriftTheme.rowFill
    }

    private var iconColor: Color {
        if isCurrentDevice, isDeviceConnected { return SoundriftTheme.accent }
        return isDeviceConnected ? .primary : .secondary
    }

    private var statusColor: Color {
        if isCurrentDevice, isDeviceConnected { return SoundriftTheme.accent }
        return .secondary
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
