// SPDX-License-Identifier: GPL-3.0-or-later
//
// Bluetooth classic RFCOMM transport on macOS (IOBluetooth).
// The connection sequence (baseband, SDP lookup, vendor service UUID, channel open, cycling the
// baseband once if the channel gets stuck) follows OpenSCQ30's macOS backend,
// lib/src/connection_backend/macos/rfcomm.rs. See NOTICE.md.

import Foundation
import IOBluetooth

private let sppUUID: [UInt8] = [
    0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB,
]
/// 0cf12d31-fac3-4553-bd80-d6832e700000, where the lowest 20 bits can be anything.
private let vendorUUID: [UInt8] = [
    0x0C, 0xF1, 0x2D, 0x31, 0xFA, 0xC3, 0x45, 0x53, 0xBD, 0x80, 0xD6, 0x83, 0x2E, 0x70, 0x00, 0x00,
]

private func isSoundcoreVendorUUID(_ uuid: [UInt8]) -> Bool {
    guard uuid.count == 16 else { return false }
    return Array(uuid[0..<13]) == Array(vendorUUID[0..<13]) && (uuid[13] & 0xF0) == (vendorUUID[13] & 0xF0)
}

@MainActor
final class RFCOMMConnector: BudsConnector {
    private var sdpDelegates: [SDPQueryDelegate] = []

    func pairedDevices() -> [BudsDevice] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            return BudsDevice(
                id: address,
                name: device.nameOrAddress ?? address,
                isConnected: device.isConnected()
            )
        }
    }

    func connect(to device: BudsDevice, cycleBasebandOnTimeout: Bool) async throws -> BudsTransport {
        guard let io = IOBluetoothDevice(addressString: device.id) else {
            throw BudsError.deviceNotFound
        }
        if !io.isConnected() {
            guard io.openConnection() == 0 else { throw BudsError.deviceNotFound }
        }

        let channelID = try await selectChannelID(for: io)

        do {
            let transport = RFCOMMTransport(device: io, channelID: channelID)
            try await transport.open()
            return transport
        } catch let error as BudsError {
            guard case .timedOut = error, cycleBasebandOnTimeout else { throw error }
            // The channel can get stuck "not open" until the baseband link is cycled once.
            try await cycleBaseband(io)
            let retry = RFCOMMTransport(device: io, channelID: channelID)
            try await retry.open()
            return retry
        }
    }

    // MARK: Baseband

    private func cycleBaseband(_ device: IOBluetoothDevice) async throws {
        _ = device.closeConnection()
        let deadline = Date().addingTimeInterval(5)
        while device.isConnected() {
            if Date() > deadline { throw BudsError.timedOut("closing the Bluetooth link") }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard device.openConnection() == 0 else { throw BudsError.deviceNotFound }
    }

    // MARK: Service lookup

    private func selectChannelID(for device: IOBluetoothDevice) async throws -> BluetoothRFCOMMChannelID {
        var records = cachedRecords(of: device)
        if records.isEmpty {
            // macOS only fills its SDP cache on demand. Not done on every connect because the query
            // can hang when repeated quickly.
            try await performSDPQuery(on: device)
            records = cachedRecords(of: device)
        }

        let uuids = records.flatMap { serviceClassUUIDs(of: $0) }
        let chosen = uuids.first(where: isSoundcoreVendorUUID) ?? sppUUID

        let record: IOBluetoothSDPServiceRecord? = chosen.withUnsafeBytes { raw in
            let sdpUUID = IOBluetoothSDPUUID(bytes: raw.baseAddress, length: raw.count)
            return device.getServiceRecord(for: sdpUUID)
        }
        guard let record else { throw BudsError.serviceNotFound }

        var channelID: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&channelID) == 0 else { throw BudsError.serviceNotFound }
        return channelID
    }

    private func cachedRecords(of device: IOBluetoothDevice) -> [IOBluetoothSDPServiceRecord] {
        (device.services as? [IOBluetoothSDPServiceRecord]) ?? []
    }

    /// Attribute 0x0001 is the ServiceClassIDList: the UUIDs a service record advertises.
    private func serviceClassUUIDs(of record: IOBluetoothSDPServiceRecord) -> [[UInt8]] {
        guard let element = record.getAttributeDataElement(0x0001) else { return [] }
        // A single UUID shows up as a bare UUID element rather than a one item array.
        if let uuid = element.getUUIDValue() {
            return [expandedBytes(of: uuid)].compactMap { $0 }
        }
        guard let items = element.getValue() as? [Any] else { return [] }
        return items.compactMap { item in
            guard let sub = item as? IOBluetoothSDPDataElement, let uuid = sub.getUUIDValue() else { return nil }
            return expandedBytes(of: uuid)
        }
    }

    /// IOBluetoothSDPUUID is an NSData. 16 and 32 bit UUIDs are expanded onto the Bluetooth base UUID.
    private func expandedBytes(of uuid: IOBluetoothSDPUUID) -> [UInt8]? {
        let raw = [UInt8](Data(referencing: uuid as NSData))
        switch raw.count {
        case 16: return raw
        case 4: return raw + Array(sppUUID[4...])
        case 2: return [0, 0] + raw + Array(sppUUID[4...])
        default: return nil
        }
    }

    private func performSDPQuery(on device: IOBluetoothDevice) async throws {
        let delegate = SDPQueryDelegate()
        // Kept alive for the life of the connector: the query can't be cancelled, so a late callback
        // must never land on a freed object.
        sdpDelegates.append(delegate)

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            var finished = false
            func finish(_ result: Result<Int32, Error>) {
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }
            delegate.completion = { finish(.success($0)) }
            if device.performSDPQuery(delegate) != 0 {
                finish(.failure(BudsError.serviceNotFound))
                return
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                finish(.failure(BudsError.timedOut("looking up services")))
            }
        }
        guard status == 0 else { throw BudsError.serviceNotFound }
    }
}

private final class SDPQueryDelegate: NSObject {
    var completion: ((Int32) -> Void)?

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        // IOBluetooth calls this on the main thread.
        let completion = self.completion
        self.completion = nil
        completion?(status)
    }
}

@MainActor
final class RFCOMMTransport: NSObject, BudsTransport {
    var onData: (([UInt8]) -> Void)?
    var onClose: (() -> Void)?

    private let device: IOBluetoothDevice
    private let channelID: BluetoothRFCOMMChannelID
    private var channel: IOBluetoothRFCOMMChannel?
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var isOpen = false

    init(device: IOBluetoothDevice, channelID: BluetoothRFCOMMChannelID) {
        self.device = device
        self.channelID = channelID
        super.init()
    }

    func open() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            openContinuation = continuation
            var opened: IOBluetoothRFCOMMChannel?
            let status = device.openRFCOMMChannelAsync(&opened, withChannelID: channelID, delegate: self)
            if status != 0 {
                finishOpen(.failure(BudsError.deviceNotFound))
                return
            }
            channel = opened
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                self?.finishOpen(.failure(BudsError.timedOut("opening the control channel")))
            }
        }
        isOpen = true
    }

    private func finishOpen(_ result: Result<Void, Error>) {
        guard let continuation = openContinuation else { return }
        openContinuation = nil
        if case .failure = result {
            channel?.close()
            channel = nil
        }
        continuation.resume(with: result)
    }

    func send(_ bytes: [UInt8]) throws {
        guard isOpen, let channel else { throw BudsError.closed }
        var copy = bytes
        let status = copy.withUnsafeMutableBytes { raw in
            channel.writeSync(raw.baseAddress, length: UInt16(raw.count))
        }
        guard status == 0 else { throw BudsError.writeFailed(status) }
    }

    func close() {
        isOpen = false
        onData = nil
        onClose = nil
        channel?.close()
        channel = nil
    }

    // MARK: IOBluetoothRFCOMMChannel delegate callbacks (selectors match IOBluetoothRFCOMMChannelDelegate)

    @objc nonisolated func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        Task { @MainActor in
            self.finishOpen(error == 0 ? .success(()) : .failure(BudsError.deviceNotFound))
        }
    }

    @objc nonisolated func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!,
        data dataPointer: UnsafeMutableRawPointer!,
        length dataLength: Int
    ) {
        // Copy now: the pointer is only valid during this call.
        let bytes = Array(UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength))
        Task { @MainActor in
            self.onData?(bytes)
        }
    }

    @objc nonisolated func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        Task { @MainActor in
            guard self.isOpen else { return }
            self.isOpen = false
            self.onClose?()
        }
    }
}
