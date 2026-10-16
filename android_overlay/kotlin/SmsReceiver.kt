package __PKG__

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** يستقبل الرسائل حتى لو التطبيق مغلق ويمررها لمحرّك التتبع. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (msgs.isEmpty()) return
        val sender = msgs[0].originatingAddress ?: return
        val body = StringBuilder()
        for (m in msgs) body.append(m.messageBody ?: "")
        val ts = msgs[0].timestampMillis
        val pending = goAsync()
        Thread {
            try { SmsEngine.handle(context.applicationContext, sender, body.toString(), ts) } catch (e: Exception) { } finally { pending.finish() }
        }.start()
    }
}
