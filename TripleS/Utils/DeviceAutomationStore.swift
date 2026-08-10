import Foundation

enum DeviceAutomationStore {
    private static let autoSwitchOutputKey = "AutoSwitchOutputDeviceNames"
    private static let autoSwitchInputKey = "AutoSwitchInputDeviceNames"
    private static let autoReconnectKey = "AutoReconnectBluetoothDeviceNames"
    static let bluetoothReconnectIntervalKey = "BluetoothReconnectIntervalSeconds"

    static let defaultBluetoothReconnectInterval: TimeInterval = 8
    static let minBluetoothReconnectInterval: TimeInterval = 3
    static let maxBluetoothReconnectInterval: TimeInterval = 60

    static let bluetoothReconnectIntervalOptions: [TimeInterval] = [3, 5, 8, 15, 30]

    static func loadAutoSwitchOutputNames() -> Set<String> {
        loadNames(from: autoSwitchOutputKey)
    }

    static func loadAutoSwitchInputNames() -> Set<String> {
        loadNames(from: autoSwitchInputKey)
    }

    static func loadAutoReconnectNames() -> Set<String> {
        loadNames(from: autoReconnectKey)
    }

    static func saveAutoSwitchOutputNames(_ names: Set<String>) {
        saveNames(names, to: autoSwitchOutputKey)
    }

    static func saveAutoSwitchInputNames(_ names: Set<String>) {
        saveNames(names, to: autoSwitchInputKey)
    }

    static func saveAutoReconnectNames(_ names: Set<String>) {
        saveNames(names, to: autoReconnectKey)
    }

    static func loadBluetoothReconnectInterval() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: bluetoothReconnectIntervalKey)
        guard stored > 0 else { return defaultBluetoothReconnectInterval }
        return min(max(stored, minBluetoothReconnectInterval), maxBluetoothReconnectInterval)
    }

    static func saveBluetoothReconnectInterval(_ interval: TimeInterval) {
        let clamped = min(max(interval, minBluetoothReconnectInterval), maxBluetoothReconnectInterval)
        UserDefaults.standard.set(clamped, forKey: bluetoothReconnectIntervalKey)
    }

    private static func loadNames(from key: String) -> Set<String> {
        guard let names = UserDefaults.standard.array(forKey: key) as? [String] else {
            return []
        }
        return Set(names)
    }

    private static func saveNames(_ names: Set<String>, to key: String) {
        UserDefaults.standard.set(Array(names).sorted(), forKey: key)
    }
}
