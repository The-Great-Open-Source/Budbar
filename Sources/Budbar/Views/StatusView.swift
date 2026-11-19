// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Shown instead of the controls when there is no live connection.
struct StatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            icon
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if model.phase != .connecting {
                HStack(spacing: 8) {
                    if model.phase == .waitingForDevice {
                        Button("Bluetooth Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    Button("Try again") { model.retry() }
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 12)
        .card()
    }

    @ViewBuilder
    private var icon: some View {
        switch model.phase {
        case .connecting:
            ProgressView().controlSize(.large).frame(height: 34)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .frame(height: 34)
        default:
            Image(systemName: "earbuds")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .frame(height: 34)
        }
    }

    private var title: String {
        switch model.phase {
        case .connecting: return "Connecting"
        case .failed: return "Can't reach your earbuds"
        default: return model.selectedDevice == nil ? "No earbuds found" : "Earbuds not connected"
        }
    }

    private var message: String {
        switch model.phase {
        case .connecting:
            return "Talking to your earbuds."
        case .failed(let reason):
            return reason
        default:
            if model.selectedDevice == nil {
                return "Pair your Soundcore earbuds in Bluetooth settings, or choose them from the menu at the top right."
            }
            return "Take them out of the case and connect them to this Mac."
        }
    }
}
