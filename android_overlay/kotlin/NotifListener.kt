package __PKG__

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * يلتقط إشعارات تطبيقات المعاملات المالية (بنوك/محافظ/إنستاباي) محليًا فقط، ويحطها في نفس طابور الرسائل
 * عشان تعدّي على محرك التحليل الأوفلاين (والمشبوه منها يروح للمراجعة). لا شبكة ولا إرسال لأي خادم.
 * لازم المستخدم يفعّل «الوصول للإشعارات» لتطبيق CashU من إعدادات الجهاز.
 */
class NotifListener : NotificationListenerService() {
    private val finHints = listOf(
        "instapay", "fawry", "vodafone", "cash", "wallet", "bank", "banque", "cib", "nbe", "qnb", "alex", "hsbc", "aaib", "adib",
        "faisal", "ahli", "misr", "pay", "meeza", "orange", "etisalat", "we.", "telda", "valu", "contact", "sympl", "halan"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn ?: return
        val pkg = n.packageName ?: return
        if (pkg == packageName) return // إشعارات CashU نفسه
        val low = pkg.lowercase()
        if (finHints.none { low.contains(it) }) return
        val ex = n.notification.extras ?: return
        val title = ex.getCharSequence("android.title")?.toString() ?: ""
        val text = (ex.getCharSequence("android.bigText") ?: ex.getCharSequence("android.text"))?.toString() ?: ""
        val body = listOf(title, text).filter { it.isNotBlank() }.joinToString(" - ")
        if (body.isBlank()) return
        // المرسل = "N:" + آخر جزء من اسم الحزمة، فيتميّز عن الرسائل النصية.
        SmsQueue.add(applicationContext, "N:" + pkg.substringAfterLast('.'), body, n.postTime)
    }
}
