import Foundation
import IOBluetooth

final class BluetoothReconnectManager {
    static let shared = BluetoothReconnectManager()

    private let targetsKey = "AutoReconnectBluetoothTargets"
    private var targets: [String: String] = [:]
    private var lastAttemptByName: [String: Date] = [:]
    private var pollTimer: Timer?

    private var retryInterval: TimeInterval {
        DeviceAutomationStore.loadBluetoothReconnectInterval()
    }

    private init() {}

    func start(with deviceNames: Set<String>) {
        loadTargets()
        for name in deviceNames {
            register(deviceName: name)
        }
        startPolling()
    }

    func register(deviceName: String) {
        if let address = resolveAddress(for: deviceName) {
            targets[deviceName] = address
            saveTargets()
            attemptReconnect(deviceName: deviceName)
        } else {
            targets[deviceName] = targets[deviceName] ?? ""
            saveTargets()
        }
    }

    func unregister(deviceName: String) {
        targets.removeValue(forKey: deviceName)
        lastAttemptByName.removeValue(forKey: deviceName)
        saveTargets()
    }

    func isRegistered(deviceName: String) -> Bool {
        targets.keys.contains(deviceName)
    }

    func isPairedDevice(named name: String) -> Bool {
        resolveAddress(for: name) != nil
    }

    func updatePollInterval() {
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        guard !targets.isEmpty else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: true) { [weak self] _ in
            self?.attemptReconnectAll()
        }
    }

    private func attemptReconnectAll() {
        for name in targets.keys {
            attemptReconnect(deviceName: name)
        }
    }

    private func attemptReconnect(deviceName: String) {
        if targets[deviceName]?.isEmpty != false {
            guard let resolved = resolveAddress(for: deviceName) else { return }
            targets[deviceName] = resolved
            saveTargets()
        }

        guard let address = targets[deviceName], !address.isEmpty else { return }

        if let lastAttempt = lastAttemptByName[deviceName],
           Date().timeIntervalSince(lastAttempt) < retryInterval {
            return
        }

        guard let device = IOBluetoothDevice(addressString: address) else { return }
        guard device.isPaired() else { return }
        guard !device.isConnected() else { return }

        lastAttemptByName[deviceName] = Date()
        let result = device.openConnection()
        if result != kIOReturnSuccess {
            print("Bluetooth reconnect failed for \(deviceName): \(result)")
        }
    }

    private func resolveAddress(for name: String) -> String? {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }

        return paired.first { device in
            let deviceName = device.name ?? device.nameOrAddress ?? ""
            return deviceName.caseInsensitiveCompare(name) == .orderedSame
        }?.addressString
    }

    private func loadTargets() {
        guard let stored = UserDefaults.standard.dictionary(forKey: targetsKey) as? [String: String] else {
            targets = [:]
            return
        }
        targets = stored
    }

    private func saveTargets() {
        UserDefaults.standard.set(targets, forKey: targetsKey)
    }
}
