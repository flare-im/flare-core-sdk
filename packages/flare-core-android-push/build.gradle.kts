plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// 平台推送：FCM 消息服务、通知展示器与四个渠道、通知点击、通知权限与后台限制引导。
// 不依赖任何引擎包，经宿主适配器 FlarePushHost 调引擎：核心 SDK 与社交 SDK 各提供一个，
// 两边复用同一份平台代码。个推在 `flare-core-android-push-getui`，只有国内渠道的构建加它。
//
// Firebase 编译期总是带着，运行期可选：应用不打包 google-services.json 时 FCM 报不可用，其余照常。
android {
    namespace = "com.flare.im.push"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }
}

// 设目标而不设工具链：Flutter 宿主用它自己的 JDK 构建这个模块。
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // 点击去向是 Flow，宿主接口是挂起函数。
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    // 应用用自己的 ActivityResultLauncher 申请通知权限，类型出现在公开接口上。
    api("androidx.activity:activity:1.9.3")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.annotation:annotation:1.8.2")
    // 回前台从 ProcessLifecycleOwner 来。
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation("com.google.firebase:firebase-messaging:24.1.0")
    // 取令牌用到的 Task 接口；firebase-messaging 也会带上，这里写明编译期依赖。
    implementation("com.google.android.gms:play-services-tasks:18.2.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    // android.jar 里的 org.json 是桩，本地单测用真实现。
    testImplementation("org.json:json:20240303")
}
