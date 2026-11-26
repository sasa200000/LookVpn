import java.io.File
import java.net.URI
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mihomo (Clash.Meta) is a pinned, checksum-verified AAR downloaded once into the build
// directory; the binary is not committed. Its GPL-3.0 license matches this app.
val mihomoVersion = "0.3.14"
val mihomoSha256 = "7c3a68a4ef9afcb5018e167dc70fba7485652d0a0e29ba006703cf00fed9e230"
val mihomoAar = layout.buildDirectory.file("libs/libmihomo-android-v$mihomoVersion.aar")
val downloadMihomo = tasks.register("downloadMihomo") {
    description = "Downloads the pinned Mihomo Android AAR"
    inputs.property("version", mihomoVersion)
    inputs.property("sha256", mihomoSha256)
    outputs.file(mihomoAar)
    // Verify on every build; a cached file with the wrong bytes must never be packaged.
    outputs.upToDateWhen { false }
    doLast {
        val target = mihomoAar.get().asFile
        fun digest(file: File): String {
            val md = MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(1 shl 16)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    md.update(buffer, 0, read)
                }
            }
            return md.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }
        if (target.isFile && digest(target) == mihomoSha256) return@doLast
        target.parentFile.mkdirs()
        val part = File(target.parentFile, "${target.name}.part")
        val url = "https://github.com/oviron/libmihomo-android/releases/download/v$mihomoVersion/" +
            "libmihomo-android-v$mihomoVersion.aar"
        URI(url).toURL().openStream().use { input ->
            part.outputStream().use { output -> input.copyTo(output) }
        }
        check(digest(part) == mihomoSha256) {
            "Mihomo AAR checksum mismatch: ${digest(part)} (expected $mihomoSha256)"
        }
        if (!part.renameTo(target)) {
            target.delete()
            part.renameTo(target)
        }
    }
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.miliconfig.vpn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.miliconfig.vpn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["applicationLabel"] = "MiliConfig"
    }

    signingConfigs {
        // android/key.properties + android/keystore/release.p12 (both git-ignored). The CI
        // workflow restores the same keystore from repository secrets on every release, so
        // updates keep the same Android signature.
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                val storePath = keystoreProperties.getProperty("storeFile")
                storeFile = file(storePath)
                // New releases use PKCS12; keep older JKS key.properties working.
                storeType = keystoreProperties.getProperty("storeType")
                    ?: if (storePath.endsWith(".p12", ignoreCase = true)) "PKCS12" else "JKS"
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            if (project.findProperty("dev") == "true") {
                applicationIdSuffix = ".dev"
                manifestPlaceholders["applicationLabel"] = "MiliConfig Dev"
            }
        }
        release {
            // Falls back to the debug key on machines without key.properties.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // Xray core ships as a large .so; keep it compressed in the APK.
            useLegacyPackaging = true
        }
    }
}

dependencies {
    // Xray core, built from xray/ (scripts/build_xray.sh)
    implementation(files("libs/xray.aar"))
    // Mihomo core (v1.19.34) for the selectable alternate engine.
    implementation(files(mihomoAar).builtBy(downloadMihomo))
    // FileProvider, for sharing exported settings files.
    implementation("androidx.core:core:1.13.1")
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
