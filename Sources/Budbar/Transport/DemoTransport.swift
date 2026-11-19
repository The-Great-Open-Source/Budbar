// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SoundcoreProtocol

/// Pretends to be a pair of earbuds so the UI can be tried (and screenshotted) without hardware.
@MainActor
final class DemoConnector: BudsConnector {
    func pairedDevices() -> [BudsDevice] {
        [BudsDevice(id: "DE-MO-00-00-00-01", name: "Soundcore R60i NC (Demo)", isConnected: true)]
    }

    func connect(to device: BudsDevice, cycleBasebandOnTimeout: Bool) async throws -> BudsTransport {
        try await Task.sleep(for: .milliseconds(700))
        return DemoTransport()
    }
}

@MainActor
final class DemoTransport: BudsTransport {
    var onData: (([UInt8]) -> Void)?
    var onClose: (() -> Void)?

    private var parser = PacketStreamParser(direction: .outbound)
    private var state = StateUpdate(
        hostIsLeft: true,
        twsConnected: true,
        left: Battery(percent: 80),
        right: Battery(percent: 70),
        caseBattery: Battery(percent: 90),
        soundModes: SoundModes(ambient: .noiseCanceling, noiseCanceling: .adaptive)
    )

    func send(_ bytes: [UInt8]) throws {
        for packet in parser.append(bytes) {
            respond(to: packet)
        }
    }

    func close() {}

    private func respond(to packet: Packet) {
        switch packet.command {
        case D1202Packets.requestStateCommand:
            deliver(Packet(command: D1202Packets.stateUpdateCommand, body: D1202.buildStateBody(state)))
        case D1202Packets.setSoundModesCommand:
            if let modes = SoundModes(bytes: packet.body) {
                state.soundModes = modes
                deliver(Packet(command: D1202Packets.soundModesUpdateCommand, body: modes.bytes))
            }
        default:
            break
        }
    }

    private func deliver(_ packet: Packet) {
        let bytes = packet.encoded(direction: .inbound)
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            self.onData?(bytes)
        }
    }
}
