plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// 个推：clientid 登记为 getui 令牌，透传消息走与 FCM 相同的入口。只有国内渠道的构建加这个模块。
// 进程被杀后只有厂商通道能到达，它们由个推的厂商插件接入，应用按 README 加插件与各厂商参数。
//
// 个推的制品不在 mavenCentral：应用的仓库列表要加 https://mvn.getui.com/nexus/content/repositories/releases/ 。
// 制品坐标与版本只写在这里，升级时对照个推的 Android 接入文档一起改。
android {
    namespace = "com.flare.im.push.getui"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
        // Flutter 插件反射调用的入口，应用混淆时保留。
        consumerProguardFiles("consumer-rules.pro")
    }
}

// 设目标而不设工具链：Flutter 宿主用它自己的 JDK 构建这个模块。
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    api(project(":flare-core-android-push"))
    // 个推 SDK 与它的核心组件，两个版本要成对。
    implementation("com.getui:gtsdk:3.3.5.0")
    implementation("com.getui:gtc:3.2.11.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
