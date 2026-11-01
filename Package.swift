// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeepMeIn",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KeepMeIn",
            path: "Sources/KeepMeIn",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
