import SwiftUI
import CoreAudio

struct DeviceVolumeSlider: View {
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

    private var liveDevice: AudioDevice {
        audioManager.liveDevice(for: device, kind: kind)
    }

    private var isDeviceConnected: Bool {
        liveDevice.isConnected
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
            if isDeviceConnected, supportsVolume {
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
                    .opacity(showsAsMuted ? 0.45 : 1)
                    .tint(SoundriftTheme.accent)

                    Button(action: toggleMute) {
                        Image(systemName: volumeIconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(showsAsMuted ? .red : .secondary)
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
}

final class VolumeInteractionState {
    var isAdjustingVolume = false
}
