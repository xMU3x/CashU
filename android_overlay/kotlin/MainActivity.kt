package com.flousy.budget

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private val reqCode = 4711

    private fun hasSms(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "budget/sms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasSms())
                    "requestPermission" -> {
                        if (hasSms()) {
                            result.success(true)
                        } else if (pending != null) {
                            result.success(false)
                        } else {
                            pending = result
                            val p = mutableListOf(
                                Manifest.permission.RECEIVE_SMS,
                                Manifest.permission.READ_SMS
                            )
                            if (Build.VERSION.SDK_INT >= 33) p.add("android.permission.POST_NOTIFICATIONS")
                            requestPermissions(p.toTypedArray(), reqCode)
                        }
                    }
                    "drainQueue" -> result.success(SmsQueue.drain(this))
                    "readInbox" -> {
                        val days = call.argument<Int>("days") ?: 30
                        Thread {
                            val r = SmsQueue.readInbox(this, days)
                            runOnUiThread { result.success(r) }
                        }.start()
                    }
                    "openSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == reqCode) {
            pending?.success(hasSms())
            pending = null
        }
    }
}
