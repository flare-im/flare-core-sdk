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

dependencies {
    // PlatformLifecycle lives in its own module (no native library) so hosts with their own engine reuse it;
    // a build that includes this package includes `:flare-core-android-lifecycle` next to it.
    api(project(":flare-core-android-lifecycle"))
    // ClientUpdateEngine adapts a client to the update controller; the same goes for `:flare-core-android-update`.
    api(project(":flare-core-android-update"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation(kotlin("test"))
    // The Android stub jar has no working org.json; local unit tests use the real one.
    testImplementation("org.json:json:20240303")
}

// LinkStatusVectorTest reads the engine's shared link status vectors. Declared as a test input so a changed
// vector file reruns the tests instead of Gradle calling them up to date.
val linkStatusVectors = layout.projectDirectory.file("../../../flare-core-sdk-engine/tests/vectors/link_status.json")
tasks.withType<Test>().configureEach {
    if (linkStatusVectors.asFile.isFile) {
        inputs.file(linkStatusVectors)
            .withPathSensitivity(PathSensitivity.RELATIVE)
            .withPropertyName("linkStatusVectors")
    }
}
