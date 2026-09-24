// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var dependencies: [Target.Dependency] = [
    .product(name: "SwiftSyntax", package: "swift-syntax"),
    .product(name: "SwiftParser", package: "swift-syntax"),
    "Yams",
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
]

let package = Package(
    name: "Sitrep",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SitrepCore", targets: ["SitrepCore"]),
        .executable(name: "sitrep", targets: ["Sitrep"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
        // 6.2.2 is the first release that builds against the Static Linux SDK:
        // earlier ones fail on an ambiguous DBL_DECIMAL_DIG (jpsim/Yams#477).
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Sitrep",
            dependencies: [
                "SitrepCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(name: "SitrepCore", dependencies: dependencies),
        .testTarget(name: "SitrepCoreTests", dependencies: ["SitrepCore"], exclude: ["Inputs"]),
        // Black-box tests that run the built executable. The dependency on
        // Sitrep is what gets the binary built before the tests look for it.
        .testTarget(name: "SitrepTests", dependencies: ["Sitrep"]),
    ]
)
