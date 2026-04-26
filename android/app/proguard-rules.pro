# Flutter internals: リリースビルド時のコード難読化・最適化による挙動不備を防ぐための設定
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# permission_handler: MissingPluginException (checkPermissionStatus) を防ぐための設定
# リリースモードでのR8/ProGuardによるネイティブコードの削除を抑止します
-keep class com.baseflow.permissionhandler.** { *; }

# R8: Missing class com.google.android.play.core... 対策
# 使用していないDeferred Components関連の警告を無視します
-dontwarn com.google.android.play.core.**
