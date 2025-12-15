// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TermBridgeKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TermBridgeKit",
            targets: ["TermBridgeKit"]
        ),
        .executable(
            name: "TermBridgeKitDemo",
            targets: ["TermBridgeKitDemo"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "GhosttyKit",
            path: "vendor/ghostty/macos/GhosttyKit.xcframework"
        ),
        .target(
            name: "TermBridgeKit",
            dependencies: ["GhosttyKit"],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("Metal")
            ]
        ),
        .executableTarget(
            name: "TermBridgeKitDemo",
            dependencies: ["TermBridgeKit"],
            path: "Examples/TermBridgeKitDemo"
        )
    ]
)
