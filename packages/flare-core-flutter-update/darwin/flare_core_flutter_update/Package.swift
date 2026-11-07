// swift-tools-version: 5.9

import PackageDescription

// FlarePlatformUpdate's installer sources are linked into this target rather than taken as a package
// dependency: that package's iOS 15 floor is above what Flutter hosts deploy to, and the podspec
// cannot depend on a SwiftPM product. Both build systems compile the same two files.
let package = Package(
    name: "flare_core_flutter_update",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "flare-core-flutter-update", targets: ["flare_core_flutter_update"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flare_core_flutter_update",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
