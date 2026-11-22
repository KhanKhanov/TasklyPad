import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ключ подписи release — вне git (android/key.properties и keystore в .gitignore, решение 6А plans/m6).
// Без файла release подписывается debug-ключом: сборка в CI и на чужом компьютере не падает, но такой APK
// не обновит установленный на телефоне.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "dev.local.tasklypad"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications использует java.time — на старых Android его даёт desugaring (О-109).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Идентификатор приложения: после первой установки меняется только переустановкой (решение 6А plans/m6).
        applicationId = "dev.local.tasklypad"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10+ (CLAUDE.md, .claude/rules/platform-android.md); у шаблона Flutter — 24.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            fun required(name: String): String = keystoreProperties.getProperty(name)
                ?: throw GradleException("В ${keystorePropertiesFile.name} нет строки $name")
            create("release") {
                keyAlias = required("keyAlias")
                keyPassword = required("keyPassword")
                storeFile = file(required("storeFile"))
                storePassword = required("storePassword")
            }
        } else {
            // Такой APK не встанет поверх установленного своим ключом: Android откажет, а удаление
            // приложения стирает базу телефона, ещё не выгруженную в папку синхронизации.
            logger.warn(
                "Нет ${keystorePropertiesFile.name}: release подписан debug-ключом и не обновит " +
                    "приложение, установленное со своим ключом",
            )
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Версия — из README flutter_local_notifications 22.3.3 (решение 4А plans/m6).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
