// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Budbar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Budbar", targets: ["Budbar"]),
    ],
    targets: [
        // Pure Swift (Foundation only): packet framing and the D1202 (P31i / R60i NC) message layout.
        .target(name: "SoundcoreProtocol"),
        // The menu bar app: Bluetooth transport, state model and SwiftUI views.
        .executableTarget(
            name: "Budbar",
            dependencies: ["SoundcoreProtocol"]
        ),
        .testTarget(
            name: "SoundcoreProtocolTests",
            dependencies: ["SoundcoreProtocol"]
        ),
    ]
)
