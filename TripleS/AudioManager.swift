import Foundation
import CoreAudio
import UserNotifications

struct SavedDevice: Codable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
    let isAirPlay: Bool
    let isBluetooth: Bool

    init(from device: AudioDevice) {
        id = device.id
        name = device.name
        isInput = device.isInput
        isOutput = device.isOutput
        isAirPlay = device.isAirPlay
        isBluetooth = device.isBluetooth
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isInput, isOutput, isAirPlay, isBluetooth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AudioDeviceID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isInput = try container.decode(Bool.self, forKey: .isInput)
        isOutput = try container.decodeIfPresent(Bool.self, forKey: .isOutput) ?? !isInput
        isAirPlay = try container.decodeIfPresent(Bool.self, forKey: .isAirPlay) ?? false
        isBluetooth = try container.decodeIfPresent(Bool.self, forKey: .isBluetooth) ?? false
    }
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevices: Set<AudioDevice> = []
    @Published var currentDevice: AudioDevice?
    @Published var selectedInputDevices: Set<AudioDevice> = []
    @Published var currentInputDevice: AudioDevice?
    @Published var availableInputDevices: [AudioDevice] = []
    
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    
    private let selectedDevicesKey = "SelectedDevices"
    private let selectedInputDevicesKey = "SelectedInputDevices"
    private let knownOutputDevicesKey = "KnownOutputDevices"
    private let knownInputDevicesKey = "KnownInputDevices"
    private let hiddenOutputDeviceNamesKey = "HiddenOutputDeviceNames"
    private let hiddenInputDeviceNamesKey = "HiddenInputDeviceNames"
    private let teamsHideMigrationKey = "didMigrateTeamsHideSetting"
    static let hideMicrosoftTeamsAudioKey = "hideMicrosoftTeamsAudio"

    private var preferredOutputDeviceNames: Set<String> = []
    private var preferredInputDeviceNames: Set<String> = []
    @Published private(set) var hiddenOutputDeviceNames: Set<String> = []
    @Published private(set) var hiddenInputDeviceNames: Set<String> = []
    @Published private(set) var autoSwitchOutputDeviceNames: Set<String> = []
    @Published private(set) var autoSwitchInputDeviceNames: Set<String> = []
    @Published private(set) var autoReconnectBluetoothDeviceNames: Set<String> = []

    var visibleOutputDevices: [AudioDevice] {
        availableDevices.filter { !hiddenOutputDeviceNames.contains($0.name) }
    }

    var hiddenOutputDevices: [AudioDevice] {
        availableDevices.filter { hiddenOutputDeviceNames.contains($0.name) }
    }

    var visibleInputDevices: [AudioDevice] {
        availableInputDevices.filter { !hiddenInputDeviceNames.contains($0.name) }
    }

    var hiddenInputDevices: [AudioDevice] {
        availableInputDevices.filter { hiddenInputDeviceNames.contains($0.name) }
    }
    
    private init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Initialize and load saved devices synchronously to avoid race conditions
        let liveOutputDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let liveInputDevices = AudioDevice.getAllDevices().filter { $0.isInput }

        hiddenOutputDeviceNames = loadHiddenDeviceNames(from: hiddenOutputDeviceNamesKey)
        hiddenInputDeviceNames = loadHiddenDeviceNames(from: hiddenInputDeviceNamesKey)
        autoSwitchOutputDeviceNames = DeviceAutomationStore.loadAutoSwitchOutputNames()
        autoSwitchInputDeviceNames = DeviceAutomationStore.loadAutoSwitchInputNames()
        autoReconnectBluetoothDeviceNames = DeviceAutomationStore.loadAutoReconnectNames()

        let outputDevices = mergeWithKnownDevices(
            liveDevices: liveOutputDevices,
            knownDevices: loadKnownDevices(from: knownOutputDevicesKey)
        )
        let inputDevices = mergeWithKnownDevices(
            liveDevices: liveInputDevices,
            knownDevices: loadKnownDevices(from: knownInputDevicesKey)
        )

        migrateLegacyTeamsHideSetting(outputDevices: outputDevices, inputDevices: inputDevices)
        
        // Initialize output devices
        self.availableDevices = outputDevices
        self.preferredOutputDeviceNames = loadPreferredDeviceNames(from: selectedDevicesKey, devices: outputDevices)
            .subtracting(hiddenOutputDeviceNames)
        self.selectedDevices = syncedSelection(
            devices: outputDevices,
            preferredNames: preferredOutputDeviceNames
        )
        self.currentDevice = AudioDevice.getCurrentDefault()
        saveKnownDevices(outputDevices, to: knownOutputDevicesKey)
        
        // Initialize input devices
        self.availableInputDevices = inputDevices
        self.preferredInputDeviceNames = loadPreferredDeviceNames(from: selectedInputDevicesKey, devices: inputDevices)
            .subtracting(hiddenInputDeviceNames)
        self.selectedInputDevices = syncedSelection(
            devices: inputDevices,
            preferredNames: preferredInputDeviceNames
        )
        self.currentInputDevice = AudioDevice.getCurrentDefaultInput()
        saveKnownDevices(inputDevices, to: knownInputDevicesKey)
        
        // Save initial states if needed
        if UserDefaults.standard.array(forKey: selectedDevicesKey) == nil {
            saveSelectedDevices()
        }
        if UserDefaults.standard.array(forKey: selectedInputDevicesKey) == nil {
            saveSelectedInputDevices()
        }
        
        // Setup listeners after initialization
        setupDeviceListener()
        setupDefaultDeviceListener()
        BluetoothReconnectManager.shared.start(with: autoReconnectBluetoothDeviceNames)
    }
    
    private func setupDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        deviceListener = { [weak self] (
            _ inNumberAddresses: UInt32,
            _ inPropertyAddresses: UnsafePointer<AudioObjectPropertyAddress>
        ) in
            DispatchQueue.main.async {
                self?.refreshAudioDevices()
                self?.refreshInputDevices()
            }
        }
        
        guard let listener = deviceListener else { return }
        
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            listener
        )
    }
    
    private func setupDefaultDeviceListener() {
        // Output device monitoring
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Input device monitoring
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        defaultDeviceListener = { [weak self] (
            _ inNumberAddresses: UInt32,
            _ inPropertyAddresses: UnsafePointer<AudioObjectPropertyAddress>
        ) in
            DispatchQueue.main.async {
                self?.currentDevice = AudioDevice.getCurrentDefault()
                self?.currentInputDevice = AudioDevice.getCurrentDefaultInput()
            }
        }
        
        guard let listener = defaultDeviceListener else { return }
        
        // Add listener for output device changes
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            nil,
            listener
        )
        
        // Add listener for input device changes
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &inputAddress,
            nil,
            listener
        )
    }
    
    func refreshAllDevices() {
        refreshAudioDevices()
        refreshInputDevices()
    }
    
    func refreshAudioDevices() {
        let previousDevices = availableDevices
        let liveDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let mergedDevices = mergeWithKnownDevices(
            liveDevices: liveDevices,
            knownDevices: loadKnownDevices(from: knownOutputDevicesKey)
        )

        availableDevices = mergedDevices
        saveKnownDevices(mergedDevices, to: knownOutputDevicesKey)
        preferredOutputDeviceNames = updatedPreferredNames(
            mergedDevices: mergedDevices,
            previousDevices: previousDevices,
            preferredNames: preferredOutputDeviceNames
        )
        selectedDevices = syncedSelection(
            devices: mergedDevices.filter { !hiddenOutputDeviceNames.contains($0.name) },
            preferredNames: preferredOutputDeviceNames
        )

        saveSelectedDevices()
        currentDevice = AudioDevice.getCurrentDefault()

        let newlyConnected = newlyConnectedDevices(previous: previousDevices, current: mergedDevices)
        for device in newlyConnected where autoSwitchOutputDeviceNames.contains(device.name) {
            applyDefaultOutputDevice(device, notify: true)
        }
    }
    
    func switchToNextDevice() {
        // Get connected devices and ensure they're sorted
        let connectedDevices = selectedDevices
            .filter { $0.isConnected }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        guard !connectedDevices.isEmpty else {
            print("Error: No connected devices available")
            return
        }
        
        let currentIndex = connectedDevices.firstIndex {
            $0.id == currentDevice?.id || $0.name == currentDevice?.name
        } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]
        
        if nextDevice.setAsDefault() {
            currentDevice = nextDevice
            NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: nextDevice)
            postSwitchNotification(title: "Audio Output Changed", body: "Switched to \(nextDevice.name)")
        }
    }
    
    deinit {
        if let listener = deviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
        }
        
        if let listener = defaultDeviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
        }
    }
    
    func saveSelectedDevices() {
        let savedDevices = availableDevices
            .filter { preferredOutputDeviceNames.contains($0.name) }
            .map { SavedDevice(from: $0) }
        if let encoded = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(encoded, forKey: selectedDevicesKey)
        }
    }

    func refreshInputDevices() {
        let previousDevices = availableInputDevices
        let liveDevices = AudioDevice.getAllDevices().filter { $0.isInput }
        let mergedDevices = mergeWithKnownDevices(
            liveDevices: liveDevices,
            knownDevices: loadKnownDevices(from: knownInputDevicesKey)
        )

        availableInputDevices = mergedDevices
        saveKnownDevices(mergedDevices, to: knownInputDevicesKey)
        preferredInputDeviceNames = updatedPreferredNames(
            mergedDevices: mergedDevices,
            previousDevices: previousDevices,
            preferredNames: preferredInputDeviceNames
        )
        selectedInputDevices = syncedSelection(
            devices: mergedDevices.filter { !hiddenInputDeviceNames.contains($0.name) },
            preferredNames: preferredInputDeviceNames
        )

        saveSelectedInputDevices()
        currentInputDevice = AudioDevice.getCurrentDefaultInput()

        let newlyConnected = newlyConnectedDevices(previous: previousDevices, current: mergedDevices)
        for device in newlyConnected where autoSwitchInputDeviceNames.contains(device.name) {
            applyDefaultInputDevice(device, notify: true)
        }
    }

    func saveSelectedInputDevices() {
        let savedDevices = availableInputDevices
            .filter { preferredInputDeviceNames.contains($0.name) }
            .map { SavedDevice(from: $0) }
        if let encoded = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(encoded, forKey: selectedInputDevicesKey)
        }
    }

    func isOutputDeviceSelected(_ device: AudioDevice) -> Bool {
        device.isConnected && preferredOutputDeviceNames.contains(device.name)
    }

    func isInputDeviceSelected(_ device: AudioDevice) -> Bool {
        device.isConnected && preferredInputDeviceNames.contains(device.name)
    }

    func setOutputDeviceSelected(_ device: AudioDevice, selected: Bool) {
        guard device.isConnected else { return }

        if selected {
            preferredOutputDeviceNames.insert(device.name)
        } else {
            preferredOutputDeviceNames.remove(device.name)
        }

        selectedDevices = syncedSelection(
            devices: availableDevices,
            preferredNames: preferredOutputDeviceNames
        )
        saveSelectedDevices()
    }

    func setInputDeviceSelected(_ device: AudioDevice, selected: Bool) {
        guard device.isConnected else { return }

        if selected {
            preferredInputDeviceNames.insert(device.name)
        } else {
            preferredInputDeviceNames.remove(device.name)
        }

        selectedInputDevices = syncedSelection(
            devices: availableInputDevices,
            preferredNames: preferredInputDeviceNames
        )
        saveSelectedInputDevices()
    }

    func hideOutputDevice(_ device: AudioDevice) {
        hiddenOutputDeviceNames.insert(device.name)
        preferredOutputDeviceNames.remove(device.name)
        selectedDevices = syncedSelection(
            devices: availableDevices,
            preferredNames: preferredOutputDeviceNames
        )
        saveHiddenDeviceNames(hiddenOutputDeviceNames, to: hiddenOutputDeviceNamesKey)
        saveSelectedDevices()
    }

    func showOutputDevice(_ device: AudioDevice) {
        hiddenOutputDeviceNames.remove(device.name)
        saveHiddenDeviceNames(hiddenOutputDeviceNames, to: hiddenOutputDeviceNamesKey)
    }

    func hideInputDevice(_ device: AudioDevice) {
        hiddenInputDeviceNames.insert(device.name)
        preferredInputDeviceNames.remove(device.name)
        selectedInputDevices = syncedSelection(
            devices: availableInputDevices,
            preferredNames: preferredInputDeviceNames
        )
        saveHiddenDeviceNames(hiddenInputDeviceNames, to: hiddenInputDeviceNamesKey)
        saveSelectedInputDevices()
    }

    func showInputDevice(_ device: AudioDevice) {
        hiddenInputDeviceNames.remove(device.name)
        saveHiddenDeviceNames(hiddenInputDeviceNames, to: hiddenInputDeviceNamesKey)
    }

    func isAutoSwitchOnConnectEnabled(_ device: AudioDevice, kind: DeviceType) -> Bool {
        switch kind {
        case .output: autoSwitchOutputDeviceNames.contains(device.name)
        case .input: autoSwitchInputDeviceNames.contains(device.name)
        }
    }

    func setAutoSwitchOnConnect(_ device: AudioDevice, kind: DeviceType, enabled: Bool) {
        switch kind {
        case .output:
            if enabled {
                autoSwitchOutputDeviceNames.insert(device.name)
            } else {
                autoSwitchOutputDeviceNames.remove(device.name)
            }
            DeviceAutomationStore.saveAutoSwitchOutputNames(autoSwitchOutputDeviceNames)
        case .input:
            if enabled {
                autoSwitchInputDeviceNames.insert(device.name)
            } else {
                autoSwitchInputDeviceNames.remove(device.name)
            }
            DeviceAutomationStore.saveAutoSwitchInputNames(autoSwitchInputDeviceNames)
        }
    }

    func isAutoReconnectBluetoothEnabled(_ device: AudioDevice) -> Bool {
        autoReconnectBluetoothDeviceNames.contains(device.name)
    }

    func supportsBluetoothReconnect(for device: AudioDevice) -> Bool {
        if device.isBluetooth {
            return true
        }
        return BluetoothReconnectManager.shared.isPairedDevice(named: device.name)
    }

    func setAutoReconnectBluetooth(_ device: AudioDevice, enabled: Bool) {
        guard supportsBluetoothReconnect(for: device) else { return }

        if enabled {
            autoReconnectBluetoothDeviceNames.insert(device.name)
            BluetoothReconnectManager.shared.register(deviceName: device.name)
        } else {
            autoReconnectBluetoothDeviceNames.remove(device.name)
            BluetoothReconnectManager.shared.unregister(deviceName: device.name)
        }
        DeviceAutomationStore.saveAutoReconnectNames(autoReconnectBluetoothDeviceNames)
    }

    private func applyDefaultOutputDevice(_ device: AudioDevice, notify: Bool) {
        guard device.isConnected, device.setAsDefault() else { return }
        currentDevice = device
        NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: device)
        if notify {
            postSwitchNotification(title: "Audio Output Changed", body: "Connected to \(device.name)")
        }
    }

    private func applyDefaultInputDevice(_ device: AudioDevice, notify: Bool) {
        guard device.isConnected, device.setAsDefaultInput() else { return }
        currentInputDevice = device
        if notify {
            postSwitchNotification(title: "Audio Input Changed", body: "Connected to \(device.name)")
        }
    }

    private func postSwitchNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }

    private func newlyConnectedDevices(previous: [AudioDevice], current: [AudioDevice]) -> [AudioDevice] {
        current.filter { device in
            guard device.isConnected else { return false }
            let wasConnected = previous.first(where: { $0.name == device.name })?.isConnected ?? false
            return !wasConnected
        }
    }

    private func loadHiddenDeviceNames(from key: String) -> Set<String> {
        guard let names = UserDefaults.standard.array(forKey: key) as? [String] else {
            return []
        }
        return Set(names)
    }

    private func saveHiddenDeviceNames(_ names: Set<String>, to key: String) {
        UserDefaults.standard.set(Array(names).sorted(), forKey: key)
    }

    private func migrateLegacyTeamsHideSetting(outputDevices: [AudioDevice], inputDevices: [AudioDevice]) {
        guard !UserDefaults.standard.bool(forKey: teamsHideMigrationKey) else { return }

        if UserDefaults.standard.object(forKey: Self.hideMicrosoftTeamsAudioKey) as? Bool ?? true {
            for device in outputDevices where device.isMicrosoftTeamsAudio {
                hiddenOutputDeviceNames.insert(device.name)
            }
            for device in inputDevices where device.isMicrosoftTeamsAudio {
                hiddenInputDeviceNames.insert(device.name)
            }

            for saved in loadKnownDevices(from: knownOutputDevicesKey) where saved.name.localizedCaseInsensitiveContains("Microsoft Teams") {
                hiddenOutputDeviceNames.insert(saved.name)
            }
            for saved in loadKnownDevices(from: knownInputDevicesKey) where saved.name.localizedCaseInsensitiveContains("Microsoft Teams") {
                hiddenInputDeviceNames.insert(saved.name)
            }
        }

        saveHiddenDeviceNames(hiddenOutputDeviceNames, to: hiddenOutputDeviceNamesKey)
        saveHiddenDeviceNames(hiddenInputDeviceNames, to: hiddenInputDeviceNamesKey)
        UserDefaults.standard.set(true, forKey: teamsHideMigrationKey)
    }

    private func syncedSelection(
        devices: [AudioDevice],
        preferredNames: Set<String>
    ) -> Set<AudioDevice> {
        Set(devices.filter { $0.isConnected && preferredNames.contains($0.name) })
    }

    private func updatedPreferredNames(
        mergedDevices: [AudioDevice],
        previousDevices: [AudioDevice],
        preferredNames: Set<String>
    ) -> Set<String> {
        var updated = preferredNames
        let previouslyKnownNames = Set(previousDevices.map(\.name))

        for device in mergedDevices where device.isConnected && !previouslyKnownNames.contains(device.name) {
            updated.insert(device.name)
        }

        return updated
    }

    private func loadPreferredDeviceNames(from key: String, devices: [AudioDevice]) -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: key),
           let savedDevices = try? JSONDecoder().decode([SavedDevice].self, from: data) {
            return Set(savedDevices.map(\.name))
        }

        return Set(devices.map(\.name))
    }

    private func mergeWithKnownDevices(
        liveDevices: [AudioDevice],
        knownDevices: [SavedDevice]
    ) -> [AudioDevice] {
        var mergedByName: [String: AudioDevice] = [:]

        for saved in knownDevices {
            if let liveDevice = liveDevices.first(where: { $0.name == saved.name }) {
                mergedByName[liveDevice.name] = liveDevice
            } else {
                mergedByName[saved.name] = AudioDevice(saved: saved)
            }
        }

        for liveDevice in liveDevices {
            mergedByName[liveDevice.name] = liveDevice
        }

        if mergedByName.isEmpty {
            return liveDevices.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        return mergedByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func loadKnownDevices(from key: String) -> [SavedDevice] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let savedDevices = try? JSONDecoder().decode([SavedDevice].self, from: data) else {
            return []
        }
        return savedDevices
    }

    private func saveKnownDevices(_ devices: [AudioDevice], to key: String) {
        let savedDevices = devices.map { SavedDevice(from: $0) }
        if let encoded = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
} 