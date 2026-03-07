// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppleVibeNotebook",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "AppleVibeNotebook",
            targets: ["AppleVibeNotebook"]
        ),
        .executable(
            name: "AppleVibeNotebookApp",
            targets: ["AppleVibeNotebookApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .target(
            name: "AppleVibeNotebook",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ],
            path: "Sources/AppleVibeNotebook"
        ),
        .executableTarget(
            name: "AppleVibeNotebookApp",
            dependencies: [
                "AppleVibeNotebook"
            ],
            path: "Sources/AppleVibeNotebookApp"
        ),
        .testTarget(
            name: "AppleVibeNotebookTests",
            dependencies: ["AppleVibeNotebook"],
            path: "Tests/AppleVibeNotebookTests"
        )
    ]
)
