import SwiftUI
import CoreAudio

struct ActiveDeviceHero: View {
    let device: AudioDevice
    let kind: DeviceType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.glyphSystemName(kind: kind))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)

            Text(device.name)
                .font(.body.weight(.semibold))
                .lineLimit(1)

            ActiveStatusPill()

            Spacer(minLength: 12)

            DeviceVolumeSlider(device: device, kind: kind)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SoundriftTheme.accent.opacity(0.14))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(SoundriftTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), Active")
    }
}

struct ActiveStatusPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(SoundriftTheme.activeGreen)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SoundriftTheme.activeGreen)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(SoundriftTheme.activeGreen.opacity(0.16), in: Capsule())
    }
}

struct DeviceVolumeSlider: View {
    let device: AudioDevice
    let kind: DeviceType

    @State private var volume: Float = 0
    @State private var supportsVolume = false
    @State private var supportsMute = false
    @State private var isMuted = false
    @State private var didProbeSupport = false
    @State private var volumeMonitor: DeviceVolumeMonitor?
    @State private var interaction = VolumeInteractionState()

    private var liveDevice: AudioDevice {
        let pool = kind == .output
            ? AudioManager.shared.availableDevices
            : AudioManager.shared.availableInputDevices
        return pool.first { $0.id == device.id }
            ?? pool.first { AudioDeviceMatch.namesMatch($0.name, device.name) }
            ?? device
    }

    private var volumeScope: AudioObjectPropertyScope {
        kind == .output ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput
    }

    private var showsAsMuted: Bool {
        isMuted || volume <= 0.001
    }

    private var volumeIconName: String {
        if showsAsMuted {
            return kind == .output ? "speaker.slash.fill" : "mic.slash.fill"
        }
        return kind == .output ? "speaker.wave.2.fill" : "mic.fill"
    }

    var body: some View {
        Group {
            if liveDevice.isConnected, supportsVolume {
                HStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(volume) },
                            set: { applyVolumeFromSlider(Float($0)) }
                        ),
                        in: 0...1
                    ) { editing in
                        interaction.isAdjustingVolume = editing
                        if !editing {
                            refreshVolumeFromDevice(reprobeSupport: false)
                        }
                    }
                    .controlSize(.small)
                    .tint(SoundriftTheme.accent)
                    .frame(maxWidth: 160)
                    .opacity(showsAsMuted ? 0.45 : 1)

                    Button(action: toggleMute) {
                        Image(systemName: volumeIconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(showsAsMuted ? SoundriftTheme.recordingRed : .secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .disabled(!supportsMute)
                    .help(supportsMute ? (showsAsMuted ? "Unmute" : "Mute") : "Mute not supported on this device")
                }
                .help(kind == .output ? "Output volume for this device" : "Input gain for this device")
            }
        }
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
        .onChange(of: liveDevice.isConnected) { _, connected in
            didProbeSupport = false
            refreshVolumeFromDevice(reprobeSupport: true)
            if connected {
                startVolumeMonitor()
            } else {
                stopVolumeMonitor()
            }
        }
    }

    private func applyVolumeFromSlider(_ newValue: Float) {
        volume = max(0, min(1, newValue))
        if volume <= 0.001 {
            volume = 0
            if supportsMute, !isMuted {
                isMuted = true
                _ = device.setMute(true, scope: volumeScope)
            }
        } else if isMuted {
            isMuted = false
            _ = device.setMute(false, scope: volumeScope)
        }
        _ = device.setVolume(volume, scope: volumeScope)
    }

    private func toggleMute() {
        guard supportsMute else { return }
        let newValue = !showsAsMuted
        if device.setMute(newValue, scope: volumeScope) {
            isMuted = newValue
            if !newValue, volume <= 0.001 {
                volume = 0.1
                _ = device.setVolume(volume, scope: volumeScope)
            }
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
        guard liveDevice.isConnected else { return }
        volumeMonitor = device.makeVolumeMonitor(scope: volumeScope) { [interaction] in
            guard !interaction.isAdjustingVolume else { return }
            refreshVolumeFromDevice(reprobeSupport: false)
        }
    }

    private func stopVolumeMonitor() {
        volumeMonitor?.stop()
        volumeMonitor = nil
    }
}

final class VolumeInteractionState {
    var isAdjustingVolume = false
}
