// swift-tools-version: 5.9

// QuantFlow — Swift Student Challenge App Playground.
// Offline-only. No third-party dependencies. No network access.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "QuantFlow",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "QuantFlow",
            targets: ["AppModule"],
            bundleIdentifier: "dev.quantflow.QuantFlow",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
