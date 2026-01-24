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
    targets: [
        .target(name: "SwishKit"),
        .executableTarget(
            name: "swish",
            dependencies: ["SwishKit"]
        ),
        .testTarget(
            name: "SwishKitTests",
            dependencies: ["SwishKit"]
        )
    ]
)
