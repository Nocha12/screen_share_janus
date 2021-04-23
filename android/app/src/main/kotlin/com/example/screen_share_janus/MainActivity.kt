package com.example.screen_share_janus

import io.flutter.embedding.android.FlutterActivity

import android.content.Context
import android.content.Intent

import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "onthelive.webview/foreground"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForeground" -> {
                    ForegroundService.startService(this)

                    result.success(true)
                }

                "stopForeground" -> {
                    ForegroundService.stopService(this)

                    result.success(true)
                }
            }
        }
    }

    override fun onDetachedFromWindow() {
        ForegroundService.stopService(this)

        super.onDetachedFromWindow()
    }
}