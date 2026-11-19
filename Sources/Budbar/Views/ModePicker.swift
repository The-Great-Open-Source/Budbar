// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

/// Three big buttons with a highlight that slides between them.
struct ModePicker: View {
    @EnvironmentObject private var model: AppModel
    let selected: AmbientSoundMode
    @Namespace private var highlight
    @State private var hovered: AmbientSoundMode?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AmbientSoundMode.allCases) { mode in
                Button {
                    guard mode != selected else { return }
                    model.hapticTick()
                    withAnimation(Metrics.spring) {
                        model.update { $0.ambient = mode }
                    }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 24, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .frame(height: 26)
                        Text(mode.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .foregroundStyle(selected == mode ? Color.white : Color.primary.opacity(0.7))
                    .background {
                        if selected == mode {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(mode.tint.gradient)
                                .shadow(color: mode.tint.opacity(0.35), radius: 8, y: 3)
                                .matchedGeometryEffect(id: "highlight", in: highlight)
                        }
                    }
                    .background {
                        if hovered == mode && selected != mode {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .onHover { inside in hovered = inside ? mode : (hovered == mode ? nil : hovered) }
                .keyboardShortcut(KeyEquivalent(mode.shortcutKey), modifiers: .command)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(selected == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .animation(Metrics.spring, value: selected)
    }
}
