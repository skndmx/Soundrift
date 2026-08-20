import Testing
@testable import Soundrift

struct AudioDeviceSelectionTests {
    @Test func normalizesCurlyApostrophesInDeviceNames() {
        #expect(AudioDeviceMatch.namesMatch("Kevin’s AirPods Pro", "Kevin's AirPods Pro"))
        #expect(!AudioDeviceMatch.namesMatch("Kevin's AirPods Pro", "Kevin's AirPods Pro Hands-Free"))
    }

    @Test func detectsHandsFreeProfileNames() {
        #expect(AudioDeviceMatch.isHandsFreeProfile(name: "AirPods Pro Hands-Free"))
        #expect(AudioDeviceMatch.isHandsFreeProfile(name: "WH-1000XM5 Headset"))
        #expect(!AudioDeviceMatch.isHandsFreeProfile(name: "Kevin's AirPods Pro"))
    }

    @Test func prefersStereoA2DPOverHandsFreeForOutput() {
        let handsFree = AudioDeviceMatch.outputRank(
            name: "AirPods Pro Hands-Free",
            canBeDefault: true,
            outputChannels: 1,
            sampleRate: 16_000
        )
        let stereo = AudioDeviceMatch.outputRank(
            name: "AirPods Pro",
            canBeDefault: true,
            outputChannels: 2,
            sampleRate: 44_100
        )
        #expect(stereo > handsFree)
    }

    @Test func prefersHigherSampleRateWhenNamesMatch() {
        let hfp = AudioDeviceMatch.outputRank(
            name: "Kevin's AirPods Pro",
            canBeDefault: true,
            outputChannels: 1,
            sampleRate: 16_000
        )
        let a2dp = AudioDeviceMatch.outputRank(
            name: "Kevin's AirPods Pro",
            canBeDefault: true,
            outputChannels: 2,
            sampleRate: 48_000
        )
        #expect(a2dp > hfp)
    }

    @Test func prefersHandsFreeEndpointForInput() {
        let stereo = AudioDeviceMatch.inputRank(
            name: "AirPods Pro",
            canBeDefault: true,
            inputChannels: 0
        )
        let handsFree = AudioDeviceMatch.inputRank(
            name: "AirPods Pro Hands-Free",
            canBeDefault: true,
            inputChannels: 1
        )
        #expect(handsFree > stereo)
    }

    @Test func bluetoothAirPodsInCaseAreDisconnected() {
        let connected = AudioDeviceAvailability.isConnected(
            isAlive: true,
            isBluetooth: true,
            jackUnplugged: false,
            canBeDefaultOutput: false,
            canBeDefaultInput: false,
            isOutput: true,
            isInput: true
        )
        #expect(!connected)
    }

    @Test func bluetoothAirPodsStayConnectedWhileDefaultable() {
        let connected = AudioDeviceAvailability.isConnected(
            isAlive: true,
            isBluetooth: true,
            jackUnplugged: false,
            canBeDefaultOutput: true,
            canBeDefaultInput: true,
            isOutput: true,
            isInput: true
        )
        #expect(connected)
    }

    @Test func builtInSpeakersStayConnectedWithoutDefaultableFlag() {
        let connected = AudioDeviceAvailability.isConnected(
            isAlive: true,
            isBluetooth: false,
            jackUnplugged: false,
            canBeDefaultOutput: false,
            canBeDefaultInput: false,
            isOutput: true,
            isInput: false
        )
        #expect(connected)
    }

    @Test func analogJackUnpluggedIsDisconnected() {
        let connected = AudioDeviceAvailability.isConnected(
            isAlive: true,
            isBluetooth: false,
            jackUnplugged: true,
            canBeDefaultOutput: true,
            canBeDefaultInput: nil,
            isOutput: true,
            isInput: false
        )
        #expect(!connected)
    }

    @Test func glyphForBuiltInSpeakers() {
        let device = AudioDevice(previewWithName: "MacBook Pro Speakers")
        #expect(device.glyphSystemName(kind: .output) == "laptopcomputer")
    }

    @Test func glyphForHeadphones() {
        let device = AudioDevice(previewWithName: "External Headphones")
        #expect(device.glyphSystemName(kind: .output) == "headphones")
    }

    @Test func glyphUsesAirPodsProProductIDEvenWhenRenamed() {
        var device = AudioDevice(previewWithName: "🐼")
        device.bluetoothProductID = 0x200E
        #expect(device.glyphSystemName(kind: .output) == "airpods.pro")
    }

    @Test func glyphUsesAirPodsMaxProductID() {
        #expect(NativeAudioDeviceIcon.symbolName(forProductID: 0x200A) == "airpods.max")
    }

    @Test func glyphUsesAirPods4ProductID() {
        #expect(NativeAudioDeviceIcon.symbolName(forProductID: 0x2027) == "airpods.gen4")
    }

    @Test func genericBluetoothHeadphonesUseHeadphonesIcon() {
        var device = AudioDevice(previewWithName: "WH-1000XM5")
        device.isBluetooth = true
        #expect(device.glyphSystemName(kind: .output) == "headphones")
    }

    @Test func glyphForHomePod() {
        let device = AudioDevice(previewWithName: "HomePod mini")
        #expect(device.glyphSystemName(kind: .output) == "homepod.mini.fill")
    }

    @Test func glyphForBeatsByName() {
        let device = AudioDevice(previewWithName: "Beats Studio Buds")
        #expect(device.glyphSystemName(kind: .output) == "beats.studiobuds")
    }

    @Test func airPlayUsesDataSourceNameInsteadOfGenericHALName() {
        #expect(AirPlayEndpoint.displayName(halName: "AirPlay", dataSourceName: "客厅") == "客厅")
        #expect(AirPlayEndpoint.displayName(halName: "AirPlay", dataSourceName: "  客厅  ") == "客厅")
        #expect(AirPlayEndpoint.displayName(halName: "AirPlay", dataSourceName: "AirPlay") == "AirPlay")
        #expect(AirPlayEndpoint.isGenericDeviceName("AirPlay"))
        #expect(AirPlayEndpoint.displayName(halName: "AirPlay", dataSourceName: "   ") == "AirPlay")
        #expect(AirPlayEndpoint.isGenericDeviceName("AirPlay"))
        #expect(AirPlayEndpoint.isGenericDeviceName("airplay"))
        #expect(!AirPlayEndpoint.isGenericDeviceName("客厅"))
    }

    @Test func airPlayEndpointsMatchByReceiverNameNotSharedHALUID() {
        var livingRoom = AudioDevice(previewWithName: "客厅")
        livingRoom.isAirPlay = true
        livingRoom.uid = "AirPlay-UID"
        livingRoom.id = 42

        var generic = AudioDevice(previewWithName: "AirPlay")
        generic.isAirPlay = true
        generic.uid = "AirPlay-UID"
        generic.id = 42

        var otherRoom = AudioDevice(previewWithName: "Bedroom")
        otherRoom.isAirPlay = true
        otherRoom.uid = "AirPlay-UID"
        otherRoom.id = 42

        #expect(livingRoom.isSameAudioEndpoint(as: generic) == false)
        #expect(livingRoom.isSameAudioEndpoint(as: otherRoom) == false)

        var livingRoomAgain = AudioDevice(previewWithName: "客厅")
        livingRoomAgain.isAirPlay = true
        livingRoomAgain.uid = "AirPlay-UID"
        livingRoomAgain.id = 99
        #expect(livingRoom.isSameAudioEndpoint(as: livingRoomAgain))
    }

    @Test func parsesRAOPInstanceIntoMACAndReceiverName() {
        let parsed = AirPlayReceiverMatch.parseRAOPInstance("9297D2C4CD3A@客厅")
        #expect(parsed?.mac == "9297D2C4CD3A")
        #expect(parsed?.name == "客厅")
        #expect(AirPlayReceiverMatch.parseRAOPInstance("客厅") == nil)
    }

    @Test func resolvesGenericAirPlayNameFromBonjourMACOrSoleReceiver() {
        let byMAC = ["9297D2C4CD3A": "客厅"]
        #expect(
            AirPlayReceiverMatch.resolvedName(
                halName: "AirPlay",
                uid: "92:97:D2:C4:CD:3A",
                dataSourceName: "AirPlay",
                namesByMAC: byMAC,
                remoteReceiverNames: ["客厅", "Bedroom"],
                lastKnownName: nil
            ) == "客厅"
        )
        #expect(
            AirPlayReceiverMatch.resolvedName(
                halName: "AirPlay",
                uid: "AirPlay",
                dataSourceName: nil,
                namesByMAC: [:],
                remoteReceiverNames: ["客厅"],
                lastKnownName: nil
            ) == "客厅"
        )
        #expect(
            AirPlayReceiverMatch.resolvedName(
                halName: "AirPlay",
                uid: "AirPlay",
                dataSourceName: nil,
                namesByMAC: [:],
                remoteReceiverNames: [],
                lastKnownName: "客厅"
            ) == "客厅"
        )
    }

    @Test func microsoftTeamsIsNotAppleTVIcon() {
        var device = AudioDevice(previewWithName: "Microsoft Teams Audio")
        device.isAirPlay = true
        #expect(device.glyphSystemName(kind: .output) == "cable.connector")
    }
}
