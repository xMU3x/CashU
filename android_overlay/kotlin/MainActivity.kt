package __PKG__

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    private fun granted(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun permState(): Map<String, Boolean> = mapOf(
        "receive" to granted(Manifest.permission.RECEIVE_SMS),
        "read" to granted(Manifest.permission.READ_SMS),
        "notif" to (Build.VERSION.SDK_INT < 33 || granted("android.permission.POST_NOTIFICATIONS"))
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ctx = applicationContext
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashu/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "setConfig" -> { SmsEngine.saveConfig(ctx, call.arguments as String); result.success(true) }
                "perms" -> result.success(permState())
                "requestPerms" -> {
                    val need = ArrayList<String>()
                    if (!granted(Manifest.permission.RECEIVE_SMS)) need.add(Manifest.permission.RECEIVE_SMS)
                    if (!granted(Manifest.permission.READ_SMS)) need.add(Manifest.permission.READ_SMS)
                    if (Build.VERSION.SDK_INT >= 33 && !granted("android.permission.POST_NOTIFICATIONS")) need.add("android.permission.POST_NOTIFICATIONS")
                    if (need.isEmpty()) result.success(permState()) else {
                        pending = result
                        requestPermissions(need.toTypedArray(), 4411)
                    }
                }
                "drain" -> result.success(SmsEngine.drain(ctx))
                "parse" -> {
                    val a = call.arguments as Map<*, *>
                    val o = SmsEngine.parse(ctx, (a["sender"] as? String) ?: "", (a["body"] as? String) ?: "", System.currentTimeMillis())
                    result.success(o?.toString() ?: "")
                }
                "scanInbox" -> {
                    val days = (call.arguments as? Int) ?: 30
                    Thread {
                        val r = try { SmsEngine.scanInbox(ctx, days) } catch (e: Exception) { "[]" }
                        runOnUiThread { result.success(r) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "cashu/sms_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { SmsEngine.sink = events }
            override fun onCancel(arguments: Any?) { SmsEngine.sink = null }
        })
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4411) {
            pending?.success(permState())
            pending = null
        }
    }
}
