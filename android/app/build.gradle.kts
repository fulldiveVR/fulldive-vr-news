plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Package name is inherited from the legacy Fulldive VR app so that this
    // build replaces it on Google Play and on already-installed devices.
    namespace = "in.fulldive.shell"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "in.fulldive.shell"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file("../keys/keys.jks")
            storePassword = System.getenv("FULLDIVE_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("FULLDIVE_ALIAS")
            keyPassword = System.getenv("FULLDIVE_ALIAS_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Falls back to the debug keys when the FULLDIVE_* environment
            // variables are missing, so `flutter run --release` keeps working.
            signingConfig = if (System.getenv("FULLDIVE_KEYSTORE_PASSWORD") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
