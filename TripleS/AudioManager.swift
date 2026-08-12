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
    /// Last hotkey/auto-switch input choice — FineTune "Lock Input Device" (UID + echo).
    /// https://github.com/ronitsingh10/FineTune
    private var heldInputDeviceName: String?
    private var heldInputDeviceUID: String?
    private let inputEchoTracker = InputEchoTracker()
    private var isRestoringHeldInput = false
    /// When false, we still remember `heldInputDeviceName` for hotkey rotation but
    /// do not reassert against Continuity (avoids an endless restore loop).
    private var inputLockArmed = false
    private var inputRestoreBudget = 0
    
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

        // FineTune ships with mic entitlement + usage string; Continuity Camera often
        // reclaims default input from apps that never requested record permission.
        Self.requestMicrophoneAccessIfNeeded()

        inputEchoTracker.onTimeout = { [weak self] uid in
            guard let self, self.inputLockArmed else { return }
            // Echo never came back (Continuity often steals before our set echoes).
            // Restore at most until the budget is spent — never loop forever.
            if AudioDevice.getCurrentDefaultInput()?.uid == self.heldInputDeviceUID {
                return
            }
            print("Input echo timed out for \(uid) — re-evaluating lock (budget=\(self.inputRestoreBudget))")
            self.restoreHeldInputDevice()
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
            let selector = inPropertyAddresses.pointee.mSelector
            DispatchQueue.main.async {
                if selector == kAudioHardwarePropertyDefaultOutputDevice {
                    self?.currentDevice = AudioDevice.getCurrentDefault()
                } else if selector == kAudioHardwarePropertyDefaultInputDevice {
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
        let currentIndex = connectedDevices.firstIndex {
            $0.id == before?.id || $0.name == before?.name
        } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]

        print("Output switch: \(before?.name ?? "nil") → \(nextDevice.name)")
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
            // Continuity/iPhone stays in rotation; FineTune-style input lock holds the choice.
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
        // Prefer held selection for rotation so Continuity reclaiming the system
        // default doesn't pin every press on "switch to MacBook" forever.
        let currentName = heldInputDeviceName
            ?? before?.name
            ?? currentInputDevice?.name
        let currentIndex = connectedDevices.firstIndex { $0.name == currentName } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]

        print("Input switch: system=\(before?.name ?? "nil") held=\(heldInputDeviceName ?? "nil") → \(nextDevice.name)")
        print("Input rotation: \(connectedDevices.map(\.name))")
        applyDefaultInputDevice(nextDevice, notify: true)
        let after = AudioDevice.getCurrentDefaultInput()
        print("Input current device: \(after?.name ?? "nil") (id=\(after?.id ?? 0)) held=\(heldInputDeviceName ?? "nil")")
    }

    private func preferredConnectedLiveDevices(
        names: Set<String>,
        requireOutput: Bool,
        requireInput: Bool
    ) -> [AudioDevice] {
        AudioDevice.getAllDevices()
            .filter { device in
                guard names.contains(device.name), device.isConnected else { return false }
                if requireOutput {
                    guard device.isOutput else { return false }
                    guard device.canBeSystemDefault(scope: kAudioDevicePropertyScopeOutput) else {
                        return false
                    }
                }
                if requireInput && !device.isInput { return false }
                return true
            }
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
        let target = device.resolvedLiveDevice() ?? device
        guard target.isConnected, target.setAsDefault() else {
            print("Failed to set default output: \(device.name) id=\(device.id)")
            return
        }
        // Prefer system truth over optimistic assignment (some virtual devices ignore sets).
        currentDevice = AudioDevice.getCurrentDefault() ?? target
        NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: currentDevice)
        if notify {
            let actualName = currentDevice?.name ?? target.name
            if actualName == target.name {
                postSwitchNotification(title: "Audio Output Changed", body: "Switched to \(actualName)")
            } else {
                print("Output set requested=\(target.name) but system stayed on \(actualName)")
                postSwitchNotification(
                    title: "Audio Output Unchanged",
                    body: "macOS kept \(actualName) instead of \(target.name)."
                )
            }
        }
    }

    private func applyDefaultInputDevice(_ device: AudioDevice, notify: Bool) {
        let target = device.resolvedLiveDevice() ?? device
        guard target.isConnected else {
            print("Failed to set default input: \(device.name) id=\(device.id) (not connected)")
            return
        }

        // FineTune setLockedInputDevice: persist lock UID, set HAL default, echo-increment UID.
        heldInputDeviceName = target.name
        heldInputDeviceUID = target.uid.isEmpty ? nil : target.uid
        inputLockArmed = heldInputDeviceUID != nil
        inputRestoreBudget = 5
        inputEchoTracker.cancelAll()

        guard target.setAsDefaultInput() else {
            print("Failed to set default input HAL call: \(target.name)")
            return
        }
        if let uid = heldInputDeviceUID {
            inputEchoTracker.increment(uid)
        }

        currentInputDevice = AudioDevice.getCurrentDefaultInput() ?? target
        print("Input set requested=\(target.name) uid=\(target.uid) system=\(currentInputDevice?.name ?? "nil")")

        // Continuity often races the first set — verify a few times without opening IO.
        for delay in [0.15, 0.4, 0.9] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.restoreHeldInputDevice()
            }
        }

        if notify {
            postSwitchNotification(title: "Audio Input Changed", body: "Switched to \(target.name)")
        }
    }

    /// FineTune handleDefaultInputDeviceChanged — UID echo, hasPending skip, then restore.
    private func handleDefaultInputDeviceChanged() {
        let actual = AudioDevice.getCurrentDefaultInput()
        currentInputDevice = actual
        guard let actual else { return }

        let newUID = actual.uid
        if !newUID.isEmpty, inputEchoTracker.consume(newUID) {
            print("Input echo ignored for \(actual.name)")
            return
        }

        // While our own set is in flight, skip interim routing (FineTune hasPending).
        if inputEchoTracker.hasPending {
            print("Input routing skipped — echo pending (system=\(actual.name))")
            return
        }

        guard inputLockArmed, let lockedUID = heldInputDeviceUID, !lockedUID.isEmpty else { return }
        if newUID == lockedUID { return }

        if inputRestoreBudget <= 0 {
            disarmInputLock(reason: "Continuity kept reclaiming \(actual.name)")
            return
        }

        print("Input drift detected: system=\(actual.name) held=\(heldInputDeviceName ?? lockedUID) — restoring")
        restoreHeldInputDevice()
    }

    /// FineTune restoreLockedInputDevice, with a Continuity reclaim budget.
    private func restoreHeldInputDevice() {
        guard !isRestoringHeldInput else { return }
        guard inputLockArmed, let lockedUID = heldInputDeviceUID, !lockedUID.isEmpty else { return }
        guard inputRestoreBudget > 0 else {
            disarmInputLock(reason: "restore budget exhausted")
            return
        }

        let device = AudioDevice.getAllDevices().first { live in
            live.isInput && live.isConnected && live.uid == lockedUID
        } ?? AudioDevice.getAllDevices().first { live in
            guard live.isInput, live.isConnected else { return false }
            return live.name == heldInputDeviceName
        }
        guard let device else { return }

        if AudioDevice.getCurrentDefaultInput()?.uid == lockedUID { return }

        inputRestoreBudget -= 1
        isRestoringHeldInput = true
        defer { isRestoringHeldInput = false }

        print("Input lock restore → \(device.name) (budget left=\(inputRestoreBudget))")
        if device.setAsDefaultInput() {
            inputEchoTracker.increment(lockedUID)
            currentInputDevice = device
        }
    }

    /// Stop fighting Continuity; keep name so hotkey rotation still advances correctly.
    private func disarmInputLock(reason: String) {
        print("Input lock disarmed — \(reason)")
        inputLockArmed = false
        heldInputDeviceUID = nil
        inputEchoTracker.cancelAll()
    }

    private static func requestMicrophoneAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Microphone access already authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "Microphone access granted" : "Microphone access denied")
            }
        case .denied, .restricted:
            print("Microphone access denied/restricted — Continuity may reclaim default input")
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

/// FineTune EchoTracker — reference-counted UID echo suppression with timeout restore.
/// https://github.com/ronitsingh10/FineTune/blob/main/FineTune/Audio/Engine/EchoTracker.swift
private final class InputEchoTracker {
    private var activeTimeouts: [String: Set<Int>] = [:]
    private var nextToken = 0
    private var generation = 0
    var onTimeout: ((String) -> Void)?

    var hasPending: Bool { !activeTimeouts.isEmpty }

    func cancelAll() {
        activeTimeouts.removeAll()
        generation += 1
    }

    func increment(_ uid: String) {
        guard !uid.isEmpty else { return }
        let token = nextToken
        nextToken += 1
        let gen = generation
        activeTimeouts[uid, default: []].insert(token)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.generation == gen else { return }
            guard self.activeTimeouts[uid]?.remove(token) != nil else { return }
            if self.activeTimeouts[uid]?.isEmpty == true {
                self.activeTimeouts.removeValue(forKey: uid)
            }
            print("Input echo for \(uid) timed out")
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