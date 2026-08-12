pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Firebase (Gate-31): version matching the current flutterfire docs for the
    // firebase_core 4.x line (the version the FlutterFire CLI pins for a new
    // project). Resolvable from the google() repository above even before
    // google-services.json is present — the plugin itself fails fast on the
    // missing file at app configuration time (see docs/firebase-config.md).
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
