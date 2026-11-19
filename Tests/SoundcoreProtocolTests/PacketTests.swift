// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
@testable import SoundcoreProtocol

final class PacketTests: XCTestCase {
    // The two byte sequences below are the example packets from OpenSCQ30's own tests
    // (lib/src/devices/soundcore/common/packet/outbound/set_sound_modes.rs).
    func testEncodesNormalModeExample() {
        let packet = Packet(command: Command(0x06, 0x81), body: [0x02, 0x00, 0x01, 0x00])
        XCTAssertEqual(
            packet.encoded(),
            [0x08, 0xEE, 0x00, 0x00, 0x00, 0x06, 0x81, 0x0E, 0x00, 0x02, 0x00, 0x01, 0x00, 0x8E]
        )
    }

    func testEncodesNoiseCancelingExample() {
        let packet = Packet(command: Command(0x06, 0x81), body: [0x00, 0x01, 0x01, 0x00])
        XCTAssertEqual(
            packet.encoded(),
            [0x08, 0xEE, 0x00, 0x00, 0x00, 0x06, 0x81, 0x0E, 0x00, 0x00, 0x01, 0x01, 0x00, 0x8D]
        )
    }

    func testChecksumWraps() {
        XCTAssertEqual(checksum(of: []), 0)
        XCTAssertEqual(checksum(of: [1, 2]), 3)
        XCTAssertEqual(checksum(of: [0xFF, 0x02]), 0x01)
    }

    func testParsesInboundPacket() {
        var parser = PacketStreamParser(direction: .inbound)
        let packet = Packet(command: Command(0x06, 0x01), body: [1, 2, 3])
        XCTAssertEqual(parser.append(packet.encoded(direction: .inbound)), [packet])
    }

    func testReassemblesPacketSplitAcrossReads() {
        var parser = PacketStreamParser(direction: .inbound)
        let packet = Packet(command: Command(0x01, 0x01), body: Array(0..<40))
        let bytes = packet.encoded(direction: .inbound)
        XCTAssertEqual(parser.append(Array(bytes[0..<7])), [])
        XCTAssertEqual(parser.append(Array(bytes[7..<20])), [])
        XCTAssertEqual(parser.append(Array(bytes[20...])), [packet])
    }

    func testSplitsTwoPacketsInOneRead() {
        var parser = PacketStreamParser(direction: .inbound)
        let first = Packet(command: Command(0x06, 0x01), body: [9])
        let second = Packet(command: Command(0x01, 0x01), body: [7, 7])
        let bytes = first.encoded(direction: .inbound) + second.encoded(direction: .inbound)
        XCTAssertEqual(parser.append(bytes), [first, second])
    }

    func testSkipsGarbageBeforePacket() {
        var parser = PacketStreamParser(direction: .inbound)
        let packet = Packet(command: Command(0x06, 0x01), body: [4, 5])
        XCTAssertEqual(parser.append([0x00, 0x42, 0x09] + packet.encoded(direction: .inbound)), [packet])
    }

    func testDropsPacketWithBadChecksum() {
        var parser = PacketStreamParser(direction: .inbound)
        let good = Packet(command: Command(0x06, 0x01), body: [1])
        var bad = Packet(command: Command(0x06, 0x01), body: [2]).encoded(direction: .inbound)
        bad[bad.count - 1] = bad[bad.count - 1] &+ 1
        XCTAssertEqual(parser.append(bad + good.encoded(direction: .inbound)), [good])
    }

    func testOutboundDirectionIsNotMistakenForInbound() {
        var parser = PacketStreamParser(direction: .inbound)
        let outbound = Packet(command: Command(0x01, 0x01)).encoded(direction: .outbound)
        XCTAssertEqual(parser.append(outbound), [])
    }
}
