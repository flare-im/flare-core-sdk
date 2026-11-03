plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.flare.im"
    compileSdk = 35
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-fexceptions", "-frtti")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    // jniLibs 只认默认的 src/main/jniLibs —— 由客户端仓根的 `make sync-android`
    // 从 flare-core-sdk-engine/dist/android 分发进来。曾额外挂 ../../native/artifacts/android
    // 作为第二个 srcDir，但仓里没有任何步骤会去填它；一旦两处同时存在同名 .so，
    // mergeDebugJniLibFolders 就报 Duplicate resources，照文档跑 make sync 反而构建不出来。
}

kotlin {
    jvmToolchain(17)
}
