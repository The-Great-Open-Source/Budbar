// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct BudsDevice: Identifiable, Hashable {
    /// Bluetooth address as macOS writes it, for example "A4-C1-39-D6-27-F4".
    let id: String
    let name: String
    /// Whether the earbuds are currently connected to this Mac (audio link), not whether we have a control channel.
    let isConnected: Bool
}

enum BudsError: LocalizedError {
    case deviceNotFound
    case serviceNotFound
    case timedOut(String)
    case writeFailed(Int32)
    case closed
    case noResponse
    case unsupportedLayout

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Couldn't find the earbuds. Make sure they are on and connected to this Mac."
        case .serviceNotFound:
            return "The earbuds didn't offer a control channel. Try putting them in the case and taking them out."
        case .timedOut:
            return "The earbuds didn't answer. Disconnect them from your phone (and close the Soundcore app there), then try again."
        case .writeFailed(let code):
            return "Couldn't send a command to the earbuds (error \(code))."
        case .closed:
            return "The connection to the earbuds was closed."
        case .noResponse:
            return "Connected, but the earbuds didn't report their state."
        case .unsupportedLayout:
            return "These earbuds sent data in a layout Budbar doesn't understand yet."
        }
    }
}

/// A byte pipe to the earbuds. Everything runs on the main actor because IOBluetooth delivers
/// its callbacks on the main thread.
@MainActor
protocol BudsTransport: AnyObject {
    var onData: (([UInt8]) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }
    func send(_ bytes: [UInt8]) throws
    func close()
}

@MainActor
protocol BudsConnector {
    func pairedDevices() -> [BudsDevice]
    /// - Parameter cycleBasebandOnTimeout: If the control channel doesn't open, drop and re-open the
    ///   Bluetooth link once and retry. This makes the earbuds chime, so only do it when the user asked.
    func connect(to device: BudsDevice, cycleBasebandOnTimeout: Bool) async throws -> BudsTransport
}
