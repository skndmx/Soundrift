import CoreAudio
import Foundation

enum AirPlayEndpoint {
    static func isGenericDeviceName(_ name: String) -> Bool {
        AudioDeviceMatch.normalizedName(name).caseInsensitiveCompare("AirPlay") == .orderedSame
    }

    /// Core Audio's AirPlay HAL device is named "AirPlay". The Apple TV / HomePod
    /// name lives on the selected data source (Control Center's "客厅").
    static func displayName(halName: String, dataSourceName: String?) -> String {
        let source = dataSourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !source.isEmpty, !isGenericDeviceName(source) else { return halName }
        return source
    }

    static func currentOutputSource(for deviceID: AudioDeviceID) -> (id: UInt32, name: String)? {
        if let sourceID = currentDataSourceID(deviceID, scope: kAudioDevicePropertyScopeOutput),
           let name = dataSourceName(deviceID, sourceID: sourceID, scope: kAudioDevicePropertyScopeOutput),
           !name.isEmpty {
            return (sourceID, name)
        }

        // Some stacks expose sources before the "current" selector is populated.
        if let sourceID = dataSourceIDs(deviceID, scope: kAudioDevicePropertyScopeOutput).first,
           let name = dataSourceName(deviceID, sourceID: sourceID, scope: kAudioDevicePropertyScopeOutput),
           !name.isEmpty {
            return (sourceID, name)
        }

        if let objectName = objectName(for: deviceID),
           !objectName.isEmpty,
           !isGenericDeviceName(objectName) {
            return (0, objectName)
        }

        return nil
    }

    @discardableResult
    static func setCurrentOutputSource(_ sourceID: UInt32, on deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var sourceID = sourceID
        return AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &sourceID
        ) == noErr
    }

    private static func currentDataSourceID(
        _ deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var sourceID: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sourceID) == noErr,
              sourceID != 0 else {
            return nil
        }
        return sourceID
    }

    private static func dataSourceIDs(
        _ deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> [UInt32] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSources,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return [] }

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size > 0 else {
            return []
        }

        let count = Int(size) / MemoryLayout<UInt32>.size
        var sourceIDs = [UInt32](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sourceIDs) == noErr else {
            return []
        }
        return sourceIDs.filter { $0 != 0 }
    }

    private static func objectName(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &cfName) == noErr,
              let unmanagedName = cfName else {
            return nil
        }
        return unmanagedName.takeRetainedValue() as String
    }

    private static func dataSourceName(
        _ deviceID: AudioDeviceID,
        sourceID: UInt32,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var sourceID = sourceID
        var cfName: Unmanaged<CFString>?
        var translation = AudioValueTranslation(
            mInputData: &sourceID,
            mInputDataSize: UInt32(MemoryLayout<UInt32>.size),
            mOutputData: &cfName,
            mOutputDataSize: UInt32(MemoryLayout<CFString>.size)
        )
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSourceNameForIDCFString,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        guard AudioObjectHasProperty(deviceID, &address),
              AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &translation) == noErr,
              let unmanagedName = cfName else {
            return nil
        }
        return unmanagedName.takeRetainedValue() as String
    }
}

enum AirPlayReceiverMatch {
    static func parseRAOPInstance(_ instance: String) -> (mac: String, name: String)? {
        guard let separator = instance.firstIndex(of: "@") else { return nil }
        let mac = normalizedMAC(String(instance[..<separator]))
        let name = String(instance[instance.index(after: separator)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mac, mac.count == 12, !name.isEmpty else { return nil }
        return (mac, name)
    }

    static func normalizedMAC(_ string: String) -> String? {
        let hex = string.uppercased().filter(\.isHexDigit)
        return hex.count == 12 ? hex : nil
    }

    static func macs(inUID uid: String) -> [String] {
        var found: [String] = []
        let nsUID = uid as NSString
        if let regex = try? NSRegularExpression(pattern: #"(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}"#) {
            for match in regex.matches(in: uid, range: NSRange(location: 0, length: nsUID.length)) {
                if let mac = normalizedMAC(nsUID.substring(with: match.range)) {
                    found.append(mac)
                }
            }
        }
        if let compact = normalizedMAC(uid.filter(\.isHexDigit)), uid.filter(\.isHexDigit).count == 12 {
            found.append(compact)
        }
        if let raop = parseRAOPInstance(uid) {
            found.append(raop.mac)
        }
        var unique: [String] = []
        for mac in found where !unique.contains(mac) {
            unique.append(mac)
        }
        return unique
    }

    static func isLocalComputerName(_ name: String, localNames: [String]) -> Bool {
        localNames.contains { AudioDeviceMatch.namesMatch($0, name) }
    }

    static func resolvedName(
        halName: String,
        uid: String,
        dataSourceName: String?,
        namesByMAC: [String: String],
        remoteReceiverNames: [String],
        lastKnownName: String?
    ) -> String {
        let fromSource = AirPlayEndpoint.displayName(halName: halName, dataSourceName: dataSourceName)
        if !AirPlayEndpoint.isGenericDeviceName(fromSource) {
            return fromSource
        }

        for mac in macs(inUID: uid) {
            if let name = namesByMAC[mac], !name.isEmpty {
                return name
            }
        }

        if remoteReceiverNames.count == 1, let only = remoteReceiverNames.first {
            return only
        }

        if let lastKnownName, !lastKnownName.isEmpty {
            if remoteReceiverNames.isEmpty
                || remoteReceiverNames.contains(where: { AudioDeviceMatch.namesMatch($0, lastKnownName) }) {
                return lastKnownName
            }
        }

        return halName
    }
}
