plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.music_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlinのコンパイルオプション設定
    kotlinOptions {
        // jvmTarget = JavaVersion.VERSION_17.toString() // 以前の書き方（非推奨）
        @Suppress("DEPRECATION")
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.music_player"
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

            // --- リリースモードでの MissingPluginException 対策 ---
            // ProGuard設定でも解消しないため、一旦最適化（コードの削除）を無効化（false）にします。
            isMinifyEnabled = false
            
            // リソースの削減（isShrinkResources）は、コードの最適化（isMinifyEnabled）が有効な場合のみ使用できます。
            // コード最適化を無効にしたため、リソース削減も明示的に無効にします。
            isShrinkResources = false
            
            // 最適化の際に「消してはいけないもの」を指定するルールファイルを読み込みます
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
