// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aperture",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "ApertureCore", targets: ["ApertureCore"]),
        .library(name: "ApertureUI", targets: ["ApertureUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
    ],
    targets: [
        .target(
            name: "ApertureCore",
            dependencies: [.product(name: "SQLite", package: "SQLite.swift")],
            path: "Sources/ApertureCore"
        ),
        .target(
            name: "ApertureUI",
            dependencies: ["ApertureCore"],
            path: "Sources/ApertureUI"
        ),
        .testTarget(
            name: "ApertureCoreTests",
            dependencies: ["ApertureCore"],
            path: "Tests/ApertureCoreTests"
        ),
    ]
)

