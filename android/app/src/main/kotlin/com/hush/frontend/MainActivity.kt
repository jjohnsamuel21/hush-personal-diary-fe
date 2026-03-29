package com.hush.frontend

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth requires FlutterFragmentActivity (not FlutterActivity).
// The biometric prompt is a DialogFragment — it needs a FragmentManager,
// which only FlutterFragmentActivity provides. Using FlutterActivity causes
// silent authentication failures on real devices.
class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.hush.frontend/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addFlagSecure" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "clearFlagSecure" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
