import AudioToolbox
import CoreAudio
import Foundation

extension AudioDevice {
    /// Whether this connected device exposes a volume that actually changes when set.
    /// Some virtual devices (e.g. Teams input) advertise volume properties that ignore writes.
    func hasVolumeControl(scope: AudioObjectPropertyScope) -> Bool {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return false }
        guard target.getVolume(scope: scope) != nil else { return false }

        let settable = target.volumePropertyCandidates(scope: scope).contains {
            target.isPropertySettable(
                selector: $0.selector,
                scope: $0.scope,
                element: $0.element
            )
        }
        guard settable else { return false }

        return target.volumeWritesStick(scope: scope)
    }

    /// Device volume in 0...1, or nil if unavailable.
    func getVolume(scope: AudioObjectPropertyScope) -> Float? {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return nil }

        for candidate in target.volumePropertyCandidates(scope: scope) {
            if let value = target.getFloat32(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) {
                return clampVolume(value)
            }
        }
        return nil
    }

    @discardableResult
    func setVolume(_ value: Float, scope: AudioObjectPropertyScope) -> Bool {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return false }
        let volume = clampVolume(value)

        var didSet = false

        for candidate in target.volumePropertyCandidates(scope: scope) {
            let canTry = target.isPropertySettable(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) || target.hasProperty(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            )
            guard canTry else { continue }

            if target.setFloat32(
                volume,
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) {
                didSet = true
            }
        }

        guard didSet else { return false }

        // Reject fake drivers that accept writes but never change the value (Teams input).
        if let readback = target.getVolume(scope: scope) {
            return abs(readback - volume) < 0.05
        }
        return false
    }

    func hasMuteControl(scope: AudioObjectPropertyScope) -> Bool {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return false }
        return target.mutePropertyCandidates(scope: scope).contains {
            target.isPropertySettable(
                selector: $0.selector,
                scope: $0.scope,
                element: $0.element
            )
        }
    }

    func getMute(scope: AudioObjectPropertyScope) -> Bool? {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return nil }
        for candidate in target.mutePropertyCandidates(scope: scope) {
            if let value = target.getUInt32(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) {
                return value != 0
            }
        }
        return nil
    }

    @discardableResult
    func setMute(_ muted: Bool, scope: AudioObjectPropertyScope) -> Bool {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return false }
        let value: UInt32 = muted ? 1 : 0
        var didSet = false
        for candidate in target.mutePropertyCandidates(scope: scope) {
            if target.isPropertySettable(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) || target.hasProperty(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) {
                if target.setUInt32(
                    value,
                    selector: candidate.selector,
                    scope: candidate.scope,
                    element: candidate.element
                ) {
                    didSet = true
                }
            }
        }
        return didSet
    }

    /// Observes volume/mute changes from System Settings or other apps.
    func makeVolumeMonitor(
        scope: AudioObjectPropertyScope,
        onChange: @escaping () -> Void
    ) -> DeviceVolumeMonitor? {
        let target = resolvedLiveDevice(kind: kind(for: scope)) ?? self
        guard target.isConnected else { return nil }
        return DeviceVolumeMonitor(deviceID: target.id, scope: scope, onChange: onChange)
    }

    private func kind(for scope: AudioObjectPropertyScope) -> DeviceType {
        scope == kAudioDevicePropertyScopeInput ? .input : .output
    }

    private struct VolumeProperty {
        let selector: AudioObjectPropertySelector
        let scope: AudioObjectPropertyScope
        let element: AudioObjectPropertyElement
    }

    private func volumePropertyCandidates(scope: AudioObjectPropertyScope) -> [VolumeProperty] {
        var candidates: [VolumeProperty] = [
            .init(
                selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                scope: scope,
                element: kAudioObjectPropertyElementMain
            ),
            .init(
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope,
                element: kAudioObjectPropertyElementMain
            )
        ]

        for element in volumeChannelElements(scope: scope) {
            candidates.append(
                .init(
                    selector: kAudioDevicePropertyVolumeScalar,
                    scope: scope,
                    element: element
                )
            )
        }

        return candidates
    }

    private func mutePropertyCandidates(scope: AudioObjectPropertyScope) -> [VolumeProperty] {
        var candidates: [VolumeProperty] = [
            .init(
                selector: kAudioDevicePropertyMute,
                scope: scope,
                element: kAudioObjectPropertyElementMain
            )
        ]
        for element in volumeChannelElements(scope: scope) {
            candidates.append(
                .init(
                    selector: kAudioDevicePropertyMute,
                    scope: scope,
                    element: element
                )
            )
        }
        return candidates
    }

    /// Micro-probe: nudge volume and restore. Returns false if the driver ignores writes.
    private func volumeWritesStick(scope: AudioObjectPropertyScope) -> Bool {
        guard let current = getVolume(scope: scope) else { return false }
        let probe = current > 0.5 ? max(0, current - 0.1) : min(1, current + 0.1)
        defer { _ = setVolumeWithoutReadbackCheck(current, scope: scope) }

        guard setVolumeWithoutReadbackCheck(probe, scope: scope) else { return false }
        guard let after = getVolume(scope: scope) else { return false }
        // Require the value to actually move toward the probe (Teams input stays pinned).
        return abs(after - probe) < 0.05 && abs(after - current) > 0.02
    }

    @discardableResult
    private func setVolumeWithoutReadbackCheck(_ value: Float, scope: AudioObjectPropertyScope) -> Bool {
        let volume = clampVolume(value)
        var didSet = false
        for candidate in volumePropertyCandidates(scope: scope) {
            if isPropertySettable(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) || hasProperty(
                selector: candidate.selector,
                scope: candidate.scope,
                element: candidate.element
            ) {
                if setFloat32(
                    volume,
                    selector: candidate.selector,
                    scope: candidate.scope,
                    element: candidate.element
                ) {
                    didSet = true
                }
            }
        }
        return didSet
    }

    // MARK: - Private helpers

    private func clampVolume(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func volumeChannelElements(scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &propSize) == noErr,
              propSize > 0,
              let raw = malloc(Int(propSize)) else {
            return []
        }
        defer { free(raw) }

        let bufferList = raw.assumingMemoryBound(to: AudioBufferList.self)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &propSize, bufferList) == noErr else {
            return []
        }

        let channelCount = UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
        guard channelCount > 0 else { return [] }

        return (1...channelCount).map { AudioObjectPropertyElement($0) }
    }

    private func hasProperty(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        return AudioObjectHasProperty(id, &address)
    }

    private func isPropertySettable(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(id, &address) else { return false }

        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr else { return false }
        return settable.boolValue
    }

    private func getFloat32(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(id, &address) else { return nil }

        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func setFloat32(
        _ value: Float,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var mutableValue = Float32(value)
        return AudioObjectSetPropertyData(
            id,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &mutableValue
        ) == noErr
    }

    private func getUInt32(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(id, &address) else { return nil }

        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func setUInt32(
        _ value: UInt32,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var mutableValue = value
        return AudioObjectSetPropertyData(
            id,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &mutableValue
        ) == noErr
    }
}

/// Listens for external volume/mute changes on a single Core Audio device.
final class DeviceVolumeMonitor {
    private let deviceID: AudioDeviceID
    private let onChange: () -> Void
    private var listenedAddresses: [AudioObjectPropertyAddress] = []
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    init(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, onChange: @escaping () -> Void) {
        self.deviceID = deviceID
        self.onChange = onChange

        let block: AudioObjectPropertyListenerBlock = { _, _ in
            DispatchQueue.main.async {
                onChange()
            }
        }
        self.listenerBlock = block

        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            kAudioDevicePropertyVolumeScalar,
            kAudioDevicePropertyMute
        ]

        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let status = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &address,
                DispatchQueue.main,
                block
            )
            if status == noErr {
                listenedAddresses.append(address)
            }
        }
    }

    func stop() {
        guard let listenerBlock else { return }
        for index in listenedAddresses.indices {
            AudioObjectRemovePropertyListenerBlock(
                deviceID,
                &listenedAddresses[index],
                DispatchQueue.main,
                listenerBlock
            )
        }
        listenedAddresses.removeAll()
        self.listenerBlock = nil
    }

    deinit {
        stop()
    }
}
