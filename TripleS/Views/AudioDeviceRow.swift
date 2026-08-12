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
            device.id == audioManager.currentDevice?.id || device.name == audioManager.currentDevice?.name
        case .input:
            device.id == audioManager.currentInputDevice?.id || device.name == audioManager.currentInputDevice?.name
        }
    }

    private var autoSwitchLabel: String {
        kind == .output ? "Auto-switch output when connected" : "Auto-switch input when connected"
    }

    private var hasAutoSwitchEnabled: Bool {
        audioManager.isAutoSwitchOnConnectEnabled(device, kind: kind)
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
                    HStack(spacing: 8) {
                        Text(device.isConnected ? "Connected" : "Disconnected")
                        if hasAutoSwitchEnabled {
                            Label("Auto-switch", systemImage: "arrow.triangle.swap")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    if device.isConnected, isCurrentDevice {
                        rowIcon(kind == .output ? "speaker.wave.3.fill" : "mic.fill")
                            .foregroundStyle(.blue)
                            .help("Currently active")
                    } else {
                        Color.clear
                            .frame(width: 28, height: 28)
                    }

                    AutomationOptionsButton(
                        autoSwitchLabel: autoSwitchLabel,
                        autoSwitchBinding: autoSwitchBinding,
                        isActive: hasAutoSwitchEnabled
                    )

                    Button(action: hideDevice) {
                        rowIcon("eye.slash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Hide this device from the list")
                }
            }

            if device.isConnected {
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
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .opacity(device.isConnected ? 1 : 0.55)
        .padding(.horizontal)
        .onAppear {
            refreshVolumeFromDevice(reprobeSupport: true)
            startVolumeMonitor()
        }
        .onDisappear {
            stopVolumeMonitor()
        }
        .onChange(of: device.id) { _, _ in
            didProbeSupport = false
            refreshVolumeFromDevice(reprobeSupport: true)
            startVolumeMonitor()
        }
        .onChange(of: device.isConnected) { _, connected in
            didProbeSupport = false
            refreshVolumeFromDevice(reprobeSupport: true)
            if connected {
                startVolumeMonitor()
            } else {
                stopVolumeMonitor()
            }
        }
    }

    private var autoSwitchBinding: Binding<Bool> {
        Binding(
            get: { audioManager.isAutoSwitchOnConnectEnabled(device, kind: kind) },
            set: { audioManager.setAutoSwitchOnConnect(device, kind: kind, enabled: $0) }
        )
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
        guard device.isConnected else { return }
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

private struct AutomationOptionsButton: View {
    let autoSwitchLabel: String
    let autoSwitchBinding: Binding<Bool>
    let isActive: Bool

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "bolt.circle")
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? .cyan : .secondary)
        }
        .buttonStyle(.plain)
        .help("Auto-switch when connected")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("When this device connects")
                    .font(.headline)

                Toggle(autoSwitchLabel, isOn: autoSwitchBinding)
            }
            .padding(16)
            .frame(width: 280)
        }
    }
}

struct DeviceListHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text("Check devices for your shortcut. Use the bolt icon for auto-switch when a device connects.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
