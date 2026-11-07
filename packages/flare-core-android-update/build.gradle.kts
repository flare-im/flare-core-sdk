plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// The update installer and controller on their own: no native library, no SDK types and no Play
// dependency. The controller reaches the engine through an injected port, so a host that brings its
// own engine (the social app's C ABI) uses it unchanged. Play In-App Updates live in
// `flare-core-android-update-play`, which only a Play flavor adds.
//
// `REQUEST_INSTALL_PACKAGES` is deliberately absent from this manifest: a store build must not carry
// it, so the app's direct flavor declares it.
android {
    namespace = "com.flare.im.update"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }
}

// Set the target rather than a toolchain: Flutter hosts build this module on whatever JDK they run.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // The controller's state is a StateFlow and its work runs on a scope the caller can pass in.
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    // Returning to the foreground from ProcessLifecycleOwner.
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    // The Android stub jar has no working org.json; local unit tests use the real one.
    testImplementation("org.json:json:20240303")
}
