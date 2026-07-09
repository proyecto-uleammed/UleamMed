package com.proyecto_uleammed.uleam_med

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "uleammed/permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                "requestFullScreenIntent" -> {
                    requestFullScreenIntent()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun requestFullScreenIntent() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }
}
