import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    // Java Properties treats Windows paths such as C:\Users as malformed
    // Unicode escapes. Signing files are simple key=value pairs, so preserve
    // backslashes and parse them without Properties' escape processing.
    keystorePropertiesFile.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#")) {
            val separator = trimmed.indexOf('=')
            if (separator > 0) {
                keystoreProperties.setProperty(
                    trimmed.substring(0, separator).trim(),
                    trimmed.substring(separator + 1).trim(),
                )
            }
        }
    }
}

android {
    namespace = "io.qzz.wenyun"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14033849"

    packaging {
        jniLibs {
            // libmihomo resolves libclash.so from applicationInfo.nativeLibraryDir,
            // so the package manager must extract native libraries at install time.
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep the original Play Store identity so this remains an update of
        // the existing app rather than a new listing.
        applicationId = "org.eu.liwenyun"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let(::file)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    implementation(files("libs/libmihomo-android-v0.3.5.aar"))
}
