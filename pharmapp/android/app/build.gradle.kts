import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pharmapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        @Suppress("DEPRECATION")
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.pharmapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing via environment variables or key.properties file.
    // To configure:
    //   1. Generate keystore: keytool -genkey -v -keystore pharmapp-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pharmapp
    //   2. Place pharmapp-release.jks in android/app/ (never commit it)
    //   3. Set env vars: KEY_STORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS
    //      OR create android/key.properties (never commit it):
    //        storePassword=<password>
    //        keyPassword=<password>
    //        keyAlias=pharmapp
    //        storeFile=pharmapp-release.jks
    val keystorePropsFile = rootProject.file("key.properties")
    val keystoreProps = Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(keystorePropsFile.inputStream())
    }

    signingConfigs {
        create("release") {
            keyAlias     = (keystoreProps["keyAlias"]       as? String) ?: System.getenv("KEY_ALIAS")       ?: ""
            keyPassword  = (keystoreProps["keyPassword"]    as? String) ?: System.getenv("KEY_PASSWORD")    ?: ""
            storeFile    = file((keystoreProps["storeFile"] as? String) ?: (System.getenv("KEY_STORE_FILE") ?: "pharmapp-release.jks"))
            storePassword= (keystoreProps["storePassword"]  as? String) ?: System.getenv("KEY_STORE_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = if (
                (keystorePropsFile.exists() || System.getenv("KEY_ALIAS") != null) &&
                file((keystoreProps["storeFile"] as? String) ?: (System.getenv("KEY_STORE_FILE") ?: "pharmapp-release.jks")).exists()
            ) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing if no keystore configured (dev only)
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
