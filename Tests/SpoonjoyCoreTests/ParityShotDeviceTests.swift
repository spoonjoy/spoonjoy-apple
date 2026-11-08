import Testing
@testable import SpoonjoyCore

@Suite("Parity shot device")
struct ParityShotDeviceTests {
    @Test("the simulator model decides, whatever idiom the runner reports")
    func simulatorModelWins() {
        #expect(ParityShotDevice.name(simulatorModelIdentifier: "iPad16,3", idiomIsPad: false) == "ipad")
        #expect(ParityShotDevice.name(simulatorModelIdentifier: "iPhone18,1", idiomIsPad: true) == "iphone")
    }

    @Test("without a simulator model the idiom decides")
    func idiomFallback() {
        #expect(ParityShotDevice.name(simulatorModelIdentifier: nil, idiomIsPad: true) == "ipad")
        #expect(ParityShotDevice.name(simulatorModelIdentifier: "", idiomIsPad: false) == "iphone")
    }

    @Test("a model that is neither iPhone nor iPad is named iphone, the default canvas")
    func unrecognisedModel() {
        #expect(ParityShotDevice.name(simulatorModelIdentifier: "Mac14,2", idiomIsPad: true) == "iphone")
        #expect(ParityShotDevice.name(simulatorModelIdentifier: "arm64", idiomIsPad: false) == "iphone")
    }
}
