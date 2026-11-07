// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flare_core_flutter_lifecycle",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "flare-core-flutter-lifecycle", targets: ["flare_core_flutter_lifecycle"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flare_core_flutter_lifecycle",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
