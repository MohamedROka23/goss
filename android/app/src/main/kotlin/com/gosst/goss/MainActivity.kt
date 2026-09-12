package com.gosst.goss

import android.content.pm.ApplicationInfo
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    private val securityChannel = "goss/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceChecks" -> result.success(
                        mapOf(
                            "debuggable" to isDebuggable(),
                            "emulator" to isEmulator(),
                            "rooted" to isRooted(),
                            "sdk" to Build.VERSION.SDK_INT
                        )
                    )
                    "secureScreen" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** A release APK must never carry the debuggable or test-only flags. */
    private fun isDebuggable(): Boolean {
        val flags = applicationInfo.flags
        return flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 ||
            flags and ApplicationInfo.FLAG_TEST_ONLY != 0
    }

    /** Best-effort emulator detection (hardware + fingerprint markers). */
    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT ?: ""
        val hardware = Build.HARDWARE ?: ""
        val product = Build.PRODUCT ?: ""
        val model = Build.MODEL ?: ""
        return fingerprint.startsWith("generic") ||
            fingerprint.startsWith("unknown") ||
            product.contains("sdk_gphone") ||
            product.contains("emulator") ||
            product.contains("simulator") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            model.contains("Emulator") ||
            model.contains("Android SDK built for x86")
    }

    /** Best-effort root detection: common su locations + test-keys build tags. */
    private fun isRooted(): Boolean {
        val buildTags = Build.TAGS ?: ""
        if (buildTags.contains("test-keys")) return true
        val suPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        return suPaths.any { File(it).exists() }
    }
}