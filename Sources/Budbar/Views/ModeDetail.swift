// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

/// Options that belong to whichever mode is active.
struct ModeDetail: View {
    @EnvironmentObject private var model: AppModel
    let modes: SoundModes

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch modes.ambient {
            case .noiseCanceling:
                SegmentedRow(
                    title: "Noise cancelling",
                    options: NoiseCancelingMode.allCases,
                    selection: modes.noiseCanceling,
                    label: { $0.title },
                    onSelect: { value in model.update { $0.noiseCanceling = value } }
                )

                switch modes.noiseCanceling {
                case .manual:
                    StrengthControl(
                        value: Int(modes.manualStrength),
                        tint: AmbientSoundMode.noiseCanceling.tint,
                        onSelect: { level in model.update { $0.manualStrength = UInt8(level) } }
                    )
                case .multiScene:
                    SegmentedRow(
                        title: "Scene",
                        options: MultiSceneMode.allCases,
                        selection: modes.multiScene,
                        label: { $0.title },
                        onSelect: { value in model.update { $0.multiScene = value } }
                    )
                case .adaptive:
                    EmptyView()
                }

                Toggle(isOn: Binding(
                    get: { modes.windNoiseSuppression },
                    set: { value in model.update { $0.windNoiseSuppression = value } }
                )) {
                    Text("Wind noise reduction")
                        .font(.system(size: 12.5))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

            case .transparency:
                SegmentedRow(
                    title: "Transparency",
                    options: TransparencyMode.allCases,
                    selection: modes.transparency,
                    label: { $0.title },
                    onSelect: { value in model.update { $0.transparency = value } }
                )

            case .normal:
                Text("Noise cancelling and transparency are off.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(Metrics.spring, value: modes.ambient)
        .animation(Metrics.spring, value: modes.noiseCanceling)
    }
}

struct SegmentedRow<Option: Hashable & Identifiable>: View {
    let title: String
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker(title, selection: Binding(get: { selection }, set: { onSelect($0) })) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

/// Five bars that grow like a signal meter. Tap one to set the strength.
struct StrengthControl: View {
    let value: Int
    let tint: Color
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        onSelect(level)
                    } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(level <= value ? tint : Color.primary.opacity(0.12))
                            .frame(height: CGFloat(8 + level * 4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30, alignment: .bottom)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Strength \(level)")
                }
            }
            .animation(Metrics.spring, value: value)
        }
    }
}
