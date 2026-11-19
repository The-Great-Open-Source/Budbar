// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import SoundcoreProtocol

struct BatteryRow: View {
    let state: StateUpdate

    var body: some View {
        HStack(spacing: 8) {
            BatteryRing(title: "Left", battery: state.left)
            BatteryRing(title: "Right", battery: state.right)
            BatteryRing(title: "Case", battery: state.caseBattery)
        }
        .card()
    }
}

struct BatteryRing: View {
    let title: String
    let battery: Battery?

    private var color: Color {
        guard let percent = battery?.percent else { return .secondary }
        if percent <= 10 { return .red }
        if percent <= 20 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(battery?.percent ?? 0) / 100)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Metrics.spring, value: battery?.percent)

                if let battery {
                    VStack(spacing: 1) {
                        Text("\(battery.percent)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .contentTransition(.numericText())
                        if battery.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(color)
                        }
                    }
                } else {
                    Text("n/a")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) battery")
        .accessibilityValue(battery.map { "\($0.percent) percent" } ?? "not available")
    }
}
