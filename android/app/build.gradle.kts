<<<<<<< Updated upstream
// build.gradle.kts (Module: android/app)
// Kotlin DSL signing + optional Gradle Play Publisher

import java.util.Properties
import java.io.FileInputStream
// Uncomment if you enable the Play Publisher plugin below
// import com.github.triplet.gradle.androidpublisher.ReleaseStatus
=======
import java.util.Properties
import java.io.FileInputStream
>>>>>>> Stashed changes

plugins {
    id("com.android.application")
    kotlin("android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // OPTIONAL: enable if you want CI auto-publish to Google Play
    // id("com.github.triplet.play") version "3.12.1"
}

// Keystore: load from env in CI (preferred) or from local key.properties for manual builds
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
<<<<<<< Updated upstream
        applicationId = "app.towdow" // TODO: MUST match the package created in Play Console
=======
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.towdow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
>>>>>>> Stashed changes
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
<<<<<<< Updated upstream
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
=======
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
>>>>>>> Stashed changes
        }
    }

    buildTypes {
<<<<<<< Updated upstream
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
            // default debug config
=======
        release {
            signingConfig = signingConfigs.getByName("release")
>>>>>>> Stashed changes
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