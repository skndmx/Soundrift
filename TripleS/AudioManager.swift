import Foundation
import CoreAudio
import UserNotifications

struct SavedDevice: Codable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
    let isAirPlay: Bool

    init(from device: AudioDevice) {
        id = device.id
        name = device.name
        isInput = device.isInput
        isOutput = device.isOutput
        isAirPlay = device.isAirPlay
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isInput, isOutput, isAirPlay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AudioDeviceID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isInput = try container.decode(Bool.self, forKey: .isInput)
        isOutput = try container.decodeIfPresent(Bool.self, forKey: .isOutput) ?? !isInput
        isAirPlay = try container.decodeIfPresent(Bool.self, forKey: .isAirPlay) ?? false
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
    static let hideMicrosoftTeamsAudioKey = "hideMicrosoftTeamsAudio"

    private var preferredOutputDeviceNames: Set<String> = []
    private var preferredInputDeviceNames: Set<String> = []
    
    private var hideMicrosoftTeamsAudio: Bool {
        UserDefaults.standard.bool(forKey: Self.hideMicrosoftTeamsAudioKey)
    }
    
    private func filterHiddenDevices(_ devices: [AudioDevice]) -> [AudioDevice] {
        guard hideMicrosoftTeamsAudio else { return devices }
        return devices.filter { !$0.isMicrosoftTeamsAudio }
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
        let liveOutputDevices = filterHiddenDevices(AudioDevice.getAllDevices().filter { $0.isOutput })
        let liveInputDevices = filterHiddenDevices(AudioDevice.getAllDevices().filter { $0.isInput })

        let outputDevices = mergeWithKnownDevices(
            liveDevices: liveOutputDevices,
            knownDevices: loadKnownDevices(from: knownOutputDevicesKey)
        )
        let inputDevices = mergeWithKnownDevices(
            liveDevices: liveInputDevices,
            knownDevices: loadKnownDevices(from: knownInputDevicesKey)
        )
        
        // Initialize output devices
        self.availableDevices = outputDevices
        self.preferredOutputDeviceNames = loadPreferredDeviceNames(from: selectedDevicesKey, devices: outputDevices)
        self.selectedDevices = syncedSelection(
            devices: outputDevices,
            preferredNames: preferredOutputDeviceNames
        )
        self.currentDevice = AudioDevice.getCurrentDefault()
        saveKnownDevices(outputDevices, to: knownOutputDevicesKey)
        
        // Initialize input devices
        self.availableInputDevices = inputDevices
        self.preferredInputDeviceNames = loadPreferredDeviceNames(from: selectedInputDevicesKey, devices: inputDevices)
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
        let liveDevices = filterHiddenDevices(AudioDevice.getAllDevices().filter { $0.isOutput })
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
            devices: mergedDevices,
            preferredNames: preferredOutputDeviceNames
        )

        saveSelectedDevices()
        currentDevice = AudioDevice.getCurrentDefault()
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
            
            // Show notification
            let content = UNMutableNotificationContent()
            content.title = "Audio Output Changed"
            content.body = "Switched to \(nextDevice.name)"
            
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
        let liveDevices = filterHiddenDevices(AudioDevice.getAllDevices().filter { $0.isInput })
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
            devices: mergedDevices,
            preferredNames: preferredInputDeviceNames
        )

        saveSelectedInputDevices()
        currentInputDevice = AudioDevice.getCurrentDefaultInput()
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