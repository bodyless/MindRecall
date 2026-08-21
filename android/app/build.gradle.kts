import com.android.build.gradle.api.ApkVariantOutput
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** 产物文件名前缀：`mind_recall_<versionName>_<debug|release>.apk` */
val apkArtifactBaseName = "mind_recall"

android {
    namespace = "com.wishtech.mind_recall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wishtech.mind_recall"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 自定义分发用文件名。`flutter install` / `flutter run` 仍写死查找
// `app-<debug|profile|release>.apk`，必须在 flutter-apk 目录保留该别名。
android.applicationVariants.configureEach {
    val variant = this
    val buildTypeName = variant.buildType.name
    val apkFileName = "${apkArtifactBaseName}_${variant.versionName}_${buildTypeName}.apk"
    val flutterCliApkName = "app-$buildTypeName.apk"
    @Suppress("DEPRECATION")
    outputs.configureEach {
        (this as ApkVariantOutput).outputFileName = apkFileName
    }
    assembleProvider.configure {
        doLast {
            val packagedDir = variant.packageApplicationProvider.get().outputDirectory.get().asFile
            val src = File(packagedDir, apkFileName)
            val destDir = layout.buildDirectory.get().asFile.resolve("outputs/flutter-apk")
            if (src.isFile) {
                destDir.mkdirs()
                src.copyTo(File(destDir, apkFileName), overwrite = true)
                src.copyTo(File(destDir, flutterCliApkName), overwrite = true)
            }
        }
    }
}
