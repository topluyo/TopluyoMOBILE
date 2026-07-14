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
}

include(":app")

// ============================================================================
// AGP 9.0.1 Compatibility Patch
// ============================================================================
// Patches Flutter plugins that use the deprecated getDefaultProguardFile('proguard-android.txt')
// which was removed in AGP 9. This replaces it with 'proguard-android-optimize.txt'
// in the plugin's build.gradle BEFORE Gradle evaluates it.
// Affected plugins: flutter_inappwebview_android, and potentially others.
// ============================================================================
gradle.beforeProject {
    val buildGradle = project.projectDir.resolve("build.gradle")
    if (buildGradle.exists() && project.name != "app" && project.name != rootProject.name) {
        val content = buildGradle.readText()
        if (content.contains("proguard-android.txt") && !content.contains("proguard-android-optimize.txt")) {
            val patched = content.replace(
                "getDefaultProguardFile('proguard-android.txt')",
                "getDefaultProguardFile('proguard-android-optimize.txt')"
            )
            buildGradle.writeText(patched)
        }
    }
}
