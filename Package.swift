// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GenerativeUIDSL",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GenerativeUIDSL", targets: ["GenerativeUIDSL"]),
    ],
    targets: [
        .target(
            name: "GenerativeUIDSL",
            path: "packages/ios/Sources/GenerativeUIDSL"
        ),
        .testTarget(
            name: "GenerativeUIDSLTests",
            dependencies: ["GenerativeUIDSL"],
            path: "packages/ios/Tests/GenerativeUIDSLTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
