package com.mohamedfarouk.shobaki_academy

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import androidx.annotation.NonNull

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "shobaki/security"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isRecordingDetected" ->
                    result.success(SecurityMonitor.isRecordingSoftwareRunning(this))
                "getDetectedApp" ->
                    result.success(SecurityMonitor.getDetectedRecordingApp())
                else -> result.notImplemented()
            }
        }
    }
}