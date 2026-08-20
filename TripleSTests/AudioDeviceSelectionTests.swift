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
}
