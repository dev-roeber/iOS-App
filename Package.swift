// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocationHistoryConsumer",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "LocationHistoryConsumer",
            targets: ["LocationHistoryConsumer"]
        ),
        .library(
            name: "LocationHistoryConsumerAppSupport",
            targets: ["LocationHistoryConsumerAppSupport"]
        ),
        .library(
            name: "LocationHistoryConsumerDemoSupport",
            targets: ["LocationHistoryConsumerDemoSupport"]
        ),
        .executable(
            name: "LocationHistoryConsumerDemo",
            targets: ["LocationHistoryConsumerDemo"]
        ),
        .executable(
            name: "LocationHistoryConsumerApp",
            targets: ["LocationHistoryConsumerApp"]
        ),
    ],
    dependencies: [
        // Pinned to exact tag on dev-roeber fork (ZIPFoundation 0.9.20 base + copyright update).
        // Use .exact() to guarantee reproducible builds in Xcode Cloud.
        // To upgrade: push a new tag to dev-roeber/ZIPFoundation, update here + resolve.
        .package(url: "https://github.com/dev-roeber/ZIPFoundation.git", exact: "0.9.20-devroeber.1"),
    ],
    targets: [
        .systemLibrary(
            // Linux shim that exposes the system `libsqlite3` headers as the
            // module name `CSQLite`. On Apple platforms `import SQLite3`
            // resolves through the SDK directly; this target is only used on
            // platforms where `canImport(SQLite3)` is false (Linux CI).
            name: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .apt(["libsqlite3-dev"]),
                .brew(["sqlite"]),
            ]
        ),
        .target(
            name: "LocationHistoryConsumer"
        ),
        .target(
            name: "LocationHistoryConsumerAppSupport",
            dependencies: [
                "LocationHistoryConsumer",
                "CSQLite",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .target(
            name: "LocationHistoryConsumerDemoSupport",
            dependencies: ["LocationHistoryConsumerAppSupport"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "LocationHistoryConsumerDemo",
            dependencies: [
                "LocationHistoryConsumerAppSupport",
                "LocationHistoryConsumerDemoSupport",
            ]
        ),
        .executableTarget(
            name: "LocationHistoryConsumerApp",
            dependencies: [
                "LocationHistoryConsumerAppSupport",
                "LocationHistoryConsumerDemoSupport",
            ]
        ),
        .testTarget(
            name: "LocationHistoryConsumerTests",
            dependencies: [
                "LocationHistoryConsumer",
                "LocationHistoryConsumerAppSupport",
                "LocationHistoryConsumerDemoSupport",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
    ]
)
