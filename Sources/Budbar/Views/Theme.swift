// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

extension AmbientSoundMode {
    var title: String {
        switch self {
        case .noiseCanceling: return "Noise Cancelling"
        case .transparency: return "Transparency"
        case .normal: return "Normal"
        }
    }

    var symbol: String {
        switch self {
        case .noiseCanceling: return "waveform.slash"
        case .transparency: return "ear.and.waveform"
        case .normal: return "speaker.wave.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .noiseCanceling: return Color(red: 0.20, green: 0.48, blue: 1.0)
        case .transparency: return Color(red: 1.0, green: 0.58, blue: 0.10)
        case .normal: return Color(red: 0.45, green: 0.47, blue: 0.52)
        }
    }

    var shortcutKey: Character {
        switch self {
        case .noiseCanceling: return "1"
        case .transparency: return "2"
        case .normal: return "3"
        }
    }
}

extension NoiseCancelingMode {
    var title: String {
        switch self {
        case .adaptive: return "Adaptive"
        case .manual: return "Manual"
        case .multiScene: return "Scenes"
        }
    }
}

extension TransparencyMode {
    var title: String {
        switch self {
        case .fullyTransparent: return "Fully transparent"
        case .vocal: return "Vocal"
        }
    }
}

extension MultiSceneMode {
    var title: String {
        switch self {
        case .transport: return "Transport"
        case .outdoor: return "Outdoor"
        case .indoor: return "Indoor"
        }
    }
}

enum Metrics {
    static let popoverWidth: CGFloat = 360
    static let cardRadius: CGFloat = 22
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
}

extension View {
    /// The soft rounded surface used for grouped controls.
    func card() -> some View {
        padding(16)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

/// Shrinks slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
