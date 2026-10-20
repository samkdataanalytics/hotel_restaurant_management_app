plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.hotrest.staff"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs that do not exist on
        // older Android levels, so it requires core library desugaring. Without
        // this the build fails at :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.hotrest.staff"
        // flutter_secure_storage requires API 23+ for the keystore-backed
        // implementation. The Flutter default is already above this; pinned
        // explicitly so an SDK downgrade cannot silently break session storage.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add a release signing config before the first pilot build.
            // Still signing with the debug key, so `flutter run --release`
            // works but the output is NOT distributable. Needs a keystore,
            // which must not be committed to this repo.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Required by the desugaring enabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
