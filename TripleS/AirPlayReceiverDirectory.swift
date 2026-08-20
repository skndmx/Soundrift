import Foundation

/// Control Center shows Apple TV / HomePod names. Core Audio only exposes a device
/// named "AirPlay". The real receiver name is advertised on Bonjour.
final class AirPlayReceiverDirectory: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    static let shared = AirPlayReceiverDirectory()
    static let lastEndpointNameKey = "AirPlayLastEndpointName"

    private let lock = NSLock()
    private var namesByMAC: [String: String] = [:]
    private var receiverNames: Set<String> = []
    private var lastPublished: Set<String> = []
    private var browsers: [NetServiceBrowser] = []
    private var resolving: [NetService] = []
    private var onChange: (() -> Void)?
    private var refreshWork: DispatchWorkItem?
    private var started = false

    private override init() {
        super.init()
    }

    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange
        guard !started else { return }
        started = true

        let raop = NetServiceBrowser()
        raop.delegate = self
        raop.searchForServices(ofType: "_raop._tcp.", inDomain: "local.")

        let airPlay = NetServiceBrowser()
        airPlay.delegate = self
        airPlay.searchForServices(ofType: "_airplay._tcp.", inDomain: "local.")

        browsers = [raop, airPlay]
    }

    func resolvedDisplayName(halName: String, uid: String, dataSourceName: String?) -> String {
        lock.lock()
        let byMAC = namesByMAC
        let remotes = remoteReceiverNamesLocked()
        lock.unlock()

        let resolved = AirPlayReceiverMatch.resolvedName(
            halName: halName,
            uid: uid,
            dataSourceName: dataSourceName,
            namesByMAC: byMAC,
            remoteReceiverNames: remotes,
            lastKnownName: UserDefaults.standard.string(forKey: Self.lastEndpointNameKey)
        )
        rememberIfNamed(resolved)
        return resolved
    }

    func preferredRemoteName() -> String? {
        lock.lock()
        let remotes = remoteReceiverNamesLocked()
        lock.unlock()
        let last = UserDefaults.standard.string(forKey: Self.lastEndpointNameKey)

        if remotes.count == 1 {
            rememberIfNamed(remotes[0])
            return remotes[0]
        }
        if let last, remotes.contains(where: { AudioDeviceMatch.namesMatch($0, last) }) {
            return last
        }
        if let last, remotes.isEmpty, !AirPlayEndpoint.isGenericDeviceName(last) {
            return last
        }
        return nil
    }

    private func rememberIfNamed(_ name: String) {
        guard !name.isEmpty, !AirPlayEndpoint.isGenericDeviceName(name) else { return }
        UserDefaults.standard.set(name, forKey: Self.lastEndpointNameKey)
    }

    private func remoteReceiverNamesLocked() -> [String] {
        let local = Self.localComputerNames()
        return receiverNames
            .filter { !AirPlayReceiverMatch.isLocalComputerName($0, localNames: local) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func localComputerNames() -> [String] {
        var names: [String] = []
        if let localized = Host.current().localizedName, !localized.isEmpty {
            names.append(localized)
        }
        let host = ProcessInfo.processInfo.hostName
        if !host.isEmpty {
            names.append(host)
            if let short = host.split(separator: ".").first {
                names.append(String(short))
            }
        }
        return names
    }

    private func addReceiver(name: String, mac: String?) {
        lock.lock()
        receiverNames.insert(name)
        if let mac {
            namesByMAC[mac] = name
        }
        let snapshot = Set(namesByMAC.values).union(receiverNames)
        let changed = snapshot != lastPublished
        if changed {
            lastPublished = snapshot
        }
        lock.unlock()
        guard changed else { return }
        scheduleChange()
    }

    private func removeReceiver(name: String) {
        lock.lock()
        receiverNames.remove(name)
        namesByMAC = namesByMAC.filter { $0.value != name }
        let snapshot = Set(namesByMAC.values).union(receiverNames)
        let changed = snapshot != lastPublished
        if changed {
            lastPublished = snapshot
        }
        lock.unlock()
        guard changed else { return }
        scheduleChange()
    }

    private func scheduleChange() {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if let raop = AirPlayReceiverMatch.parseRAOPInstance(service.name) {
            addReceiver(name: raop.name, mac: raop.mac)
            return
        }

        addReceiver(name: service.name, mac: nil)
        service.delegate = self
        service.resolve(withTimeout: 3)
        resolving.append(service)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        if let raop = AirPlayReceiverMatch.parseRAOPInstance(service.name) {
            removeReceiver(name: raop.name)
            return
        }
        removeReceiver(name: service.name)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        resolving.removeAll { $0 === sender }
        guard let txt = sender.txtRecordData(), !txt.isEmpty else { return }
        let dict = NetService.dictionary(fromTXTRecord: txt)
        guard let deviceIDData = dict["deviceid"] ?? dict["deviceID"],
              let deviceID = String(data: deviceIDData, encoding: .utf8),
              let mac = AirPlayReceiverMatch.normalizedMAC(deviceID) else {
            return
        }
        addReceiver(name: sender.name, mac: mac)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolving.removeAll { $0 === sender }
    }
}
