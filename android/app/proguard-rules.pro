# Keep Kiwi classes from being obfuscated or removed
-keep class kr.pe.bab2min.** { *; }
-keepclassmembers class kr.pe.bab2min.** { *; }
-dontwarn kr.pe.bab2min.**

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}
