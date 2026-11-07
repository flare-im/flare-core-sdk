plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// Play In-App Updates, kept out of `flare-core-android-update` so a direct build carries no Play code.
// Only a Play flavor depends on this module.
android {
    namespace = "com.flare.im.update.play"
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
    api(project(":flare-core-android-update"))
    implementation("com.google.android.play:app-update:2.1.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
