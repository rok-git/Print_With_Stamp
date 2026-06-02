// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PrintWithStamp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "print-with-stamp", targets: ["PrintWithStamp"])
    ],
    targets: [
        .executableTarget(name: "PrintWithStamp")
    ]
)
