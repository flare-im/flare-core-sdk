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
        // The update installer and controller without the engine: the App Store and TestFlight hand-off.
        .library(name: "FlarePlatformUpdate", targets: ["FlarePlatformUpdate"]),
        // Notification permission, APNs registration, presentation, taps and badge without the engine:
        // the core client and the social SDK each provide the host it talks to.
        .library(name: "FlarePlatformPush", targets: ["FlarePlatformPush"]),
        // The base class of an app's notification service extension: re-renders alerts from the snapshot the app
        // writes into its App Group and records arrival receipts. Depends on nothing else, so the extension stays small.
        .library(name: "FlareNotificationService", targets: ["FlareNotificationService"])
    ],
    targets: [
        .systemLibrary(
            name: "CFlareImCoreSdkFFI",
            path: "Sources/CFlareImCoreSdkFFI"
        ),
        .target(name: "FlarePlatformLifecycle"),
        .target(name: "FlarePlatformUpdate", dependencies: ["FlarePlatformLifecycle"]),
        .target(name: "FlarePlatformPush", dependencies: ["FlarePlatformLifecycle"]),
        .target(name: "FlareNotificationService"),
        .target(
            name: "FlareCoreAppleSDK",
            dependencies: ["CFlareImCoreSdkFFI", "FlarePlatformLifecycle", "FlarePlatformUpdate", "FlarePlatformPush"]
        ),
        .testTarget(
            name: "FlarePlatformLifecycleTests",
            dependencies: ["FlarePlatformLifecycle"]
        ),
        .testTarget(
            name: "FlarePlatformUpdateTests",
            dependencies: ["FlarePlatformUpdate"]
        ),
        .testTarget(
            name: "FlarePlatformPushTests",
            dependencies: ["FlarePlatformPush", "FlarePlatformLifecycle"]
        ),
        .testTarget(
            name: "FlareNotificationServiceTests",
            dependencies: ["FlareNotificationService"]
        ),
        .testTarget(
            name: "FlareCoreAppleSDKTests",
            dependencies: ["FlareCoreAppleSDK", "FlarePlatformUpdate", "FlarePlatformPush"]
        )
    ]
)
