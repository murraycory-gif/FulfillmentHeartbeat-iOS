// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeartbeatIngest",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HeartbeatIngest",
            path: "Sources",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("z"),
                .linkedFramework("Compression"),
            ]
        ),
    ]
)
