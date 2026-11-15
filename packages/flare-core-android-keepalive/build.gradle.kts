plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// 常驻连接（可选依赖，默认关）：前台服务加一条常驻通知，让应用退到后台后进程与链路一直在。只面向没有任何
// 推送通道的部署：开着时应用不登记推送绑定、接上后台展示器，服务端看到的是一台长期 Standby 的设备。
// 不依赖任何引擎包，应用经 FlareKeepAliveHost 接线。上架应用商店的应用不应启用：specialUse 前台服务与
// 电池优化豁免在商店政策里受限。
android {
    namespace = "com.flare.im.keepalive"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }
}

// 设目标而不设工具链：与推送模块一样，宿主用它自己的 JDK 构建这个模块。
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // 运行状态是 StateFlow，出现在公开接口上。
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.annotation:annotation:1.8.2")
    // 开着却没跑起来（后台时系统不让启动前台服务）：回到前台时补启动。
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")

    testImplementation("junit:junit:4.13.2")
}
