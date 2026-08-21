import SwiftUI
import CoreAudio

struct AudioDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    let kind: DeviceType

    @State private var volume: Float = 0
    @State private var supportsVolume = false
    @State private var supportsMute = false
    @State private var isMuted = false
    @State private var didProbeSupport = false
    @State private var volumeMonitor: DeviceVolumeMonitor?
    @State private var interaction = VolumeInteractionState()

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
        return pool.first { $0.id == device.id }
            ?? pool.first { AudioDeviceMatch.namesMatch($0.name, device.name) }
            ?? device
    }

    private var isDeviceConnected: Bool {
        liveDevice.isConnected
    }

    private var volumeScope: AudioObjectPropertyScope {
        kind == .output ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput
    }

    private var volumeIconName: String {
        if isMuted {
            return kind == .output ? "speaker.slash.fill" : "mic.slash.fill"
        }
        return kind == .output ? "speaker.wave.2.fill" : "mic.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    guard isDeviceConnected else { return }
                    setSelected(!isSelected)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? Color.cyan : .secondary)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(!isDeviceConnected)
                .help(isDeviceConnected ? "Include in shortcut rotation" : "Connect device to include in rotation")

                Button(action: switchToThisDevice) {
                    HStack(spacing: 10) {
                        deviceGlyph

                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .fontWeight(.medium)
                                .foregroundStyle(isDeviceConnected ? .primary : .secondary)
                            Text(isDeviceConnected ? "Connected" : "Disconnected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isDeviceConnected)
                .help(switchHelp)

                HStack(spacing: 4) {
                    Button(action: hideDevice) {
                        rowIcon("eye.slash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Hide this device from the list")
                }
            }

            if isDeviceConnected {
                if supportsVolume {
                    HStack(spacing: 10) {
                        Button(action: toggleMute) {
                            Image(systemName: volumeIconName)
                                .font(.system(size: 12))
                                .foregroundStyle(isMuted ? .red : .secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .disabled(!supportsMute)
                        .help(supportsMute ? (isMuted ? "Unmute" : "Mute") : "Mute not supported on this device")

                        Slider(
                            value: Binding(
                                get: { Double(volume) },
                                set: { newValue in
                                    volume = Float(newValue)
                                    if isMuted, volume > 0.001 {
                                        isMuted = false
                                        _ = device.setMute(false, scope: volumeScope)
                                    }
                                    _ = device.setVolume(volume, scope: volumeScope)
                                }
                            ),
                            in: 0...1
                        ) { editing in
                            interaction.isAdjustingVolume = editing
                            if !editing {
                                refreshVolumeFromDevice(reprobeSupport: false)
                            }
                        }
                        .opacity(isMuted ? 0.45 : 1)

                        Text("\(Int((volume * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(isMuted ? .red : .secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .help(kind == .output ? "Output volume for this device" : "Input gain for this device")
                } else {
                    Text("No volume control on this device")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .help("macOS does not expose a working volume control for this device (common for Continuity mics and some virtual devices like Teams input).")
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isCurrentDevice, isDeviceConnected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
        .opacity(isDeviceConnected ? 1 : 0.55)
        .padding(.horizontal)
        .onAppear {
            refreshVolumeFromDevice(reprobeSupport: true)
            startVolumeMonitor()
        }
        .onDisappear {
            stopVolumeMonitor()
        }
        .onChange(of: liveDevice.id) { _, _ in
            didProbeSupport = false
            refreshVolumeFromDevice(reprobeSupport: true)
            startVolumeMonitor()
        }
        .onChange(of: isDeviceConnected) { _, connected in
            didProbeSupport = false
            refreshVolumeFromDevice(reprobeSupport: true)
            if connected {
                startVolumeMonitor()
            } else {
                stopVolumeMonitor()
            }
        }
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
            return Color.primary.opacity(0.14)
        }
        return Color.primary.opacity(0.05)
    }

    @ViewBuilder
    private var deviceGlyph: some View {
        let isActive = isCurrentDevice && isDeviceConnected
        Image(systemName: liveDevice.glyphSystemName(kind: kind))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : (isDeviceConnected ? Color.primary : Color.secondary))
            .frame(width: 30, height: 30)
            .background(
                isActive ? Color(nsColor: .systemBlue) : Color.primary.opacity(isDeviceConnected ? 0.12 : 0.06),
                in: Circle()
            )
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

    private func toggleMute() {
        guard supportsMute else { return }
        let newValue = !isMuted
        if device.setMute(newValue, scope: volumeScope) {
            isMuted = newValue
        } else {
            refreshVolumeFromDevice(reprobeSupport: false)
        }
    }

    private func refreshVolumeFromDevice(reprobeSupport: Bool) {
        if reprobeSupport || !didProbeSupport {
            supportsVolume = device.hasVolumeControl(scope: volumeScope)
            supportsMute = device.hasMuteControl(scope: volumeScope)
            didProbeSupport = true
        }

        if let current = device.getVolume(scope: volumeScope) {
            volume = current
        }
        if let muted = device.getMute(scope: volumeScope) {
            isMuted = muted
        } else {
            supportsMute = false
            isMuted = false
        }
    }

    private func startVolumeMonitor() {
        stopVolumeMonitor()
        guard isDeviceConnected else { return }
        volumeMonitor = device.makeVolumeMonitor(scope: volumeScope) { [interaction] in
            guard !interaction.isAdjustingVolume else { return }
            refreshVolumeFromDevice(reprobeSupport: false)
        }
    }

    private func stopVolumeMonitor() {
        volumeMonitor?.stop()
        volumeMonitor = nil
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .frame(width: 28, height: 28)
    }
}

private final class VolumeInteractionState {
    var isAdjustingVolume = false
}

struct DeviceListHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text("Check devices for your shortcut. Click a name or icon to switch to it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
