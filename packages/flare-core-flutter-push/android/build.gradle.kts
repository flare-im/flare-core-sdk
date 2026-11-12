group = "com.flare.im.push.flutter"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.2.20"

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

// AGP 9 自己编 Kotlin，除非应用用 android.builtInKotlin=false 关掉。
val builtInKotlinEnabled =
    agpMajor >= 9 &&
        (providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() ?: true)

if (!builtInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.flare.im.push.flutter"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    lint {
        disable.add("InvalidPackage")
    }
}

dependencies {
    // 推送的平台行为全在 `flare-core-android-push`（FCM 服务、通知渠道与展示、点击、三态权限与申请、
    // 后台限制）：项目依赖，不拷源码。flare-core-sdk 没有根工程，宿主的 settings 要把这个模块和插件一起 include。
    // 个推模块不在这里：它是应用自己的可选依赖，插件按类名反射启用。
    api(project(":flare-core-android-push"))
    // 宿主调用切到主线程走方法通道。
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
