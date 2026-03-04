// swift-tools-version: 6.2

import PackageDescription

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
        .package(url: "https://github.com/objecthub/swift-commandlinekit.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(name: "SwishKit"),
        .executableTarget(
            name: "swish",
            dependencies: [
                "SwishKit",
                .product(name: "CommandLineKit", package: "swift-commandlinekit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "SwishKitTests",
            dependencies: ["SwishKit"]
        )
    ]
)
