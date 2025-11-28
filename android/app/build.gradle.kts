import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties (for local builds)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

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



// Read version from pubspec.yaml
fun getFlutterVersion(): Pair<Int, String> {
    val pubspec = File("${project.rootDir}/pubspec.yaml")
    val versionLine = pubspec.readLines().firstOrNull { it.startsWith("version:") }
    val version = versionLine?.split("version:")?.get(1)?.trim() ?: "1.0.0+1"

    val versionName = version.split("+")[0]
    val versionCode = version.split("+").getOrNull(1)?.toIntOrNull() ?: 1

    return Pair(versionCode, versionName)
}

val (pubspecVersionCode, pubspecVersionName) = getFlutterVersion()


signingConfigs {
        create("release") {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
