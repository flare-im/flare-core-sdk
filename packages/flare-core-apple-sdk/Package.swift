// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlareCoreAppleSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "FlareCoreAppleSDK", targets: ["FlareCoreAppleSDK"]),
        // Network / foreground reporting and app info without the engine: other SDKs (social) that
        // ship their own FFI library depend on this alone.
        .library(name: "FlarePlatformLifecycle", targets: ["FlarePlatformLifecycle"]),
    ],
    targets: [
        .systemLibrary(
            name: "CFlareImCoreSdkFFI",
            path: "Sources/CFlareImCoreSdkFFI"
        ),
        .target(name: "FlarePlatformLifecycle"),
        .target(
            name: "FlareCoreAppleSDK",
            dependencies: ["CFlareImCoreSdkFFI", "FlarePlatformLifecycle"]
        ),
        .testTarget(
            name: "FlarePlatformLifecycleTests",
            dependencies: ["FlarePlatformLifecycle"]
        ),
        .testTarget(
            name: "FlareCoreAppleSDKTests",
            dependencies: ["FlareCoreAppleSDK"]
        )
    ]
)
