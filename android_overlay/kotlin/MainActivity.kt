package __PKG__

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPerm: MethodChannel.Result? = null
    private var launchRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        launchRoute = intent?.getStringExtra("route")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchRoute = intent.getStringExtra("route")
    }
    private val reqCode = 4711

    private fun granted(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // تغيير أيقونة التطبيق (إعدادات ← تغيير الأيقونة): تفعيل activity-alias واحد وتعطيل الباقي.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashu/icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(currentIcon())
                "set" -> {
                    val id = call.argument<String>("id")
                    if (id == null || !iconAliases.containsKey(id)) {
                        result.error("bad_icon", "unknown icon: $id", null)
                    } else {
                        try {
                            setIcon(id)
                            result.success(id)
                        } catch (e: Exception) {
                            result.error("set_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        val smsCh = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashu/sms")
        // لحظة وصول رسالة/إشعار مالي: نبلّغ Dart يسحب الطابور فورًا (من غير انتظار المؤقت)
        SmsQueue.onAdded = { runOnUiThread { try { smsCh.invokeMethod("onQueue", null) } catch (e: Exception) { } } }
        smsCh.setMethodCallHandler { call, result ->
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
                "requestNotifyPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4712)
                    }
                    result.success(true)
                }
                "notify" -> {
                    postNotification(call.argument<String>("title") ?: "", call.argument<String>("body") ?: "", (call.argument<Number>("id") ?: 1).toInt(), call.argument<String>("route") ?: "review")
                    result.success(null)
                }
                "notifAccess" -> result.success(
                    androidx.core.app.NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                )
                "openNotifAccess" -> {
                    startActivity(Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "takeRoute" -> {
                    val r = launchRoute
                    launchRoute = null
                    result.success(r)
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

    // معرّفات الأيقونات ← اسم الـ activity-alias في AndroidManifest (لازم تتطابق مع lib/ui/app_icons.dart)
    private val iconAliases = linkedMapOf(
        "navy" to "IconNavy", "black" to "IconBlack", "blue" to "IconBlue", "mint" to "IconMint", "green" to "IconGreen",
        "gold" to "IconGold", "mintarc" to "IconMintArc", "light" to "IconLight", "royal" to "IconRoyal", "violet" to "IconViolet",
    )

    private fun iconComponent(id: String) = android.content.ComponentName(packageName, "__PKG__." + iconAliases[id])

    private fun iconOn(id: String): Boolean {
        val st = packageManager.getComponentEnabledSetting(iconComponent(id))
        return st == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            (st == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && id == "navy") // navy مفعّلة افتراضيًا في المانيفست
    }

    private fun currentIcon(): String = iconAliases.keys.firstOrNull { iconOn(it) } ?: "navy"

    private fun setIcon(id: String) {
        val pm = packageManager
        // نفعّل الجديدة الأول (عشان يفضل دايمًا أيقونة تشغيل واحدة على الأقل) وبعدين نعطّل الباقي.
        pm.setComponentEnabledSetting(iconComponent(id), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in iconAliases.keys) {
            if (other != id) {
                pm.setComponentEnabledSetting(iconComponent(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }

    private fun postNotification(title: String, body: String, id: Int, route: String) {
        val chId = "cashu_tx"
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(chId, "CashU", NotificationManager.IMPORTANCE_DEFAULT))
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", route)
        }
        val pi = PendingIntent.getActivity(this, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, chId)
            .setContentIntent(pi)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(this).notify(id, n)
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

    override fun onDestroy() {
        SmsQueue.onAdded = null
        super.onDestroy()
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
