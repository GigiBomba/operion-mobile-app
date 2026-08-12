plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (Gate-31): the google-services Gradle plugin validates
    // android/app/google-services.json at configuration time — a missing file
    // fails the build fast ("File google-services.json is missing."), which is
    // the desired release fail-fast (see docs/firebase-config.md). The plugin
    // version is pinned in android/settings.gradle.kts pluginManagement.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.operion.operion_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 10+ requires core library desugaring
        // for scheduled notifications on older Android versions (Phase 5A).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.operion.operion_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Gate-31 SDK pins (blueprint §13.6 matrix) — explicit instead of the
        // Flutter defaults: minSdk 29 (Android 10), targetSdk 35 (Android 15).
        minSdk = 29
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Phase 5A: keep quick-action drawables + widget providers from
            // being stripped by R8 (proguard-rules.pro).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Release signing (Gate-31): ALWAYS resolved from environment
            // variables — a release APK must NEVER fall back to debug signing
            // (Play Console / store upload would reject a debug-signed APK).
            //
            // Required env vars:
            //   KEYSTORE_PATH           -> absolute/relative path to release.keystore
            //   KEYSTORE_STORE_PASSWORD -> keystore store password
            //   KEYSTORE_KEY_ALIAS      -> key alias (e.g. "operion")
            //   KEYSTORE_KEY_PASSWORD   -> key password
            //
            // Generate a keystore if you don't have one:
            //   keytool -genkey -v -keystore release.keystore -alias operion \
            //     -keyalg RSA -keysize 2048 -validity 10000
            //
            // The check runs ONLY when a release task (assembleRelease /
            // bundleRelease / …) is part of the invocation — a debug build must
            // not trip over missing release credentials. If ANY variable is
            // unset/blank the release build FAILS with a GradleException
            // (fail-fast) — it never silently uses debug signing.
            val buildingRelease = gradle.startParameter.taskNames.any { task ->
                task.substringAfterLast(':').contains("Release")
            }
            if (buildingRelease) {
                val keystorePath = System.getenv("KEYSTORE_PATH")
                val keystoreStorePassword = System.getenv("KEYSTORE_STORE_PASSWORD")
                val keystoreKeyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
                val keystoreKeyPassword = System.getenv("KEYSTORE_KEY_PASSWORD")
                if (keystorePath.isNullOrBlank() ||
                    keystoreStorePassword.isNullOrBlank() ||
                    keystoreKeyAlias.isNullOrBlank() ||
                    keystoreKeyPassword.isNullOrBlank()
                ) {
                    throw GradleException(
                        """
                        Release signing requires all four environment variables:
                          KEYSTORE_PATH=${'$'}{KEYSTORE_PATH}
                          KEYSTORE_STORE_PASSWORD=${'$'}{KEYSTORE_STORE_PASSWORD}
                          KEYSTORE_KEY_ALIAS=${'$'}{KEYSTORE_KEY_ALIAS}
                          KEYSTORE_KEY_PASSWORD=${'$'}{KEYSTORE_KEY_PASSWORD}

                        Generate a keystore if you don't have one:
                          keytool -genkey -v -keystore release.keystore -alias operion \
                            -keyalg RSA -keysize 2048 -validity 10000

                        Then export the four variables and rebuild. Release builds
                        never fall back to debug signing.
                        """.trimIndent(),
                    )
                }
                signingConfig = signingConfigs.create("release") {
                    storeFile = file(keystorePath)
                    storePassword = keystoreStorePassword
                    keyAlias = keystoreKeyAlias
                    keyPassword = keystoreKeyPassword
                }
            }
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
