// SPDX-License-Identifier: GPL-3.0-or-later
//
// Message layout for the Soundcore "D1202" family: P31i (D1202) and R60i NC (D1202C).
// Field offsets and command codes follow OpenSCQ30 (https://github.com/Oppzippy/OpenSCQ30),
// see lib/src/devices/soundcore/d1202. See NOTICE.md.

import Foundation

public enum AmbientSoundMode: UInt8, CaseIterable, Identifiable, Sendable {
    case noiseCanceling = 0
    case transparency = 1
    case normal = 2

    public var id: UInt8 { rawValue }
}

public enum NoiseCancelingMode: UInt8, CaseIterable, Identifiable, Sendable {
    case manual = 0
    case adaptive = 1
    case multiScene = 2

    public var id: UInt8 { rawValue }
}

public enum TransparencyMode: UInt8, CaseIterable, Identifiable, Sendable {
    case fullyTransparent = 0
    case vocal = 1

    public var id: UInt8 { rawValue }
}

public enum MultiSceneMode: UInt8, CaseIterable, Identifiable, Sendable {
    case transport = 0
    case outdoor = 1
    case indoor = 2

    public var id: UInt8 { rawValue }
}

/// The eight "sound modes" bytes. The same bytes are used when reading state and when setting it.
public struct SoundModes: Equatable, Sendable {
    public var ambient: AmbientSoundMode
    public var noiseCanceling: NoiseCancelingMode
    public var transparency: TransparencyMode
    public var multiScene: MultiSceneMode
    /// 1 (weak) to 5 (strong). Used when `noiseCanceling` is `.manual`.
    public var manualStrength: UInt8
    public var windNoiseSuppression: Bool
    public var windNoiseDetected: Bool
    public var realTimeAdaptive: Bool
    /// Low nibble of byte 1. Reported by the earbuds, kept as is and sent back unchanged.
    public var adaptiveRaw: UInt8
    /// Byte 5, purpose unknown. Kept as is and sent back unchanged.
    public var unknownByte: UInt8

    public static let byteCount = 8

    public init(
        ambient: AmbientSoundMode = .noiseCanceling,
        noiseCanceling: NoiseCancelingMode = .adaptive,
        transparency: TransparencyMode = .fullyTransparent,
        multiScene: MultiSceneMode = .transport,
        manualStrength: UInt8 = 3,
        windNoiseSuppression: Bool = false,
        windNoiseDetected: Bool = false,
        realTimeAdaptive: Bool = false,
        adaptiveRaw: UInt8 = 0,
        unknownByte: UInt8 = 0
    ) {
        self.ambient = ambient
        self.noiseCanceling = noiseCanceling
        self.transparency = transparency
        self.multiScene = multiScene
        self.manualStrength = min(max(manualStrength, 1), 5)
        self.windNoiseSuppression = windNoiseSuppression
        self.windNoiseDetected = windNoiseDetected
        self.realTimeAdaptive = realTimeAdaptive
        self.adaptiveRaw = adaptiveRaw & 0x0F
        self.unknownByte = unknownByte
    }

    /// Returns nil if the bytes are too short or the ambient mode byte is out of range,
    /// which usually means the packet layout is not the one we expect.
    public init?(bytes: [UInt8]) {
        guard bytes.count >= Self.byteCount,
              let ambient = AmbientSoundMode(rawValue: bytes[0])
        else { return nil }
        self.init(
            ambient: ambient,
            noiseCanceling: NoiseCancelingMode(rawValue: bytes[3]) ?? .manual,
            transparency: TransparencyMode(rawValue: bytes[2]) ?? .fullyTransparent,
            multiScene: MultiSceneMode(rawValue: bytes[6]) ?? .transport,
            manualStrength: bytes[1] >> 4,
            windNoiseSuppression: bytes[4] & 1 != 0,
            windNoiseDetected: bytes[4] & 2 != 0,
            realTimeAdaptive: bytes[7] != 0,
            adaptiveRaw: bytes[1] & 0x0F,
            unknownByte: bytes[5]
        )
    }

    public var bytes: [UInt8] {
        [
            ambient.rawValue,
            (manualStrength << 4) | (adaptiveRaw & 0x0F),
            transparency.rawValue,
            noiseCanceling.rawValue,
            (windNoiseSuppression ? 1 : 0) | (windNoiseDetected ? 2 : 0),
            unknownByte,
            multiScene.rawValue,
            realTimeAdaptive ? 1 : 0,
        ]
    }
}

public struct Battery: Equatable, Sendable {
    /// 10 to 100 in steps of 10. The earbuds report ten levels.
    public var percent: Int
    public var isCharging: Bool

    public init(percent: Int, isCharging: Bool = false) {
        self.percent = percent
        self.isCharging = isCharging
    }
}

public struct StateUpdate: Equatable, Sendable {
    public var hostIsLeft: Bool
    public var twsConnected: Bool
    /// nil when that earbud is not present (reported as 255).
    public var left: Battery?
    public var right: Battery?
    public var caseBattery: Battery?
    public var soundModes: SoundModes

    public init(
        hostIsLeft: Bool = true,
        twsConnected: Bool = true,
        left: Battery? = nil,
        right: Battery? = nil,
        caseBattery: Battery? = nil,
        soundModes: SoundModes = SoundModes()
    ) {
        self.hostIsLeft = hostIsLeft
        self.twsConnected = twsConnected
        self.left = left
        self.right = right
        self.caseBattery = caseBattery
        self.soundModes = soundModes
    }
}

public enum D1202 {
    /// Offsets into the body of a state update packet (command 0x01 0x01).
    /// Derived by adding up the field sizes of OpenSCQ30's D1202StateUpdatePacket:
    /// tws 2, battery 4, firmware 10, serial 16, unknown 5, case battery 1, equalizer 22,
    /// unknown 1, hear id 48, unknown 1, buttons 8, unknown 1, then the sound modes.
    public enum Layout {
        public static let hostDevice = 0
        public static let twsConnected = 1
        public static let leftLevel = 2
        public static let rightLevel = 3
        public static let leftCharging = 4
        public static let rightCharging = 5
        public static let caseLevel = 37
        public static let soundModes = 119
        public static let minimumStateLength = soundModes + SoundModes.byteCount
    }

    static let absentLevel: UInt8 = 255

    /// Levels are 0...9 on the wire, shown as 10...100 percent.
    static func battery(level: UInt8, charging: UInt8?) -> Battery? {
        guard level != absentLevel else { return nil }
        let percent = min(Int(level) + 1, 10) * 10
        return Battery(percent: percent, isCharging: charging == 1)
    }

    static func rawLevel(for battery: Battery?) -> UInt8 {
        guard let battery else { return absentLevel }
        return UInt8(max(0, min(9, battery.percent / 10 - 1)))
    }

    public static func parseStateUpdate(body: [UInt8]) -> StateUpdate? {
        guard body.count >= Layout.minimumStateLength,
              let modes = SoundModes(
                  bytes: Array(body[Layout.soundModes..<(Layout.soundModes + SoundModes.byteCount)])
              )
        else { return nil }

        return StateUpdate(
            hostIsLeft: body[Layout.hostDevice] == 0,
            twsConnected: body[Layout.twsConnected] != 0,
            left: battery(level: body[Layout.leftLevel], charging: body[Layout.leftCharging]),
            right: battery(level: body[Layout.rightLevel], charging: body[Layout.rightCharging]),
            caseBattery: battery(level: body[Layout.caseLevel], charging: nil),
            soundModes: modes
        )
    }

    /// Builds a state update body. Used by demo mode and by the tests; real earbuds send many more fields,
    /// which are left zeroed here.
    public static func buildStateBody(_ state: StateUpdate) -> [UInt8] {
        var body = [UInt8](repeating: 0, count: Layout.minimumStateLength + 8)
        body[Layout.hostDevice] = state.hostIsLeft ? 0 : 1
        body[Layout.twsConnected] = state.twsConnected ? 1 : 0
        body[Layout.leftLevel] = rawLevel(for: state.left)
        body[Layout.rightLevel] = rawLevel(for: state.right)
        body[Layout.leftCharging] = (state.left?.isCharging ?? false) ? 1 : 0
        body[Layout.rightCharging] = (state.right?.isCharging ?? false) ? 1 : 0
        body[Layout.caseLevel] = rawLevel(for: state.caseBattery)
        let modeBytes = state.soundModes.bytes
        for (offset, byte) in modeBytes.enumerated() {
            body[Layout.soundModes + offset] = byte
        }
        return body
    }
}

public enum D1202Packets {
    public static let requestStateCommand = Command(0x01, 0x01)
    public static let stateUpdateCommand = Command(0x01, 0x01)
    public static let setSoundModesCommand = Command(0x06, 0x81)
    public static let soundModesUpdateCommand = Command(0x06, 0x01)

    public static var requestState: Packet {
        Packet(command: requestStateCommand)
    }

    public static func setSoundModes(_ modes: SoundModes) -> Packet {
        Packet(command: setSoundModesCommand, body: modes.bytes)
    }
}
