// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AunApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AunApp", targets: ["AunApp"]),
        .executable(name: "AunAppConfigCheck", targets: ["AunAppConfigCheck"])
    ],
    targets: [
        .target(name: "AunSupport"),
        .executableTarget(name: "AunApp", dependencies: ["AunSupport"]),
        .executableTarget(name: "AunAppConfigCheck", dependencies: ["AunSupport"])
    ]
)
