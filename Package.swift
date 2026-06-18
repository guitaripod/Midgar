// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Midgar",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Midgar", targets: ["Midgar"])
    ],
    targets: [
        .target(
            name: "Midgar",
            resources: [
                .process("Resources/catalog.fallback.json"),
                .copy("Resources/fallback-icons"),
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "MidgarTests",
            dependencies: ["Midgar"]
        )
    ]
)
