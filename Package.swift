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
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0"),
        .package(url: "https://github.com/objecthub/swift-commandlinekit.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "SwishKit", dependencies: ["BigInt"]),
        .executableTarget(
            name: "swish",
            dependencies: ["SwishKit", .product(name: "CommandLineKit", package: "swift-commandlinekit")]
        ),
        .testTarget(
            name: "SwishKitTests",
            dependencies: ["SwishKit"]
        )
    ]
)
