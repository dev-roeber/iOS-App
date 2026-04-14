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
        // .upToNextMinor pins to 0.9.x: takes patches but blocks any 0.10+ release
        // that could introduce breaking changes in the 0.x series.
        .package(url: "https://github.com/dev-roeber/ZIPFoundation.git", branch: "development"),
    ],
    targets: [
        .target(
            name: "LocationHistoryConsumer"
        ),
        .target(
            name: "LocationHistoryConsumerAppSupport",
            dependencies: [
                "LocationHistoryConsumer",
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
