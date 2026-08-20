import Foundation
import CoreAudio
import AVFoundation
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
    private var availabilityListenerBlock: AudioObjectPropertyListenerBlock?
    private var availabilityListenerIDs: Set<AudioDeviceID> = []
    private var availabilityAddresses: [AudioDeviceID: [AudioObjectPropertyAddress]] = [:]
    private var followUpRefreshWork: [DispatchWorkItem] = []
    private var availabilityRefreshWork: DispatchWorkItem?
    /// FineTune-style input lock: remember the last explicit choice and reassert if
    /// macOS changes the default (BT reconnect, System Settings, etc.).
    /// Disable FineTune's "Lock Input Device" (or quit FineTune) when using Soundrift,
    /// or the two locks will fight each other.
    private var heldInputDeviceName: String?
    private var heldInputDeviceUID: String?
    private let inputEchoTracker = InputEchoTracker()
    private var isRestoringHeldInput = false
    
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

        // Microphone entitlement + usage string (same as FineTune).
        Self.requestMicrophoneAccessIfNeeded()

        inputEchoTracker.onTimeout = { [weak self] _ in
            self?.restoreHeldInputDevice()
        }
        
        // Initialize and load saved devices synchronously to avoid race conditions
        let liveOutputDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let liveInputDevices = AudioDevice.getAllDevices().filter { $0.isInput }

        hiddenOutputDeviceNames = loadHiddenDeviceNames(from: hiddenOutputDeviceNamesKey)
        hiddenInputDeviceNames = loadHiddenDeviceNames(from: hiddenInputDeviceNamesKey)
        autoSwitchOutputDeviceNames = DeviceAutomationStore.loadAutoSwitchOutputNames()
        autoSwitchInputDeviceNames = DeviceAutomationStore.loadAutoSwitchInputNames()

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
        syncAvailabilityListeners()
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
                self?.refreshAllDevices()
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
            let selector = inPropertyAddresses.pointee.mSelector
            DispatchQueue.main.async {
                // AirPods-in-case often changes the default without removing the
                // HAL device. Re-enumerate so the row can flip to Disconnected.
                self?.refreshAllDevices()
                self?.scheduleFollowUpDeviceRefresh()
                if selector == kAudioHardwarePropertyDefaultInputDevice {
                    self?.handleDefaultInputDeviceChanged()
                }
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
        syncAvailabilityListeners()
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
        logConnectionChanges(previous: previousDevices, current: mergedDevices, kind: .output)

        let newlyConnected = AudioDevice.uniquePreferredDevices(
            newlyConnectedDevices(previous: previousDevices, current: mergedDevices),
            kind: .output
        )
        for device in newlyConnected where autoSwitchOutputDeviceNames.contains(device.name) {
            applyDefaultOutputDevice(device, notify: true)
        }
    }
    
    func switchToNextDevice() {
        let connectedDevices = preferredConnectedLiveDevices(
            names: preferredOutputDeviceNames,
            requireOutput: true,
            requireInput: false
        )

        guard !connectedDevices.isEmpty else {
            print("Error: No connected output devices available")
            return
        }

        let before = AudioDevice.getCurrentDefault()
        let currentIndex = connectedDevices.firstIndex { device in
            guard let before else { return false }
            return device.isSameAudioEndpoint(as: before)
        } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]

        print("Output switch: \(before?.name ?? "nil") → \(nextDevice.name) id=\(nextDevice.id)")
        applyDefaultOutputDevice(nextDevice, notify: true)
        let after = AudioDevice.getCurrentDefault()
        currentDevice = after
        print("Output current device: \(after?.name ?? "nil") (id=\(after?.id ?? 0))")
    }

    /// Live devices for hotkey rotation, always resolved from Core Audio by name
    /// so Continuity / Bluetooth ID changes don't skip a selected source.
    func preferredConnectedLiveInputDevices() -> [AudioDevice] {
        preferredConnectedLiveDevices(
            names: preferredInputDeviceNames,
            requireOutput: false,
            requireInput: true
        )
    }

    func switchToNextInputDevice() {
        let connectedDevices = preferredConnectedLiveInputDevices()
            // Skip devices macOS won't allow as the system default (e.g. Teams).
            .filter { device in
                device.canBeSystemDefault(scope: kAudioDevicePropertyScopeInput)
            }

        guard !connectedDevices.isEmpty else {
            print("Error: No hotkey-eligible input devices (non-defaultable devices are skipped)")
            postSwitchNotification(
                title: "No Switchable Input",
                body: "No checked input device can be set as the system default."
            )
            return
        }

        let before = AudioDevice.getCurrentDefaultInput()
        let currentName = heldInputDeviceName
            ?? before?.name
            ?? currentInputDevice?.name
        let currentIndex = connectedDevices.firstIndex { $0.name == currentName } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]

        print("Input switch: system=\(before?.name ?? "nil") held=\(heldInputDeviceName ?? "nil") → \(nextDevice.name)")
        applyDefaultInputDevice(nextDevice, notify: true)
        let after = AudioDevice.getCurrentDefaultInput()
        print("Input current device: \(after?.name ?? "nil") held=\(heldInputDeviceName ?? "nil")")
    }

    private func preferredConnectedLiveDevices(
        names: Set<String>,
        requireOutput: Bool,
        requireInput: Bool
    ) -> [AudioDevice] {
        let kind: DeviceType = requireOutput ? .output : .input
        let matches = AudioDevice.getAllDevices()
            .filter { device in
                guard names.contains(where: { AudioDeviceMatch.namesMatch($0, device.name) }),
                      device.isConnected else { return false }
                if requireOutput {
                    guard device.isOutput else { return false }
                    guard device.canBeSystemDefault(scope: kAudioDevicePropertyScopeOutput) else {
                        return false
                    }
                }
                if requireInput && !device.isInput { return false }
                return true
            }
        return AudioDevice.uniquePreferredDevices(matches, kind: kind)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

        removeAllAvailabilityListeners()
        followUpRefreshWork.forEach { $0.cancel() }
        availabilityRefreshWork?.cancel()
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
        logConnectionChanges(previous: previousDevices, current: mergedDevices, kind: .input)

        let newlyConnected = AudioDevice.uniquePreferredDevices(
            newlyConnectedDevices(previous: previousDevices, current: mergedDevices),
            kind: .input
        )
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
        preferredOutputDeviceNames.insert(device.name)
        selectedDevices = syncedSelection(
            devices: availableDevices,
            preferredNames: preferredOutputDeviceNames
        )
        saveHiddenDeviceNames(hiddenOutputDeviceNames, to: hiddenOutputDeviceNamesKey)
        saveSelectedDevices()
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
        preferredInputDeviceNames.insert(device.name)
        selectedInputDevices = syncedSelection(
            devices: availableInputDevices,
            preferredNames: preferredInputDeviceNames
        )
        saveHiddenDeviceNames(hiddenInputDeviceNames, to: hiddenInputDeviceNamesKey)
        saveSelectedInputDevices()
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

    private func applyDefaultOutputDevice(_ device: AudioDevice, notify: Bool) {
        let target = device.resolvedLiveDevice(kind: .output) ?? device
        guard target.isConnected else {
            print("Failed to set default output: \(device.name) id=\(device.id) (not connected)")
            return
        }

        let didStick = target.setAsDefaultOutputAndWait()
        let actual = AudioDevice.getCurrentDefault()
        currentDevice = actual ?? target
        NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: currentDevice)

        if notify {
            let actualName = actual?.name ?? target.name
            if didStick, actual.map({ $0.isSameAudioEndpoint(as: target) }) ?? false {
                postSwitchNotification(title: "Audio Output Changed", body: "Switched to \(actualName)")
            } else {
                print("Output set requested=\(target.name) id=\(target.id) but system stayed on \(actualName)")
                postSwitchNotification(
                    title: "Audio Output Unchanged",
                    body: "macOS kept \(actualName) instead of \(target.name)."
                )
            }
        }
    }

    private func applyDefaultInputDevice(_ device: AudioDevice, notify: Bool) {
        let target = device.resolvedLiveDevice(kind: .input) ?? device
        guard target.isConnected else {
            print("Failed to set default input: \(device.name) id=\(device.id) (not connected)")
            return
        }

        heldInputDeviceName = target.name
        heldInputDeviceUID = target.uid.isEmpty ? nil : target.uid

        guard target.setAsDefaultInput() else {
            print("Failed to set default input HAL call: \(target.name)")
            return
        }
        if let uid = heldInputDeviceUID {
            inputEchoTracker.increment(uid)
        }

        currentInputDevice = AudioDevice.getCurrentDefaultInput() ?? target
        print("Input set → \(target.name) (system=\(currentInputDevice?.name ?? "nil"))")

        if notify {
            postSwitchNotification(title: "Audio Input Changed", body: "Switched to \(target.name)")
        }
    }

    private func handleDefaultInputDeviceChanged() {
        let actual = AudioDevice.getCurrentDefaultInput()
        currentInputDevice = actual
        guard let actual else { return }

        let newUID = actual.uid
        if !newUID.isEmpty, inputEchoTracker.consume(newUID) {
            return
        }
        if inputEchoTracker.hasPending {
            return
        }

        guard let lockedUID = heldInputDeviceUID, !lockedUID.isEmpty else { return }
        if newUID != lockedUID {
            print("Input drift: system=\(actual.name) held=\(heldInputDeviceName ?? lockedUID) — restoring")
            restoreHeldInputDevice()
        }
    }

    private func restoreHeldInputDevice() {
        guard !isRestoringHeldInput else { return }
        guard let lockedUID = heldInputDeviceUID, !lockedUID.isEmpty else { return }

        let device = AudioDevice.getAllDevices().first { live in
            live.isInput && live.isConnected && live.uid == lockedUID
        } ?? AudioDevice.getAllDevices().first { live in
            live.isInput && live.isConnected && live.name == heldInputDeviceName
        }
        guard let device else { return }
        if AudioDevice.getCurrentDefaultInput()?.uid == lockedUID { return }

        isRestoringHeldInput = true
        defer { isRestoringHeldInput = false }

        if device.setAsDefaultInput() {
            inputEchoTracker.increment(lockedUID)
            currentInputDevice = device
            print("Input lock restore → \(device.name)")
        }
    }

    private static func requestMicrophoneAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        case .denied, .restricted:
            print("Microphone access denied — input switching may be limited")
        @unknown default:
            break
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

    private func logConnectionChanges(previous: [AudioDevice], current: [AudioDevice], kind: DeviceType) {
        for device in current {
            let wasConnected = previous.first(where: { $0.name == device.name })?.isConnected
            guard let wasConnected, wasConnected != device.isConnected else { continue }
            let label = kind == .output ? "Output" : "Input"
            print("\(label) \(device.name) \(device.isConnected ? "connected" : "disconnected")")
        }
        for previousDevice in previous where current.contains(where: { $0.name == previousDevice.name }) == false {
            guard previousDevice.isConnected else { continue }
            let label = kind == .output ? "Output" : "Input"
            print("\(label) \(previousDevice.name) disconnected")
        }
    }

    private func scheduleFollowUpDeviceRefresh() {
        followUpRefreshWork.forEach { $0.cancel() }
        followUpRefreshWork = [0.35, 1.0].map { delay in
            let work = DispatchWorkItem { [weak self] in
                self?.refreshAllDevices()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    private func scheduleAvailabilityRefresh() {
        availabilityRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshAllDevices()
        }
        availabilityRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func syncAvailabilityListeners() {
        if availabilityListenerBlock == nil {
            availabilityListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.scheduleAvailabilityRefresh()
                }
            }
        }
        guard let block = availabilityListenerBlock else { return }

        let liveIDs = Set(AudioDevice.getAllDevices().map(\.id))
        for deviceID in availabilityListenerIDs.subtracting(liveIDs) {
            removeAvailabilityListener(deviceID)
        }
        for deviceID in liveIDs.subtracting(availabilityListenerIDs) {
            addAvailabilityListener(deviceID, block: block)
        }
    }

    private func addAvailabilityListener(_ deviceID: AudioDeviceID, block: @escaping AudioObjectPropertyListenerBlock) {
        var addresses = [
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsAlive,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyJackIsConnected,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyJackIsConnected,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
        ]

        var added: [AudioObjectPropertyAddress] = []
        for index in addresses.indices {
            guard AudioObjectHasProperty(deviceID, &addresses[index]) else { continue }
            let status = AudioObjectAddPropertyListenerBlock(deviceID, &addresses[index], nil, block)
            if status == noErr {
                added.append(addresses[index])
            }
        }

        guard !added.isEmpty else { return }
        availabilityListenerIDs.insert(deviceID)
        availabilityAddresses[deviceID] = added
    }

    private func removeAvailabilityListener(_ deviceID: AudioDeviceID) {
        guard let block = availabilityListenerBlock,
              let addresses = availabilityAddresses.removeValue(forKey: deviceID) else {
            availabilityListenerIDs.remove(deviceID)
            return
        }
        for var address in addresses {
            _ = AudioObjectRemovePropertyListenerBlock(deviceID, &address, nil, block)
        }
        availabilityListenerIDs.remove(deviceID)
    }

    private func removeAllAvailabilityListeners() {
        let ids = availabilityListenerIDs
        for deviceID in ids {
            removeAvailabilityListener(deviceID)
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

/// FineTune-style echo suppression for our own default-input HAL writes.
private final class InputEchoTracker {
    private var activeTimeouts: [String: Set<Int>] = [:]
    private var nextToken = 0
    var onTimeout: ((String) -> Void)?

    var hasPending: Bool { !activeTimeouts.isEmpty }

    func increment(_ uid: String) {
        guard !uid.isEmpty else { return }
        let token = nextToken
        nextToken += 1
        activeTimeouts[uid, default: []].insert(token)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            guard self.activeTimeouts[uid]?.remove(token) != nil else { return }
            if self.activeTimeouts[uid]?.isEmpty == true {
                self.activeTimeouts.removeValue(forKey: uid)
            }
            self.onTimeout?(uid)
        }
    }

    func consume(_ uid: String) -> Bool {
        guard !uid.isEmpty, let token = activeTimeouts[uid]?.min() else { return false }
        activeTimeouts[uid]?.remove(token)
        if activeTimeouts[uid]?.isEmpty == true {
            activeTimeouts.removeValue(forKey: uid)
        }
        return true
    }
} 