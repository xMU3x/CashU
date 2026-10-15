package com.flousy.budget

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

/**
 * طابور الرسائل المالية على الجهاز. التطبيق (Dart) بيفضّيه ويحلّل الرسائل.
 * الفلترة هنا بتمنع إن أي رمز تحقق (OTP) أو رسالة من رقم عادي أو رسالة من غير مبلغ بعملة تتخزّن أصلًا.
 */
object SmsQueue {
    private const val PREFS = "budget_sms"
    private const val KEY = "queue"
    private const val MAX = 300

    private val OTP = Regex(
        "(otp|one.?time|رمز (التحقق|الدخول|سري|تفعيل)|كود (التحقق|التفعيل)|verification code|your code|رمز المرور|passcode|cvv|الرقم السري)",
        RegexOption.IGNORE_CASE
    )
    private val HINT = Regex(
        "(egp|\\bl\\.?e\\b|usd|eur|sar|aed|gbp|جنيه|ج\\.م|جم|دولار|\\\$|€|£|مبلغ)",
        RegexOption.IGNORE_CASE
    )
    private val PHONE_SENDER = Regex("^\\+?\\d{6,}$")

    fun looksFinancial(sender: String, body: String): Boolean {
        if (PHONE_SENDER.matches(sender.replace(" ", ""))) return false
        if (body.length > 600) return false
        if (!body.any { it.isDigit() }) return false
        if (OTP.containsMatchIn(body)) return false
        return HINT.containsMatchIn(body)
    }

    @Synchronized
    fun add(ctx: Context, sender: String, body: String, ts: Long): Boolean {
        if (!looksFinancial(sender, body)) return false
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(p.getString(KEY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optLong("ts") == ts && o.optString("body") == body) return false
        }
        arr.put(JSONObject().put("sender", sender).put("body", body).put("ts", ts))
        val out = JSONArray()
        val start = maxOf(0, arr.length() - MAX)
        for (i in start until arr.length()) out.put(arr.get(i))
        p.edit().putString(KEY, out.toString()).commit()
        return true
    }

    @Synchronized
    fun drain(ctx: Context): String {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val s = p.getString(KEY, "[]") ?: "[]"
        p.edit().remove(KEY).commit()
        return s
    }

    /** قراءة صندوق الوارد لآخر [days] يوم (بتحتاج READ_SMS). */
    fun readInbox(ctx: Context, days: Int): String {
        val out = JSONArray()
        val since = System.currentTimeMillis() - days * 86400000L
        try {
            ctx.contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf("address", "body", "date"),
                "date > ?",
                arrayOf(since.toString()),
                "date DESC"
            )?.use { c ->
                val a = c.getColumnIndex("address")
                val b = c.getColumnIndex("body")
                val d = c.getColumnIndex("date")
                var n = 0
                while (c.moveToNext() && n < 600) {
                    val sender = c.getString(a) ?: ""
                    val body = c.getString(b) ?: ""
                    if (looksFinancial(sender, body)) {
                        out.put(JSONObject().put("sender", sender).put("body", body).put("ts", c.getLong(d)))
                        n++
                    }
                }
            }
        } catch (e: Exception) {
            // مفيش صلاحية أو مشكلة في القراءة → نرجّع اللي اتجمع
        }
        return out.toString()
    }
}
