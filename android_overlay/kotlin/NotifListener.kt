package __PKG__

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/** قائمة التطبيقات اللي المستخدم اختارها لتتبّع إشعاراتها (محلية على الجهاز فقط). أي تطبيق خارجها بيتجاهل بالكامل. */
object NotifApps {
    private const val PREFS = "cashu_notif_apps"
    private const val KEY = "pkgs"

    @Synchronized
    fun set(ctx: Context, pkgs: Set<String>) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putStringSet(KEY, HashSet(pkgs)).apply()
    }

    @Synchronized
    fun allowed(ctx: Context, pkg: String): Boolean =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet(KEY, emptySet())?.contains(pkg) == true
}

/**
 * يلتقط إشعارات تطبيقات البنوك اللي المستخدم اختارها بس (مش أي إشعار) محليًا، ويحطها في نفس طابور الرسائل
 * عشان تعدّي على محرك التحليل الأوفلاين. لا شبكة ولا إرسال لأي خادم.
 * لازم المستخدم يفعّل «الوصول للإشعارات» لتطبيق CashU من إعدادات الجهاز.
 */
class NotifListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        val pkg = n.packageName ?: return
        if (pkg == packageName) return // إشعارات CashU نفسه
        if (!NotifApps.allowed(applicationContext, pkg)) return // مش من التطبيقات المختارة
        if (n.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = n.notification.extras ?: return
        val title = ex.getCharSequence("android.title")?.toString() ?: ""
        val text = (ex.getCharSequence("android.bigText") ?: ex.getCharSequence("android.text"))?.toString() ?: ""
        val body = listOf(title, text).filter { it.isNotBlank() }.joinToString(" - ")
        if (body.isBlank()) return
        // المرسل = "N:" + اسم الحزمة كامل، فيتميّز عن الرسائل النصية وتتربط الحزمة بحسابها.
        SmsQueue.add(applicationContext, "N:$pkg", body, n.postTime)
    }
}
