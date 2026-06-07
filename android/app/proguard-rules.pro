# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Pigeon-generated channel classes (path_provider, etc.)
-keep class dev.flutter.pigeon.** { *; }

# path_provider_android
-keep class io.flutter.plugins.pathprovider.** { *; }

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

# health
-keep class io.flutter.plugins.health.** { *; }

# Preserve native method names (JNI)
-keepclassmembers class * {
    native <methods>;
}

# Keep plugin registrant
-keep class com.sitrovainnovation.renovatio.GeneratedPluginRegistrant { *; }
