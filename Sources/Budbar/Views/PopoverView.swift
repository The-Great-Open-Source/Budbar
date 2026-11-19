// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            HeaderView()

            Group {
                if model.isConnected, let state = model.state {
                    VStack(spacing: 18) {
                        ModePicker(selected: state.soundModes.ambient)
                        ModeDetail(modes: state.soundModes)
                        BatteryRow(state: state)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    StatusView()
                        .transition(.opacity)
                }
            }
            .animation(Metrics.spring, value: model.isConnected)

            FooterView()
        }
        .padding(20)
        .frame(width: Metrics.popoverWidth)
        .background(alignment: .top) {
            Ellipse()
                .fill(glowColor.opacity(0.22))
                .frame(width: 320, height: 180)
                .blur(radius: 55)
                .offset(y: -70)
                .animation(.easeInOut(duration: 0.5), value: glowColor)
                .allowsHitTesting(false)
        }
    }

    private var glowColor: Color {
        if model.isConnected, let modes = model.state?.soundModes {
            return modes.ambient.tint
        }
        return .gray
    }
}

// MARK: Header

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    private var iconTint: Color {
        if model.isConnected, let modes = model.state?.soundModes {
            return modes.ambient.tint
        }
        return Color.gray
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(iconTint.gradient)
                    .shadow(color: iconTint.opacity(0.4), radius: 8, y: 3)
                Image(systemName: "earbuds")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .animation(.easeInOut(duration: 0.4), value: iconTint)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.deviceTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.statusColor)
                        .frame(width: 6, height: 6)
                    Text(model.statusText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            SettingsMenu()
        }
    }
}

struct SettingsMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            if !model.devices.isEmpty {
                Picker("Earbuds", selection: Binding(
                    get: { model.selectedDevice?.id ?? "" },
                    set: { model.select(deviceID: $0) }
                )) {
                    ForEach(model.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .pickerStyle(.inline)
                Divider()
            }
            Button("Reconnect") { model.retry() }
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Demo mode", isOn: Binding(
                get: { model.demoMode },
                set: { model.setDemoMode($0) }
            ))
            Divider()
            Button("Quit Budbar") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: Footer

struct FooterView: View {
    var body: some View {
        HStack {
            Text("Unofficial. Not affiliated with Anker or Soundcore.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            Link("GitHub", destination: URL(string: "https://github.com/The-Great-Open-Source/Budbar")!)
                .font(.system(size: 10, weight: .medium))
        }
    }
}
