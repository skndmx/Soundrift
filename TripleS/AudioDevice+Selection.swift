import CoreAudio
import Foundation

enum AudioDeviceMatch {
    static func normalizedName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizedName(lhs).caseInsensitiveCompare(normalizedName(rhs)) == .orderedSame
    }

    /// Bluetooth HFP/HSP endpoints share a name with the stereo device on some stacks,
    /// or are labeled Hands-Free / Headset. Those are the wrong default *output*.
    static func isHandsFreeProfile(name: String) -> Bool {
        let n = normalizedName(name).lowercased()
        return n.contains("hands-free")
            || n.contains("handsfree")
            || n.contains("headset")
    }

    static func outputRank(
        name: String,
        canBeDefault: Bool,
        outputChannels: Int,
        sampleRate: Double
    ) -> Int {
        var rank = 0
        if canBeDefault { rank += 1_000 }
        if !isHandsFreeProfile(name: name) { rank += 400 }
        rank += min(max(outputChannels, 0), 16) * 10
        if sampleRate >= 44_100 { rank += 200 }
        else if sampleRate >= 16_000 { rank += 20 }
        return rank
    }

    static func inputRank(
        name: String,
        canBeDefault: Bool,
        inputChannels: Int
    ) -> Int {
        var rank = 0
        if canBeDefault { rank += 1_000 }
        rank += min(max(inputChannels, 0), 16) * 10
        // Hands-Free is the mic endpoint for many Bluetooth headsets.
        if isHandsFreeProfile(name: name) { rank += 50 }
        return rank
    }
}

enum AudioDeviceAvailability {
    /// Bluetooth headsets (AirPods) often remain in the HAL list after they go
    /// in the case. `IsAlive` stays true, but they can no longer be the default.
    static func isConnected(
        isAlive: Bool,
        isBluetooth: Bool,
        jackUnplugged: Bool,
        canBeDefaultOutput: Bool?,
        canBeDefaultInput: Bool?,
        isOutput: Bool,
        isInput: Bool
    ) -> Bool {
        guard isAlive, !jackUnplugged else { return false }
        guard isBluetooth else { return true }

        let outputUsable = isOutput && canBeDefaultOutput != false
        let inputUsable = isInput && canBeDefaultInput != false
        return outputUsable || inputUsable
    }
}

extension AudioDevice {
    func isSameAudioEndpoint(as other: AudioDevice) -> Bool {
        // One HAL "AirPlay" device can host several endpoints (客厅 vs another Apple TV).
        if isAirPlay || other.isAirPlay {
            return AudioDeviceMatch.namesMatch(name, other.name)
        }
        if !uid.isEmpty, !other.uid.isEmpty, uid == other.uid {
            return true
        }
        return AudioDeviceMatch.namesMatch(name, other.name)
    }

    /// Live HAL object for this logical device. Bluetooth headsets often appear twice
    /// (A2DP stereo vs HFP hands-free) under the same name — pick the one that matches `kind`.
    func resolvedLiveDevice(kind: DeviceType? = nil) -> AudioDevice? {
        let live = AudioDevice.getAllDevices().filter(\.isConnected)
        let matches = live.filter { isSameAudioEndpoint(as: $0) }

        if let kind, let preferred = AudioDevice.preferredLiveDevice(from: matches, kind: kind) {
            return preferred
        }
        if !uid.isEmpty, let uidMatch = matches.first(where: { $0.uid == uid }) {
            return uidMatch
        }
        return matches.first { $0.id == id } ?? matches.first
    }

    static func preferredLiveDevice(from devices: [AudioDevice], kind: DeviceType) -> AudioDevice? {
        let eligible = devices.filter { device in
            guard device.isConnected else { return false }
            switch kind {
            case .output: return device.isOutput
            case .input: return device.isInput
            }
        }
        return eligible.max { lhs, rhs in
            lhs.selectionRank(kind: kind) < rhs.selectionRank(kind: kind)
        }
    }

    static func uniquePreferredDevices(_ devices: [AudioDevice], kind: DeviceType) -> [AudioDevice] {
        var grouped: [String: [AudioDevice]] = [:]
        for device in devices {
            grouped[AudioDeviceMatch.normalizedName(device.name).lowercased(), default: []].append(device)
        }
        return grouped.values.compactMap { preferredLiveDevice(from: $0, kind: kind) }
    }

    func selectionRank(kind: DeviceType) -> Int {
        switch kind {
        case .output:
            return AudioDeviceMatch.outputRank(
                name: name,
                canBeDefault: canBeSystemDefault(scope: kAudioDevicePropertyScopeOutput),
                outputChannels: channelCount(scope: kAudioDevicePropertyScopeOutput),
                sampleRate: nominalSampleRate()
            )
        case .input:
            return AudioDeviceMatch.inputRank(
                name: name,
                canBeDefault: canBeSystemDefault(scope: kAudioDevicePropertyScopeInput),
                inputChannels: channelCount(scope: kAudioDevicePropertyScopeInput)
            )
        }
    }

    /// Core Audio often returns success before Bluetooth A2DP has actually become default.
    @discardableResult
    func setAsDefaultOutputAndWait() -> Bool {
        let timeout: TimeInterval = isBluetoothTransport ? 1.0 : 0.4
        let deadline = Date().addingTimeInterval(timeout)
        var delay: TimeInterval = 0

        while Date() < deadline {
            if delay > 0 {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(delay))
            }

            let target = resolvedLiveDevice(kind: .output) ?? self
            guard target.isConnected else {
                delay = delay == 0 ? 0.08 : min(delay * 1.5, 0.2)
                continue
            }

            if target.setAsDefault(),
               let actual = AudioDevice.getCurrentDefault(),
               target.isSameAudioEndpoint(as: actual) {
                return true
            }

            delay = delay == 0 ? 0.08 : min(delay * 1.5, 0.2)
        }

        if let actual = AudioDevice.getCurrentDefault() {
            return isSameAudioEndpoint(as: actual)
        }
        return false
    }
}
