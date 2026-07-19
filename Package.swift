// swift-tools-version:5.9
import PackageDescription

/// Sinhala FM Font Input Method for macOS
///
/// This package defines the input method application and its test target.
/// Note: The primary build method is via `Scripts/build.sh` which uses `swiftc`
/// directly to create the proper .app bundle. This Package.swift is primarily
/// for code organization, IDE support, and running unit tests.
let package = Package(
    name: "SinhalaFMInput",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "SinhalaFMInput",
            path: "Sources/SinhalaFMInput",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("InputMethodKit")
            ]
        ),
        .testTarget(
            name: "SinhalaFMInputTests",
            dependencies: ["SinhalaFMInput"],
            path: "Tests/SinhalaFMInputTests"
        )
    ]
)
