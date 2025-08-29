// build.gradle.kts (Module: android/app)
// Kotlin DSL signing + optional Gradle Play Publisher

import java.util.Properties
import java.io.FileInputStream
// Uncomment if you enable the Play Publisher plugin below
// import com.github.triplet.gradle.androidpublisher.ReleaseStatus

plugins {
    id("com.android.application")
    kotlin("android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // OPTIONAL: enable if you want CI auto-publish to Google Play
    // id("com.github.triplet.play") version "3.12.1"
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.towdow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

    defaultConfig {
        applicationId = "app.towdow" // TODO: MUST match the package created in Play Console
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val envKs = System.getenv("ANDROID_KEYSTORE")
            if (envKs != null) {
                // CI path via env variables
                storeFile = file(envKs)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            } else if (keystorePropertiesFile.exists()) {
                // Local signing via key.properties (git-ignored)
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
        }
    }
}

flutter { source = "../.." }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// OPTIONAL: Gradle Play Publisher (enable plugin above first)
// play {
//     serviceAccountCredentials.set(file(System.getenv("PLAY_JSON")))
//     track.set("internal")
//     defaultToAppBundles.set(true)
//     releaseStatus.set(ReleaseStatus.COMPLETED)
// }

// key.properties (DO NOT COMMIT) template:
// storeFile=/absolute/path/to/upload-keystore.jks
// storePassword=YOUR_STORE_PASSWORD
// keyAlias=upload
// keyPassword=YOUR_KEY_PASSWORD