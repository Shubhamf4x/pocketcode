# Flutter embedding and engine entry points must survive R8.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# The embedding optionally references Play Store deferred-component APIs that
# are not bundled in this app (no deferred components in use).
-dontwarn com.google.android.play.core.**

# flutter_secure_storage (EncryptedSharedPreferences / Tink crypto) breaks
# if its reflection-based classes are stripped.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }

# Keep source file + line numbers for readable release stack traces.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
