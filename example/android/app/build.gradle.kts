plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bearound_flutter_sdk_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.1.12297006"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bearound_flutter_sdk_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Local native artifact (development only, opt-in): the plugin compiles against the AAR in
// BEAROUND_NATIVE_AAR_PATH but cannot embed it, so the host packages it. Without
// BEAROUND_APP_PRESENCE_LOCAL=1 the published native SDK comes from the plugin as before.
// See scripts/app-presence-local-native.sh.
if (System.getenv("BEAROUND_APP_PRESENCE_LOCAL") == "1") {
    val bearoundNativeAar = File(System.getenv("BEAROUND_NATIVE_AAR_PATH").orEmpty())
    require(bearoundNativeAar.isAbsolute && bearoundNativeAar.isFile) {
        "BEAROUND_APP_PRESENCE_LOCAL=1 requires BEAROUND_NATIVE_AAR_PATH to be an absolute path to an existing native AAR"
    }
    dependencies {
        implementation(files(bearoundNativeAar))
    }
}
