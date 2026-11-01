package __PKG__

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** يلتقط الرسائل الواردة ويحفظها محليًا فقط؛ لا شبكة ولا إرسال لأي خادم. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val bodies = LinkedHashMap<String, StringBuilder>()
        var ts = System.currentTimeMillis()
        for (m in msgs) {
            val from = m.originatingAddress ?: continue
            bodies.getOrPut(from) { StringBuilder() }.append(m.messageBody ?: "")
            if (m.timestampMillis > 0) ts = m.timestampMillis
        }
        for ((from, body) in bodies) SmsQueue.add(context, from, body.toString(), ts)
    }
}
