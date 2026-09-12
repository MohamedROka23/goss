# GOSST App — R8 shrink keep rules.
# The app entry point must survive shrinking/renaming; plugin consumer rules
# (Firebase, local_auth, flutter_secure_storage, ...) arrive with their AARs.

-keep class com.gosst.goss.MainActivity { *; }
-keepclassmembers class com.gosst.goss.** {
    public <fields>;
}