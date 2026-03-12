// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GenerativeUIDSL",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GenerativeUIDSL", targets: ["GenerativeUIDSL"]),
    ],
    targets: [
        .target(name: "GenerativeUIDSL"),
        .testTarget(
            name: "GenerativeUIDSLTests",
            dependencies: ["GenerativeUIDSL"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
