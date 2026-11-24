plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// PlatformLifecycle on its own: the default network and the process lifecycle reported through two
// injected functions. No native library and no SDK types, so a host that brings its own engine (the
// social app's C ABI) reuses it without a second copy of the core engine; the core package depends on
// it and wires it to its client.
android {
    namespace = "com.flare.im.lifecycle"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // The report loop runs on a coroutine scope the caller can pass in.
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    // Foreground and background from ProcessLifecycleOwner.
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")

    testImplementation("junit:junit:4.13.2")
}
