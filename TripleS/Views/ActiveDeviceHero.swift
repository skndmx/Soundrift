import SwiftUI
import AppKit
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

            DeviceVolumeSlider(device: device, kind: kind, style: .hero)
                .id("\(kind)-\(device.id)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .soundriftHeroGlass()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), Active")
    }
}

struct ActiveStatusPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(SoundriftTheme.activeGreen, in: Capsule())
    }
}

enum DeviceVolumeControlStyle {
    case hero
    case row
}

struct DeviceVolumeSlider: View {
    let device: AudioDevice
    let kind: DeviceType
    var style: DeviceVolumeControlStyle = .hero

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
        isMuted || (supportsVolume && volume <= 0.001)
    }

    private var volumeIconName: String {
        if showsAsMuted {
            return kind == .output ? "speaker.slash.fill" : "mic.slash.fill"
        }
        return kind == .output ? "speaker.wave.2.fill" : "mic.fill"
    }

    private var volumeSlider: some View {
        AppKitVolumeSlider(
            value: Binding(
                get: { Double(volume) },
                set: { applyVolumeFromSlider(Float($0)) }
            ),
            onEditingChanged: { editing in
                interaction.isAdjustingVolume = editing
                if !editing {
                    refreshVolumeFromDevice(reprobeSupport: false)
                }
            }
        )
        .controlSize(.small)
        .tint(SoundriftTheme.accent)
        .frame(maxWidth: style == .hero ? 160 : .infinity)
        .frame(height: 16)
        .opacity(showsAsMuted ? 0.45 : 1)
    }

    private var muteButton: some View {
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

    var body: some View {
        Group {
            if liveDevice.isConnected, supportsVolume || supportsMute {
                HStack(spacing: 8) {
                    if style == .row {
                        muteButton
                    }
                    if supportsVolume {
                        volumeSlider
                    }
                    if style == .row, supportsVolume {
                        Text("\(Int((volume * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(showsAsMuted ? SoundriftTheme.recordingRed : .secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    if style == .hero {
                        muteButton
                    }
                }
                .help(kind == .output ? "Output volume for this device" : "Input gain for this device")
            } else if style == .row, liveDevice.isConnected {
                Text("No volume control on this device")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("macOS does not expose a working volume control for this device (common for Continuity mics and some virtual devices like Teams input).")
            }
        }
        .onAppear {
            refreshVolumeFromDevice(reprobeSupport: true)
            startVolumeMonitor()
        }
        .onDisappear {
            stopVolumeMonitor()
        }
        .onChange(of: kind) { _, _ in
            resetVolumeObservation()
        }
        .onChange(of: liveDevice.id) { _, _ in
            resetVolumeObservation()
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
            if !newValue, supportsVolume, volume <= 0.001 {
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

    private func resetVolumeObservation() {
        didProbeSupport = false
        refreshVolumeFromDevice(reprobeSupport: true)
        startVolumeMonitor()
    }

    private func startVolumeMonitor() {
        stopVolumeMonitor()
        guard liveDevice.isConnected else { return }
        volumeMonitor = liveDevice.makeVolumeMonitor(scope: volumeScope) { [interaction] in
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

/// AppKit slider so knob drags are not treated as window-background drags.
private struct AppKitVolumeSlider: NSViewRepresentable {
    var value: Binding<Double>
    var onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(value: value, onEditingChanged: onEditingChanged)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = WindowPinnedSlider()
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = value.wrappedValue
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.onEditingChanged = { editing in
            context.coordinator.isEditing = editing
            onEditingChanged(editing)
        }
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.value = value
        context.coordinator.onEditingChanged = onEditingChanged
        if let pinned = slider as? WindowPinnedSlider {
            pinned.onEditingChanged = { editing in
                context.coordinator.isEditing = editing
                onEditingChanged(editing)
            }
        }
        guard !context.coordinator.isEditing else { return }
        if abs(slider.doubleValue - value.wrappedValue) > 0.002 {
            slider.doubleValue = value.wrappedValue
        }
    }

    final class Coordinator: NSObject {
        var value: Binding<Double>
        var onEditingChanged: (Bool) -> Void
        var isEditing = false

        init(value: Binding<Double>, onEditingChanged: @escaping (Bool) -> Void) {
            self.value = value
            self.onEditingChanged = onEditingChanged
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

private final class WindowPinnedSlider: NSSlider {
    var onEditingChanged: ((Bool) -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        onEditingChanged?(true)
        super.mouseDown(with: event)
        onEditingChanged?(false)
    }
}
