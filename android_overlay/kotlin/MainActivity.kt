package __PKG__

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPerm: MethodChannel.Result? = null
    private val reqCode = 4711

    private fun granted(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashu/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(granted())
                "requestPermission" -> {
                    if (granted()) {
                        result.success(true)
                    } else if (pendingPerm != null) {
                        result.error("busy", "permission request in progress", null)
                    } else {
                        pendingPerm = result
                        ActivityCompat.requestPermissions(
                            this, arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS), reqCode
                        )
                    }
                }
                "drain" -> result.success(queueAsList())
                "ack" -> {
                    val ids = (call.arguments as? List<*>)?.map { it.toString() }?.toSet() ?: emptySet()
                    SmsQueue.ack(applicationContext, ids)
                    result.success(null)
                }
                "readInbox" -> {
                    val since = (call.argument<Number>("since") ?: 0).toLong()
                    val limit = (call.argument<Number>("limit") ?: 500).toInt()
                    if (!granted()) {
                        result.error("denied", "READ_SMS not granted", null)
                    } else {
                        Thread {
                            try {
                                val rows = readInbox(since, limit)
                                runOnUiThread { result.success(rows) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("read_failed", e.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queueAsList(): List<Map<String, Any>> {
        val arr = SmsQueue.snapshot(applicationContext)
        val out = ArrayList<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(mapOf("id" to o.optString("id"), "sender" to o.optString("sender"), "body" to o.optString("body"), "ts" to o.optLong("ts")))
        }
        return out
    }

    private fun readInbox(since: Long, limit: Int): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        val cur = contentResolver.query(
            Uri.parse("content://sms/inbox"), arrayOf("address", "body", "date"),
            "date >= ?", arrayOf(since.toString()), "date DESC LIMIT $limit"
        ) ?: return out
        cur.use {
            while (it.moveToNext()) {
                val body = it.getString(1) ?: continue
                if (!SmsQueue.shouldKeep(body)) continue
                out.add(mapOf("sender" to (it.getString(0) ?: ""), "body" to body, "ts" to it.getLong(2)))
            }
        }
        return out
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == reqCode) {
            val ok = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPerm?.success(ok)
            pendingPerm = null
        } else {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
