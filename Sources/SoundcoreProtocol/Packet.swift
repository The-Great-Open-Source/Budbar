// SPDX-License-Identifier: GPL-3.0-or-later
//
// Packet framing for Soundcore earbuds.
// The wire format was worked out by the OpenSCQ30 project (https://github.com/Oppzippy/OpenSCQ30)
// and this file follows it. See NOTICE.md.

import Foundation

public enum PacketDirection: Sendable {
    /// Host (this Mac) to earbuds.
    case outbound
    /// Earbuds to host.
    case inbound

    public var marker: [UInt8] {
        switch self {
        case .outbound: return [0x08, 0xEE, 0x00, 0x00, 0x00]
        case .inbound: return [0x09, 0xFF, 0x00, 0x00, 0x01]
        }
    }
}

public struct Command: Hashable, Sendable {
    public let high: UInt8
    public let low: UInt8

    public init(_ high: UInt8, _ low: UInt8) {
        self.high = high
        self.low = low
    }
}

/// Sum of all bytes, wrapping at 256.
public func checksum(of bytes: [UInt8]) -> UInt8 {
    bytes.reduce(0) { $0 &+ $1 }
}

public struct Packet: Equatable, Sendable {
    public var command: Command
    public var body: [UInt8]

    public init(command: Command, body: [UInt8] = []) {
        self.command = command
        self.body = body
    }

    /// Layout: direction marker (5) + command (2) + total length as little endian u16 (2) + body + checksum (1).
    /// The length covers the whole packet, checksum included.
    public func encoded(direction: PacketDirection = .outbound) -> [UInt8] {
        let length = 5 + 2 + 2 + body.count + 1
        var bytes = direction.marker
        bytes.append(command.high)
        bytes.append(command.low)
        bytes.append(UInt8(length & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(contentsOf: body)
        bytes.append(checksum(of: bytes))
        return bytes
    }
}

/// Reassembles packets from a byte stream that may split or merge them arbitrarily.
/// Garbage before a packet is skipped and packets with a bad checksum are dropped.
public struct PacketStreamParser {
    private var buffer: [UInt8] = []
    private let direction: PacketDirection
    private static let headerLength = 9
    private static let minimumLength = 10
    private static let maximumLength = 4096

    public init(direction: PacketDirection = .inbound) {
        self.direction = direction
    }

    public mutating func append(_ data: [UInt8]) -> [Packet] {
        buffer.append(contentsOf: data)
        var packets: [Packet] = []
        let marker = direction.marker

        while true {
            guard let start = indexOfMarker(marker) else {
                // Keep the tail in case a marker was split across two reads.
                if buffer.count > marker.count - 1 {
                    buffer.removeFirst(buffer.count - (marker.count - 1))
                }
                break
            }
            if start > 0 {
                buffer.removeFirst(start)
            }
            guard buffer.count >= Self.headerLength else { break }

            let length = Int(buffer[7]) | (Int(buffer[8]) << 8)
            if length < Self.minimumLength || length > Self.maximumLength {
                // Not a real header, skip this byte and look for the next marker.
                buffer.removeFirst(1)
                continue
            }
            guard buffer.count >= length else { break }

            let frame = Array(buffer[0..<length])
            buffer.removeFirst(length)

            let expected = checksum(of: Array(frame[0..<(length - 1)]))
            guard expected == frame[length - 1] else { continue }

            packets.append(
                Packet(
                    command: Command(frame[5], frame[6]),
                    body: Array(frame[Self.headerLength..<(length - 1)])
                )
            )
        }
        return packets
    }

    private func indexOfMarker(_ marker: [UInt8]) -> Int? {
        guard buffer.count >= marker.count else { return nil }
        for index in 0...(buffer.count - marker.count) {
            if Array(buffer[index..<(index + marker.count)]) == marker {
                return index
            }
        }
        return nil
    }
}
