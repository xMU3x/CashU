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
    companion object {
        private const val ROUTE_EXTRA = "cashu_route"
        // الأيقونة الأساسية (الافتراضية) = اللي مفعّلة في المانيفست (android:enabled="true") = kPrimaryAppIconId في Dart
        private const val DEFAULT_ICON = "black"
    }
    private var pendingPerm: MethodChannel.Result? = null
    private var launchRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        launchRoute = routeOf(intent)
        // حماية: لازم يكون فيه أيقونة تشغيل واحدة مفعّلة بالظبط (لو حصل أي تعارض نصلّحه هنا).
        try { ensureSingleIcon() } catch (e: Exception) { }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchRoute = routeOf(intent)
    }

    // Flutter 3.50 بيتجاهل الـ extra اسمه "route" في نسخة release (تشديد أمان الـ Intent)، فبنستخدم اسم خاص بالتطبيق.
    // بنقرأ "route" القديم كـ fallback عشان إشعارات اتنشرت قبل التحديث تفضل شغالة.
    private fun routeOf(i: Intent?): String? = i?.getStringExtra(ROUTE_EXTRA) ?: i?.getStringExtra("route")
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
                            result.success(setIcon(id))
                        } catch (e: Exception) {
                            // رسالة تشخيصية بتظهر للمستخدم بدل «تعذّر» العامة
                            result.error("set_failed", "${e.javaClass.simpleName}: ${e.message}", null)
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
                "setNotifApps" -> {
                    val l = (call.arguments as? List<*>)?.map { it.toString() }?.toSet() ?: emptySet()
                    NotifApps.set(applicationContext, l)
                    result.success(true)
                }
                "installedApps" -> {
                    Thread {
                        try {
                            val rows = installedApps()
                            runOnUiThread { result.success(rows) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("apps_failed", e.message, null) }
                        }
                    }.start()
                }
                "powerStatus" -> result.success(powerStatus())
                "requestBattery" -> {
                    try {
                        startActivity(
                            Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                .setData(Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                    } catch (e: Exception) {
                        startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    result.success(true)
                }
                "openAppPermissions" -> {
                    // شاشة «إيقاف نشاط التطبيق لو مش مستخدم»: بنجرّب أنسب Intent ونقع على تفاصيل التطبيق ثم الإعدادات العامة لو الجهاز مش داعمه.
                    val pkgUri = Uri.parse("package:$packageName")
                    val tries = ArrayList<Intent>()
                    if (Build.VERSION.SDK_INT >= 30) tries.add(Intent(Intent.ACTION_AUTO_REVOKE_PERMISSIONS).setData(pkgUri))
                    tries.add(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(pkgUri))
                    tries.add(Intent(android.provider.Settings.ACTION_SETTINGS))
                    result.success(startFirstResolvable(tries))
                }
                "openAppDetails" -> {
                    // شاشة تفاصيل التطبيق (البطارية/الشغل في الخلفية/الصلاحيات) — بدل ما نفتح شاشة الصلاحيات الغلط.
                    val pkgUri = Uri.parse("package:$packageName")
                    val tries = arrayListOf(
                        Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(pkgUri),
                        Intent(android.provider.Settings.ACTION_SETTINGS)
                    )
                    result.success(startFirstResolvable(tries))
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

    // معرّفات الأيقونات ← اسم الـ activity-alias في AndroidManifest (لازم تتطابق مع lib/ui/app_icons_data.dart)
    private val iconAliases = linkedMapOf(
        "black" to "IconBlack", "navy" to "IconNavy", "blue" to "IconBlue", "mint" to "IconMint", "green" to "IconGreen",
        "gold" to "IconGold", "cream" to "IconCream", "graphite" to "IconGraphite", "royal" to "IconRoyal", "violet" to "IconViolet",
    )

    private fun iconComponent(id: String) = android.content.ComponentName(packageName, "__PKG__." + iconAliases[id])

    private fun iconState(id: String) = packageManager.getComponentEnabledSetting(iconComponent(id))

    // مفعّلة فعليًا: صريحة (ENABLED) أو افتراضية من المانيفست (DEFAULT) وهي الأساسية بس.
    private fun iconOn(id: String): Boolean {
        val st = iconState(id)
        return st == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            (st == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && id == DEFAULT_ICON)
    }

    // اختيار المستخدم الصريح (ENABLED) بيغلب الافتراضي؛ لو مفيش، الأساسية. (مهم بعد التحديث: مستخدم اختار أيقونة قبل كده ما يرجعش للأسود.)
    private fun currentIcon(): String =
        iconAliases.keys.firstOrNull { iconState(it) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED }
            ?: iconAliases.keys.firstOrNull { iconOn(it) }
            ?: DEFAULT_ICON

    private fun ensureSingleIcon() {
        if (iconAliases.keys.count { iconOn(it) } != 1) setIcon(currentIcon())
    }

    private fun setIcon(id: String): String {
        val pm = packageManager
        // نفعّل الجديدة الأول (عشان يفضل دايمًا أيقونة تشغيل واحدة على الأقل) وبعدين نعطّل الباقي.
        pm.setComponentEnabledSetting(iconComponent(id), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
        for (other in iconAliases.keys) {
            if (other != id) {
                pm.setComponentEnabledSetting(iconComponent(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
            }
        }
        // تحقّق من الحالة الفعلية في النظام (بدل ما نفترض إن الاستدعاء نجح)
        val on = iconAliases.keys.filter { iconOn(it) }
        if (on != listOf(id)) throw IllegalStateException("verify failed, enabled=$on")
        return id
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
            putExtra(ROUTE_EXTRA, route)
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

    /** التطبيقات القابلة للتشغيل (لاختيار تطبيق البنك). بدون صلاحية QUERY_ALL_PACKAGES: بنستعمل <queries> للـ launcher بس. */
    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        val q = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any>>()
        for (ri in pm.queryIntentActivities(q, 0)) {
            val pkg = ri.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seen.add(pkg)) continue
            out.add(mapOf("name" to ri.loadLabel(pm).toString(), "pkg" to pkg))
        }
        out.sortBy { (it["name"] as String).lowercase() }
        return out
    }


    /** يبدأ أول Intent بيتفتح فعلًا (بعض الأجهزة مبتدعمش Intent معين فبيرمي ActivityNotFoundException؛ منستخدمش resolveActivity عشان قيود رؤية الحزم في أندرويد ١١+). */
    private fun startFirstResolvable(intents: List<Intent>): Boolean {
        for (i in intents) {
            try {
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                return true
            } catch (e: Exception) {
                // نجرّب اللي بعده
            }
        }
        return false
    }

    /** حالة بقاء التتبع شغال: البطارية بدون قيود · الشغل في الخلفية · عدم سحب الصلاحيات تلقائيًا. */
    private fun powerStatus(): Map<String, Boolean> {
        val pm = getSystemService(android.os.PowerManager::class.java)
        val battery = try { pm.isIgnoringBatteryOptimizations(packageName) } catch (e: Exception) { false }
        val background = try {
            if (Build.VERSION.SDK_INT >= 28) !getSystemService(android.app.ActivityManager::class.java).isBackgroundRestricted else true
        } catch (e: Exception) { true }
        val revoke = try {
            if (Build.VERSION.SDK_INT >= 30) packageManager.isAutoRevokeWhitelisted else true
        } catch (e: Exception) { true }
        return mapOf("battery" to battery, "background" to background, "revoke" to revoke)
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
