// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocationHistoryConsumer",
    platforms: [
        .iOS(.v17),
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
                // CSQLite is a pkgConfig shim for the system libsqlite3 used
                // only when `canImport(SQLite3)` is false (i.e. Linux CI).
                // On Apple platforms the SDK provides SQLite3 directly and
                // an unconditional dependency would force the Linux shim
                // into the iOS/iOS-Widget link, producing
                // `Undefined symbols: _sqlite3_*` at link time.
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
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
