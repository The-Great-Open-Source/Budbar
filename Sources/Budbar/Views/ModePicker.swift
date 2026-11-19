// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

/// Control Center style tiles: a round icon button with a label underneath.
struct ModePicker: View {
    @EnvironmentObject private var model: AppModel
    let selected: AmbientSoundMode
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AmbientSoundMode.allCases) { mode in
                Button {
                    guard mode != selected else { return }
                    model.hapticTick()
                    withAnimation(Metrics.spring) {
                        model.update { $0.ambient = mode }
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.10))
                            if selected == mode {
                                Circle()
                                    .fill(mode.tint)
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                            Image(systemName: mode.symbol)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(selected == mode ? Color.white : Color.primary)
                        }
                        .frame(width: 52, height: 52)

                        Text(mode.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selected == mode ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(KeyEquivalent(mode.shortcutKey), modifiers: .command)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(selected == mode ? .isSelected : [])
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
        .animation(Metrics.spring, value: selected)
    }
}
