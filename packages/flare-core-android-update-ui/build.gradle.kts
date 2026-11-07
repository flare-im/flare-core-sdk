plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// The update controller bound to the Kit's update components: the one module that knows both, so two
// apps do not each map one to the other. `flare-core-android-update` and the Play module stay free of
// the Kit, because a Flutter host builds them without it.
android {
    namespace = "com.flare.im.update.ui"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The Kit's own floor.
        minSdk = 26
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    api(project(":flare-core-android-update"))
    // Hosts substitute the workspace Kit for this coordinate.
    implementation("com.flare.im:im-ui-compose:2.0.0-rc.1")

    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
