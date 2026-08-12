allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Phase 5A build fix — AGP 9 toolchain compatibility:
// file_picker 11.x detects AGP 9+ (`com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION`)
// and deliberately SKIPS applying the classic `kotlin-android` plugin, relying on
// AGP's built-in Kotlin. This project opts out of built-in Kotlin
// (`android.builtInKotlin=false`) because classic-KGP plugins (connectivity_plus,
// image_picker, …) fail under it. Result: file_picker's Kotlin sources were never
// compiled and its `FilePickerPlugin` class was missing at the app's javac stage.
// Force-apply the classic KGP (declared in settings.gradle.kts) to that one
// project only — the same configuration file_picker itself uses on AGP 8.
subprojects {
    plugins.withId("com.android.library") {
        if (name == "file_picker") {
            apply(plugin = "org.jetbrains.kotlin.android")
            // file_picker's own build.gradle targets Java 17 — pin Kotlin to
            // the same JVM target so javac/kotlinc don't disagree.
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension>("kotlin") {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
