package com.flousy.budget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony

/** بيستقبل أي SMS (حتى والتطبيق مقفول)، يحفظ المالي منها في الطابور، وينبّه المستخدم. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val bySender = LinkedHashMap<String, StringBuilder>()
        var ts = System.currentTimeMillis()
        for (m in msgs) {
            val s = m.originatingAddress ?: ""
            bySender.getOrPut(s) { StringBuilder() }.append(m.messageBody ?: "")
            ts = m.timestampMillis
        }
        var any = false
        for ((s, b) in bySender) {
            if (SmsQueue.add(ctx, s, b.toString(), ts)) any = true
        }
        if (any) notifyNew(ctx)
    }

    private fun notifyNew(ctx: Context) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel("sms_detected", "رسائل البنك", NotificationManager.IMPORTANCE_DEFAULT)
                )
                Notification.Builder(ctx, "sms_detected")
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(ctx)
            }
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getActivity(ctx, 0, launch ?: Intent(), flags)
            val n = builder
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setContentTitle("فلوسي")
                .setContentText("رصدنا رسالة مالية جديدة — افتح التطبيق لمراجعتها")
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build()
            nm.notify(7001, n)
        } catch (e: Exception) {
            // الإشعارات اختيارية؛ الرسالة اتحفظت في الطابور أصلًا
        }
    }
}
