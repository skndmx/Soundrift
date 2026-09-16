import CoreAudio
import Foundation

/// Snapshot of the menu-bar switcher. Built when the menu opens so SwiftUI
/// never observes `AudioManager` (that rebuilds `MenuBarExtra` and eats clicks).
enum SoundriftMenuBarModel {
    struct DeviceRow: Equatable {
        let device: AudioDevice
        let title: String
        let isCurrent: Bool
        let isEnabled: Bool
        let symbolName: String
    }

    static func connectedFirst(_ devices: [AudioDevice]) -> [AudioDevice] {
        devices.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected && !rhs.isConnected
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func deviceRows(
        devices: [AudioDevice],
        current: AudioDevice?,
        kind: DeviceType,
        isEnabled: (AudioDevice) -> Bool
    ) -> [DeviceRow] {
        connectedFirst(devices).map { device in
            DeviceRow(
                device: device,
                title: device.name,
                isCurrent: current.map { device.isSameAudioEndpoint(as: $0) } ?? false,
                isEnabled: isEnabled(device),
                symbolName: device.glyphSystemName(kind: kind)
            )
        }
    }

    static func isDeviceSwitchable(_ device: AudioDevice, kind: DeviceType) -> Bool {
        guard device.isConnected, device.id != 0 else { return false }
        let scope: AudioObjectPropertyScope = kind == .output
            ? kAudioDevicePropertyScopeOutput
            : kAudioDevicePropertyScopeInput
        return device.canBeSystemDefault(scope: scope)
    }
}
