plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.myanimerent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.myanimerent"
        resValue("string", "app_name", "MyAnimeRent")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "mode"
    productFlavors {
        create("standard") {
            dimension = "mode"
        }
        create("event") {
            dimension = "mode"
            applicationIdSuffix = ".event"
            versionNameSuffix = "-event"
            resValue("string", "app_name", "MyAnimeRent Uji Event")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// A demo entrypoint must never produce an APK with the existing app identity.
val flutterTarget = (project.findProperty("target") as? String ?: "lib/main.dart").replace('\\', '/')
// Flutter wraps a device integration test in a temporary listener entrypoint.
val generatedEventTestRunner = Regex(".*/flutter_tools\\.[^/]+/flutter_test_listener\\.[^/]+/listener\\.dart$").matches(flutterTarget) &&
    file(flutterTarget).isFile && file(flutterTarget).readText().contains("/integration_test/event_flow_test.dart")
val eventTarget = flutterTarget.endsWith("/main_event.dart") ||
    flutterTarget.endsWith("/integration_test/event_flow_test.dart") || generatedEventTestRunner
val requestedTasks = gradle.startParameter.taskNames.map { it.lowercase() }
if (eventTarget && requestedTasks.any { it.contains("standard") }) {
    throw GradleException("Target event wajib memakai --flavor event agar tidak menggantikan aplikasi utama.")
}
if (!eventTarget && requestedTasks.any { it.contains("event") }) {
    throw GradleException("Flavor event wajib memakai -t lib/main_event.dart. Target saat ini: $flutterTarget")
}
