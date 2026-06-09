# Keep attributes needed for reflection and Pigeon message codecs
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep ALL Flutter plugin implementations (modern FlutterPlugin API).
# R8 tree-shakes these because they are only referenced by reflection in
# GeneratedPluginRegistrant; this rule prevents that.
# NOTE: use ** (not *) to match across all package levels.
-keep class ** implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class ** implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class ** implements io.flutter.plugin.common.EventChannel$StreamHandler { *; }

# Pigeon-generated channel classes and their inner types
-keep class dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }

# path_provider_android (Pigeon-generated PathProviderApi lives here)
-keep class io.flutter.plugins.pathprovider.** { *; }
-keepclassmembers class io.flutter.plugins.pathprovider.** { *; }

# just_audio
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.** { *; }

# audio_waveforms
-keep class com.simform.audio_waveforms.** { *; }

# ffmpeg_kit_flutter_new
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# package_info_plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keepclassmembers class dev.fluttercommunity.plus.packageinfo.** { *; }

# device_info_plus
-keep class dev.fluttercommunity.plus.deviceinfo.** { *; }
-keepclassmembers class dev.fluttercommunity.plus.deviceinfo.** { *; }

# health
-keep class io.flutter.plugins.health.** { *; }

# Preserve native method names (JNI)
-keepclassmembers class * {
    native <methods>;
}

# Keep Flutter's generated plugin registrant (called via direct reference in MainActivity)
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
