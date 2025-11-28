import java.io.File
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// =================================================================
// 1. HELPER FUNCTIONS & PROPERTIES
// =================================================================

// Read version from pubspec.yaml
fun getFlutterVersion(): Pair<Int, String> {
    // FIX: Use project.rootDir.parentFile to correctly point one level up
    // from the 'android' directory to the Flutter project root.
    val flutterProjectRoot = project.rootDir.parentFile
    val pubspec = File(flutterProjectRoot, "pubspec.yaml")

    // Safely read the file lines
    val versionLine = pubspec.readLines().firstOrNull { it.startsWith("version:") }
    val version = versionLine?.split("version:")?.get(1)?.trim() ?: "1.0.0+1"

    val versionName = version.split("+")[0]
    // Get the build number (the versionCode) from after the '+'
    val versionCode = version.split("+").getOrNull(1)?.toIntOrNull() ?: 1

    return Pair(versionCode, versionName)
}

// Call the function once to get the version data
val (pubspecVersionCode, pubspecVersionName) = getFlutterVersion()

// Load keystore properties (for local builds)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// =================================================================
// 2. ANDROID CONFIGURATION BLOCK
// =================================================================

android {
    namespace = "com.plantsciencetools.germplasmx"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // Apply the custom version data in the defaultConfig block
    defaultConfig {
        versionCode = pubspecVersionCode
        versionName = pubspecVersionName
    }

    signingConfigs {
        create("release") {
            // Logic for Codemagic (CI) vs. Local signing
            if (System.getenv("CI") == "true") {
                // Use Codemagic environment variables
                storeFile = System.getenv("CM_KEYSTORE_PATH")?.let { file(it) }
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else {
                // Use local key.properties file
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            // Optional: sign debug builds with the same key
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// =================================================================
// 3. DEPENDENCIES & FLUTTER CONFIG
// =================================================================

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}