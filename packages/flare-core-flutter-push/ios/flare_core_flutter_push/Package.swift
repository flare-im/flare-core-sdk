// swift-tools-version: 5.9

import PackageDescription

// FlarePlatformPush 与它依赖的 FlarePlatformLifecycle 以符号链接把源码接进来，不作包依赖：Flutter 把插件包
// 经符号链接放进生成的包里，相对路径的包依赖在那里解析不到；podspec 也不能依赖 SwiftPM 产品。
// 两个目标保留原来的模块名，推送模块里的 `import FlarePlatformLifecycle` 原样成立，代码只有一份。
// iOS 15 是这两个模块的下限（通知的 interruptionLevel 等）。
let package = Package(
    name: "flare_core_flutter_push",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "flare-core-flutter-push", targets: ["flare_core_flutter_push"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(name: "FlarePlatformLifecycle"),
        .target(name: "FlarePlatformPush", dependencies: ["FlarePlatformLifecycle"]),
        .target(
            name: "flare_core_flutter_push",
            dependencies: [
                "FlarePlatformPush",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
