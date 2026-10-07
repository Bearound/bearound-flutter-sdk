pluginManagement {
    resolutionStrategy {
        eachPlugin {
            if (requested.version != null) {
                when (requested.id.id) {
                    "com.android.library", "com.android.application" -> useModule("com.android.tools.build:gradle:${requested.version}")
                    "org.jetbrains.kotlin.android" -> useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
                }
            }
        }
    }
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
    }
}

rootProject.name = "beacon-bridge-benchmark"
include(":physical-app")
project(":physical-app").projectDir = file("e2e/physical-app")
