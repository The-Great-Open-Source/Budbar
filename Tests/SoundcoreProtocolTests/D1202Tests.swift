// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import SoundcoreProtocol

final class D1202Tests: XCTestCase {
    private let sample = SoundModes(
        ambient: .normal,
        noiseCanceling: .adaptive,
        transparency: .vocal,
        multiScene: .outdoor,
        manualStrength: 3,
        windNoiseSuppression: true,
        windNoiseDetected: false,
        realTimeAdaptive: true
    )

    func testSoundModesBytes() {
        // ambient, manual<<4 | adaptive, transparency, nc mode, wind, unknown, multi scene, real time adaptive
        XCTAssertEqual(sample.bytes, [2, 0x30, 1, 1, 0x01, 0, 1, 1])
    }

    func testSoundModesRoundTrip() {
        XCTAssertEqual(SoundModes(bytes: sample.bytes), sample)
    }

    func testSoundModesRejectsOutOfRangeAmbientByte() {
        XCTAssertNil(SoundModes(bytes: [9, 0x30, 0, 0, 0, 0, 0, 0]))
        XCTAssertNil(SoundModes(bytes: [0, 0]))
    }

    func testManualStrengthIsClamped() {
        XCTAssertEqual(SoundModes(manualStrength: 0).manualStrength, 1)
        XCTAssertEqual(SoundModes(manualStrength: 9).manualStrength, 5)
    }

    func testSetSoundModesPacketBytes() {
        // 5 marker + 2 command + 2 length + 8 body + 1 checksum = 18 (0x12)
        XCTAssertEqual(
            D1202Packets.setSoundModes(sample).encoded(),
            [0x08, 0xEE, 0x00, 0x00, 0x00, 0x06, 0x81, 0x12, 0x00,
             2, 0x30, 1, 1, 0x01, 0, 1, 1, 0xC6]
        )
    }

    func testRequestStatePacketBytes() {
        // 5 + 2 + 2 + 0 + 1 = 10
        XCTAssertEqual(
            D1202Packets.requestState.encoded(),
            [0x08, 0xEE, 0x00, 0x00, 0x00, 0x01, 0x01, 0x0A, 0x00, 0x02]
        )
    }

    func testStateUpdateRoundTrip() {
        let state = StateUpdate(
            hostIsLeft: false,
            twsConnected: true,
            left: Battery(percent: 80, isCharging: true),
            right: Battery(percent: 100, isCharging: false),
            caseBattery: Battery(percent: 30),
            soundModes: sample
        )
        XCTAssertEqual(D1202.parseStateUpdate(body: D1202.buildStateBody(state)), state)
    }

    func testAbsentEarbudIsReportedAsNil() {
        let state = StateUpdate(
            left: Battery(percent: 50),
            right: nil,
            caseBattery: nil,
            soundModes: sample
        )
        let parsed = D1202.parseStateUpdate(body: D1202.buildStateBody(state))
        XCTAssertNotNil(parsed?.left)
        XCTAssertNil(parsed?.right)
        XCTAssertNil(parsed?.caseBattery)
    }

    func testTooShortStateBodyIsRejected() {
        XCTAssertNil(D1202.parseStateUpdate(body: [UInt8](repeating: 0, count: 100)))
    }

    func testBatteryLevelsMapToTenPercentSteps() {
        XCTAssertEqual(D1202.battery(level: 0, charging: 0)?.percent, 10)
        XCTAssertEqual(D1202.battery(level: 9, charging: 1)?.percent, 100)
        XCTAssertEqual(D1202.battery(level: 9, charging: 1)?.isCharging, true)
        XCTAssertNil(D1202.battery(level: 255, charging: 0))
    }

    func testStateBodyLayoutPutsSoundModesAtExpectedOffset() {
        let body = D1202.buildStateBody(StateUpdate(soundModes: sample))
        XCTAssertEqual(Array(body[119..<127]), sample.bytes)
    }
}
