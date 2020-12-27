// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineCB",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "CombineCB",
            targets: ["CombineCB"]),
    ],
    dependencies: [
        .package(name: "CoreBluetoothMock",
                 url: "https://github.com/kaphacius/IOS-CoreBluetooth-Mock.git",
                 .branch("master"))
    ],
    targets: [
        .target(
            name: "CombineCB",
            dependencies: ["CoreBluetoothMock"]),
        .testTarget(
            name: "CombineCBTests",
            dependencies: ["CombineCB", "CoreBluetoothMock"],
            swiftSettings: [.define("CCB_TESTS")]
            ),
    ]
)
