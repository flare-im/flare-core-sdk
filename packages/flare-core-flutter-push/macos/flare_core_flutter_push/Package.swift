// swift-tools-version: 5.9

import PackageDescription

// macOS 上只有桌面系统通知（UNUserNotificationCenter），不接 APNs，也不依赖 FlarePlatformPush：
// 桌面自己提示，没有推送绑定。10.15 与 Flutter macOS 宿主的下限一致。
let package = Package(
    name: "flare_core_flutter_push",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "flare-core-flutter-push", targets: ["flare_core_flutter_push"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flare_core_flutter_push",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
