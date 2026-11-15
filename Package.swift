// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ohr",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        // Pure-logic library -no Speech framework, testable
        .target(
            name: "OhrCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        // Main executable -depends on OhrCore + Hummingbird + Speech
        .executableTarget(
            name: "ohr",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "OhrCore",
            ],
            path: "Sources",
            exclude: ["Core"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        // Test runner -pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "ohr-tests",
            dependencies: ["OhrCore"],
            path: "Tests/ohrTests"
        ),
    ]
)
