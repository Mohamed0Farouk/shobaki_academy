package com.mohamedfarouk.shobaki_academy

import android.app.ActivityManager
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build

object SecurityMonitor {
    private var detectedApp = ""

    private val knownPackages = listOf(
        "com.azrecorder",
        "com.hecorat.screenrecorder.free",
        "com.samsung.android.app.sreminder",
        "com.xiaomi.screenrecorder",
        "com.oneplus.screenrecorder",
        "com.oppo.screenrecorder",
        "com.obsproject.obsstudio",
        "com.screenrecorder.recorder",
        "com.duapps.recorder",
        "com.mobivista.android.screenrecorder",
        "com.super.screenrecorder",
        "com.microsoft.rdc.android",
        "com.teamviewer.teamviewer.market",
        "com.km.player",
        "com.sec.android.app.screenrecorder",
        "com.huawei.screenrecorder",
        "com.google.android.apps.recorder",
    )

    fun isRecordingSoftwareRunning(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val displayManager =
                context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val displays = displayManager.displays
            if (displays.size > 1) {
                detectedApp = "Screen Mirroring/Recording"
                return true
            }
        }

        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningApps = activityManager.runningAppProcesses ?: return false

        for (app in runningApps) {
            for (pkg in knownPackages) {
                if (app.processName.contains(pkg, ignoreCase = true)) {
                    detectedApp = app.processName
                    return true
                }
            }
        }

        detectedApp = ""
        return false
    }

    fun getDetectedRecordingApp(): String = detectedApp
}
