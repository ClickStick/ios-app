import CryptoKit
import Foundation
import Testing
@testable import ClickStickKit

struct CSDeviceStateTransitionTests {
    @Test
    func initSessionEchoCompletesStartSessionWithoutStartingAnotherOne() throws {
        let device = TestDevice(uuid: UUID())
        let appAuthKey = CSAppAuthKey.demo
        let donglePrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let sessionData = CSDeviceSession.make(
            publicKey: donglePrivateKey.publicKey,
            appAuthKey: appAuthKey
        )

        device._appAuthKey = appAuthKey
        device._connectionState = .connectedUnauthorized
        device._deviceState = .initSession
        device.statusData = sessionData

        device._startSession()
        #expect(device.sentPackets.count == 1)

        device._didReceiveStatusData(sessionData)

        #expect(device.connectionState == .connectedAuthorized)
        #expect(device.sentPackets.count == 1)

        device._didReceiveStatusData(sessionData)

        #expect(device.connectionState == .connectedAuthorized)
        #expect(device.sentPackets.count == 1)
    }
}

private final class TestDevice: CSDevice {
    var statusData: Data?
    private(set) var sentPackets: [Data] = []

    override var _maxOutgoingPacketSize: Int { 226 }

    override func _requestRSSIRefresh() {}
    override func _startConnection() {}
    override func _startServiceDiscovery() {}
    override func _readDeviceStatusChannel() -> Data? { statusData }
    override func _requestStatusUpdate() {}

    override func _writeToCommandChannel(_ packet: Data) {
        sentPackets.append(packet)
        _didWriteToCommandChannel(error: nil)
    }

    override func _endConnection() {}
}
