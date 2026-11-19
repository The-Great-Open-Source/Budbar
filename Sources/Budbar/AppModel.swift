// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import ServiceManagement
import SoundcoreProtocol
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case waitingForDevice
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase = .waitingForDevice
    @Published private(set) var devices: [BudsDevice] = []
    @Published private(set) var selectedDevice: BudsDevice?
    @Published private(set) var state: StateUpdate?
    @Published private(set) var demoMode: Bool

    private var connector: BudsConnector
    private var transport: BudsTransport?
    private var parser = PacketStreamParser(direction: .inbound)
    private var failureCount = 0
    private var lastStateRequest = Date.distantPast
    private var supervisor: Task<Void, Never>?

    private static let deviceKey = "selectedDeviceID"
    private static let demoKey = "demoMode"

    init() {
        let demo = ProcessInfo.processInfo.arguments.contains("--demo")
            || UserDefaults.standard.bool(forKey: Self.demoKey)
        demoMode = demo
        connector = demo ? DemoConnector() : RFCOMMConnector()
        refreshDevices()
        supervisor = Task { await self.supervise() }
    }

    // MARK: Derived values for the views

    var isConnected: Bool { phase == .connected && state != nil }

    var deviceTitle: String {
        guard let name = selectedDevice?.name else { return "Budbar" }
        return name.replacingOccurrences(of: "Soundcore ", with: "")
    }

    var statusText: String {
        switch phase {
        case .waitingForDevice: return "Not connected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .failed: return "Can't connect"
        }
    }

    var statusColor: Color {
        switch phase {
        case .connected: return .green
        case .connecting: return .orange
        case .waitingForDevice: return .gray
        case .failed: return .red
        }
    }

    var menuBarSymbol: String {
        guard isConnected, let modes = state?.soundModes else { return "earbuds" }
        switch modes.ambient {
        case .noiseCanceling: return "waveform.slash"
        case .transparency: return "ear.and.waveform"
        case .normal: return "earbuds"
        }
    }

    // MARK: Devices and connection

    func refreshDevices() {
        devices = connector.pairedDevices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let savedID = UserDefaults.standard.string(forKey: Self.deviceKey)
        let likely = devices.first {
            $0.name.range(of: "soundcore|r60i|p31i", options: [.regularExpression, .caseInsensitive]) != nil
        }
        selectedDevice = devices.first(where: { $0.id == savedID }) ?? likely
    }

    func select(deviceID: String) {
        UserDefaults.standard.set(deviceID, forKey: Self.deviceKey)
        disconnect()
        refreshDevices()
        Task { await attemptConnect(manual: true) }
    }

    /// Manual retry from the UI. Allowed to cycle the Bluetooth link if the channel is stuck.
    func retry() {
        failureCount = 0
        Task { await attemptConnect(manual: true) }
    }

    func setDemoMode(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.demoKey)
        disconnect()
        demoMode = on
        connector = on ? DemoConnector() : RFCOMMConnector()
        failureCount = 0
        refreshDevices()
        Task { await attemptConnect(manual: true) }
    }

    private func supervise() async {
        while !Task.isCancelled {
            switch phase {
            case .waitingForDevice, .failed:
                await attemptConnect(manual: false)
            case .connected:
                if Date().timeIntervalSince(lastStateRequest) > 60 {
                    requestState()
                }
            case .connecting:
                break
            }
            // Back off after failures so we don't keep poking earbuds that are busy with another device.
            let seconds = min(4 * (1 << min(failureCount, 4)), 60)
            try? await Task.sleep(for: .seconds(seconds))
        }
    }

    private func attemptConnect(manual: Bool) async {
        guard phase != .connecting else { return }
        refreshDevices()
        guard let device = selectedDevice else {
            phase = .waitingForDevice
            return
        }
        if !manual && !device.isConnected {
            phase = .waitingForDevice
            return
        }

        phase = .connecting
        do {
            let transport = try await connector.connect(to: device, cycleBasebandOnTimeout: manual)
            adopt(transport)
            requestState()
            watchForFirstState()
        } catch {
            fail(error)
        }
    }

    private func adopt(_ transport: BudsTransport) {
        self.transport?.close()
        self.transport = transport
        parser = PacketStreamParser(direction: .inbound)
        transport.onData = { [weak self] bytes in self?.handle(bytes) }
        transport.onClose = { [weak self] in self?.connectionClosed() }
    }

    private func watchForFirstState() {
        Task {
            try? await Task.sleep(for: .seconds(6))
            if phase == .connecting {
                fail(BudsError.noResponse)
            }
        }
    }

    private func disconnect() {
        transport?.close()
        transport = nil
        state = nil
        phase = .waitingForDevice
    }

    private func connectionClosed() {
        transport = nil
        state = nil
        phase = .waitingForDevice
    }

    private func fail(_ error: Error) {
        transport?.close()
        transport = nil
        state = nil
        failureCount += 1
        phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    // MARK: Packets

    private func requestState() {
        lastStateRequest = Date()
        send(D1202Packets.requestState)
    }

    private func send(_ packet: Packet) {
        do {
            try transport?.send(packet.encoded())
        } catch {
            fail(error)
        }
    }

    private func handle(_ bytes: [UInt8]) {
        for packet in parser.append(bytes) {
            switch packet.command {
            case D1202Packets.stateUpdateCommand:
                guard let update = D1202.parseStateUpdate(body: packet.body) else {
                    fail(BudsError.unsupportedLayout)
                    return
                }
                state = update
                failureCount = 0
                phase = .connected
            case D1202Packets.soundModesUpdateCommand:
                if var current = state, let modes = SoundModes(bytes: packet.body) {
                    current.soundModes = modes
                    state = current
                }
            default:
                break
            }
        }
    }

    // MARK: Changing settings

    /// Updates the screen right away, then tells the earbuds. The earbuds' own reply corrects us if they disagree.
    func update(_ change: (inout SoundModes) -> Void) {
        guard var current = state, phase == .connected else { return }
        var modes = current.soundModes
        change(&modes)
        guard modes != current.soundModes else { return }
        current.soundModes = modes
        state = current
        send(D1202Packets.setSoundModes(modes))
    }

    func hapticTick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Budbar: launch at login failed: \(error.localizedDescription)")
        }
        objectWillChange.send()
    }
}
