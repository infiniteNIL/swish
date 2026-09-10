// swift-tools-version: 6.4

import PackageDescription

/// Xcode's "Approachable Concurrency" (`SWIFT_APPROACHABLE_CONCURRENCY`) minus the three
/// features Swift 6 language mode already implies — `DisableOutwardActorInference`,
/// `GlobalActorIsolatedTypesUsability`, and `InferSendableFromCaptures`. Listing those
/// emits "already enabled as of the Swift 6 language mode" warnings.
///
/// `defaultIsolation(nil)` is explicit on purpose. It is a *separate* setting from
/// approachable concurrency (Xcode turns it on only in the App template), and SwishKit
/// must never inherit a `MainActor` default: the evaluator is driven from background GCD
/// queues (agents, futures, STM commits), so `-default-isolation=MainActor` fails the
/// build outright.
let approachableConcurrency: [SwiftSetting] = [
    .defaultIsolation(nil),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Swish",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "SwishKit", targets: ["SwishKit"]),
        .executable(name: "swish", targets: ["swish"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.3.0"),
        .package(
            url: "https://github.com/objecthub/swift-commandlinekit.git",
            from: "1.0.0"),
        .package(
            url: "https://github.com/attaswift/BigInt.git",
            from: "5.3.0"),
        .package(
            url: "https://github.com/Zollerboy1/BigDecimal.git",
            from: "1.0.0"),
        .package(
            url: "https://github.com/apple/swift-collections.git",
            from: "1.1.0")
    ],
    targets: [
        .target(
            name: "SwishKit",
            dependencies: [
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "BigDecimal", package: "BigDecimal"),
                .product(name: "Collections", package: "swift-collections")
            ],
            resources: [
                .copy("Resources/clojure")
            ],
            swiftSettings: approachableConcurrency
        ),
        .executableTarget(
            name: "swish",
            dependencies: [
                "SwishKit",
                .product(name: "CommandLineKit", package: "swift-commandlinekit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: approachableConcurrency
        ),
        .testTarget(
            name: "SwishKitTests",
            dependencies: ["SwishKit"],
            swiftSettings: approachableConcurrency
        )
    ]
)
