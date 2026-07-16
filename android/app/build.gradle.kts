import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 阿里云更新签名/密钥：优先读 android/aliyun-update-sign-info.txt（key=value，gitignore），
// 再退 gradle 属性 / 环境变量；缺省为空（运行时会提示"更新参数未配置"）。
val aliyunUpdateInfo = Properties().apply {
    rootProject.file("aliyun-update-sign-info.txt")
        .takeIf { it.exists() }
        ?.readLines(Charsets.UTF_8)
        ?.forEach { line ->
            val trimmed = line.trim()
            if (trimmed.isBlank() || trimmed.startsWith("#") || !trimmed.contains("=")) return@forEach
            val k = trimmed.substringBefore("=").trim().trimStart('﻿')
            val v = trimmed.substringAfter("=")
            if (k.isNotBlank()) setProperty(k, v)
        }
}

fun secureConfig(name: String, defaultValue: String = ""): String =
    aliyunUpdateInfo.getProperty(name)
        ?: (project.findProperty(name) as String?)
        ?: System.getenv(name)
        ?: defaultValue

// 发布签名：读 android/release-linso-sign-info.txt（与 L2 同一 keystore；
// 同包名 top.linso.t1 覆盖安装/阿里云更新必须同签名）。
val releaseSignInfo = Properties().apply {
    rootProject.file("release-linso-sign-info.txt")
        .takeIf { it.exists() }
        ?.inputStream()
        ?.use { load(it) }
}
fun signConfig(name: String): String? =
    (project.findProperty(name) as String?)
        ?: releaseSignInfo.getProperty(name)
        ?: System.getenv(name)
val releaseStoreFileName = signConfig("RELEASE_STORE_FILE")
val hasReleaseSigning = releaseStoreFileName != null &&
    rootProject.file(releaseStoreFileName).exists() &&
    signConfig("RELEASE_STORE_PASSWORD") != null &&
    signConfig("RELEASE_KEY_ALIAS") != null &&
    signConfig("RELEASE_KEY_PASSWORD") != null

android {
    namespace = "top.linso.t1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18.x 需要 core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "top.linso.t1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // 只保留 arm64-v8a：清掉任何继承的 ABI，再单独加 arm64。
            abiFilters.clear()
            abiFilters += "arm64-v8a"
        }

        // 阿里云 EMAS 云发布参数（反射式 Taobao OneSDK 使用）
        buildConfigField("String", "ALIYUN_UPDATE_APP_KEY", "\"${secureConfig("ALIYUN_UPDATE_APP_KEY")}\"")
        buildConfigField("String", "ALIYUN_UPDATE_APP_SECRET", "\"${secureConfig("ALIYUN_UPDATE_APP_SECRET")}\"")
        buildConfigField("String", "ALIYUN_UPDATE_APP_RSA_SECRET", "\"${secureConfig("ALIYUN_UPDATE_APP_RSA_SECRET")}\"")
        buildConfigField("String", "ALIYUN_UPDATE_CHANNEL_ID", "\"${secureConfig("ALIYUN_UPDATE_CHANNEL_ID", "default")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("linso") {
                storeFile = rootProject.file(releaseStoreFileName!!)
                storePassword = signConfig("RELEASE_STORE_PASSWORD")
                keyAlias = signConfig("RELEASE_KEY_ALIAS")
                keyPassword = signConfig("RELEASE_KEY_PASSWORD")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            // 有 release-linso keystore 时用 linso 签名（与 L2 同签名），否则回退 debug。
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("linso")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 默认会删掉只被反射引用的阿里云 SDK 类，保留 proguard 规则。
            isMinifyEnabled = true
            // 删无用资源（依赖 minify）。纯瘦身，无功能影响。
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 不额外打包 native 调试符号（第三方 so 已 strip，兜底）。
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }

    // 双保险：禁用 per-ABI 拆分，只打包 arm64-v8a，排除其它 ABI 的原生库。
    splits {
        abi {
            isEnable = false
            reset()
            include("arm64-v8a")
            isUniversalApk = false
        }
    }

    // 压缩 APK 体积：原生 .so 在 APK 内压缩存储（安装时解压）。
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += setOf(
                "/META-INF/*.version",
                "/META-INF/*.kotlin_module",
                "**/*.kotlin_builtins",
                "DebugProbesKt.bin",
                "kotlin-tooling-metadata.json",
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 阿里云 EMAS 云发布（Taobao OneSDK）—— 反射调用，运行期需要这些类
    implementation("com.taobao.android:update-main:1.3.0-open")
    implementation("com.taobao.android:update-common:1.3.0-open")
    implementation("com.taobao.android:update-datasource:1.3.0-open")
    implementation("com.taobao.android:update-adapter:1.3.0-open")
    implementation("com.taobao.android:downloader:2.0.3.23-open")
    implementation("com.aliyun.ams:alicloud-android-tool:1.0.0")
    implementation("com.aliyun.ams:alicloud-android-utdid:2.6.0")
    implementation("com.alibaba:fastjson:1.1.73.android")
}
