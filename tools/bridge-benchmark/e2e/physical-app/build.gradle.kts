plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "io.bearound.qa.bridge"
    compileSdk = 36
    defaultConfig {
        applicationId = "io.bearound.qa.bridge"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes { getByName("debug") { isDebuggable = true } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }
    sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/assets"))
}

val flutterHome = System.getenv("BRIDGE_FLUTTER_HOME") ?: "/opt/homebrew/share/flutter"
dependencies {
    implementation(project(":"))
    implementation("com.github.Bearound:bearound-android-sdk:v3.14.0")
    implementation(files("$flutterHome/bin/cache/artifacts/engine/android-arm64/flutter.jar"))
}

val copySourceHashes by tasks.registering(Copy::class) {
    dependsOn(rootProject.tasks.named("generatePublishedSource"))
    from(rootProject.layout.buildDirectory.file("source-hashes.properties"))
    into(layout.buildDirectory.dir("generated/assets"))
}
tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Assets") }.configureEach {
    dependsOn(copySourceHashes)
}
