package com.example.screen_share_janus

import io.flutter.embedding.android.FlutterActivity

import android.content.Context
import android.content.Intent

import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FixFlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
    }
}

open class FixFlutterActivity : FlutterActivity() {
    override fun onDestroy() {
        flutterEngine?.platformViewsController?.onDetachedFromJNI()
        super.onDestroy()
    }
    companion object {
        fun createIntent(context: Context, initialRoute: String = "/"): Intent {
            return Intent(context, FixFlutterActivity::class.java)
                    .putExtra("initial_route", initialRoute)
                    .putExtra("background_mode", "opaque")
                    .putExtra("destroy_engine_with_activity", true)
        }
    }
}