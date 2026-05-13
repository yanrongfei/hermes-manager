pluginManagement {
    val flutterSdkPath = System.getenv("FLUTTER_HOME")
        ?: throw GradleException("FLUTTER_HOME environment variable is not set.")
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories {
        maven { 
            name = "aliyun-google"
            url = uri("https://maven.aliyun.com/repository/google") 
        }
        maven { 
            name = "aliyun-public"
            url = uri("https://maven.aliyun.com/repository/public") 
        }
        maven { 
            name = "aliyun-gradle-plugin"
            url = uri("https://maven.aliyun.com/repository/gradle-plugin") 
        }
        maven { 
            name = "flutter-storage"
            url = uri("https://storage.flutter-io.cn/download.flutter.io") 
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
}

include(":app")