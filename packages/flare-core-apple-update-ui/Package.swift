// swift-tools-version: 5.9
import Foundation
import PackageDescription

// The update controller bound to the Kit's update components: the one package that knows both, so two
// apps do not each map one to the other. `FlarePlatformUpdate` stays free of the Kit, because a Flutter
// host links its sources without it.
//
// The Kit follows the same switch as the social app: the sibling flare-im-design checkout on dev, the
// published package when FLARE_USE_PUBLISHED_KIT=true. A path dependency's package name is its directory
// name, a url's the repository's.
let usePublishedKit = ProcessInfo.processInfo.environment["FLARE_USE_PUBLISHED_KIT"] == "true"

let kitDependency: Package.Dependency = usePublishedKit
    ? .package(url: "https://github.com/flare-im/flare-im-design.git", from: "1.0.9")
    : .package(path: "../../../flare-im-design/packages/ios-im-ui")

let kitPackageName = usePublishedKit ? "flare-im-design" : "ios-im-ui"

let package = Package(
    name: "FlareUpdateUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "FlareUpdateUI", targets: ["FlareUpdateUI"]),
    ],
    dependencies: [
        .package(path: "../flare-core-apple-sdk"),
        kitDependency,
    ],
    targets: [
        .target(
            name: "FlareUpdateUI",
            dependencies: [
                .product(name: "FlarePlatformUpdate", package: "flare-core-apple-sdk"),
                .product(name: "FlareIMUI", package: kitPackageName),
            ]
        ),
        .testTarget(name: "FlareUpdateUITests", dependencies: ["FlareUpdateUI"]),
    ]
)
