// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HandyTab",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HandyTab", targets: ["HandyTab"])
    ],
    targets: [
        .target(
            name: "CMultitouch",
            linkerSettings: [
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"]),
                .linkedFramework("MultitouchSupport"),
            ]
        ),
        .target(name: "TrackpadSupport", dependencies: ["CMultitouch"]),
        .executableTarget(
            name: "HandyTab",
            dependencies: ["TrackpadSupport"],
            path: "Sources",
            exclude: ["CMultitouch", "TrackpadSupport"]
        ),
        .testTarget(name: "TrackpadSupportTests", dependencies: ["TrackpadSupport", "CMultitouch"]),
    ]
)
