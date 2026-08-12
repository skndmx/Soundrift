import Foundation

enum DeviceAutomationStore {
    private static let autoSwitchOutputKey = "AutoSwitchOutputDeviceNames"
    private static let autoSwitchInputKey = "AutoSwitchInputDeviceNames"

    static func loadAutoSwitchOutputNames() -> Set<String> {
        loadNames(from: autoSwitchOutputKey)
    }

    static func loadAutoSwitchInputNames() -> Set<String> {
        loadNames(from: autoSwitchInputKey)
    }

    static func saveAutoSwitchOutputNames(_ names: Set<String>) {
        saveNames(names, to: autoSwitchOutputKey)
    }

    static func saveAutoSwitchInputNames(_ names: Set<String>) {
        saveNames(names, to: autoSwitchInputKey)
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
