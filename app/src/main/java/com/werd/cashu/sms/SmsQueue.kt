package com.werd.cashu.sms

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** طابور رسائل مؤقت على الجهاز فقط. يُحذف كل عنصر بعد تأكيد التطبيق (ack) أو بعد 7 أيام. */
object SmsQueue {
    private const val PREFS = "cashu_sms_queue"
    private const val KEY = "q"
    private const val MAX = 300
    private const val TTL_MS = 7L * 24 * 3600 * 1000

    // علامات تحقق واضحة: لا نخزّن هذه الرسائل أصلًا (تقليل الاحتفاظ بالبيانات الحساسة)
    private val otpMarkers = listOf(
        "otp", "one time password", "one-time password", "verification code", "activation code", "security code", "passcode",
        "رمز التحقق", "رمز التفعيل", "كود التحقق", "كود التفعيل", "كلمة المرور لمرة واحدة"
    )

    // رمز تحقق فعلي (OTP 123456 · الرمز هو 123456 · 123456 is your OTP) — نفس منطق محرك Dart.
    // lazy + try/catch: أي مشكلة في الـ regex ما توقعش التطبيق وقت التشغيل (الـ object بيتحمّل أول ما التطبيق يفتح).
    private val otpCode: Regex? by lazy {
        try {
            Regex(
                "(?:otp|code|passcode|رمز(?:\\s+\\S+){0,2}|كود(?:\\s+\\S+){0,2})\\s*[:=\\-]?\\s*[0-9]{4,8}\\b" +
                    "|(?:otp|code|passcode|رمز|كود)[^.\\n]{0,60}?(?:\\bis|هو|:)\\s*[0-9]{4,8}\\b" +
                    "|\\b[0-9]{4,8}\\s+(?:is|هو)\\s+(?:your|the|رمز|كود)",
                RegexOption.IGNORE_CASE
            )
        } catch (e: Exception) {
            null
        }
    }
    private val moneyHints = listOf(
        "egp", "usd", "eur", "sar", "aed", "جنيه", "ج.م", "جم", "دولار", "يورو", "$", "€", "£",
        "مبلغ", "amount", "purchase", "شراء", "سحب", "خصم", "debit", "credit", "withdraw"
    )

    /** الأرقام العربية/الفارسية → 0-9 عشان مطابقة الأرقام تشتغل على أي جهاز. */
    private fun asciiDigits(s: String): String {
        val b = StringBuilder(s.length)
        for (ch in s) {
            b.append(
                when (ch) {
                    in '\u0660'..'\u0669' -> '0' + (ch - '\u0660')
                    in '\u06F0'..'\u06F9' -> '0' + (ch - '\u06F0')
                    else -> ch
                }
            )
        }
        return b.toString()
    }

    /** يحتفظ بالرسالة إلا لو كانت رمز تحقق فعلي. ذيل «لا تشارك OTP» في رسائل المعاملات لا يُسقطها. */
    fun shouldKeep(body: String): Boolean {
        if (!body.any { it.isDigit() }) return false
        val low = asciiDigits(body).lowercase()
        if (otpMarkers.none { low.contains(it) }) return true
        val re = otpCode
        if (re != null && re.containsMatchIn(low)) return false
        return moneyHints.any { low.contains(it) }
    }

    /** يُستدعى بعد إضافة عنصر جديد (يضبطه MainActivity طول ما التطبيق حي) عشان Dart يسحب الطابور فورًا. */
    @Volatile
    var onAdded: (() -> Unit)? = null

    @Synchronized
    fun add(ctx: Context, sender: String, body: String, ts: Long) {
        if (!shouldKeep(body)) return
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = load(p.getString(KEY, null))
        // نفس الرسالة/الإشعار اتسجل من أقل من دقيقة (تحديث إشعار أو استقبال مزدوج): تجاهل
        for (i in maxOf(0, arr.length() - 25) until arr.length()) {
            val x = arr.optJSONObject(i) ?: continue
            if (x.optString("sender") == sender && x.optString("body") == body && Math.abs(x.optLong("ts") - ts) < 60_000) return
        }
        val o = JSONObject()
        o.put("id", "$ts-${(sender + body).hashCode()}")
        o.put("sender", sender)
        o.put("body", body)
        o.put("ts", ts)
        o.put("at", System.currentTimeMillis()) // وقت الوصول الفعلي (للـ TTL) — ts ممكن يكون وقت مركز الرسائل
        arr.put(o)
        save(ctx, trim(arr))
        try { onAdded?.invoke() } catch (e: Exception) { }
    }

    @Synchronized
    fun snapshot(ctx: Context): JSONArray =
        trim(load(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)))

    @Synchronized
    fun ack(ctx: Context, ids: Set<String>) {
        val arr = snapshot(ctx)
        val out = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (!ids.contains(o.optString("id"))) out.put(o)
        }
        save(ctx, out)
    }

    private fun load(s: String?): JSONArray = try { if (s == null) JSONArray() else JSONArray(s) } catch (e: Exception) { JSONArray() }

    private fun trim(a: JSONArray): JSONArray {
        val cut = System.currentTimeMillis() - TTL_MS
        val items = ArrayList<JSONObject>()
        for (i in 0 until a.length()) {
            val o = a.optJSONObject(i) ?: continue
            if (o.optLong("at", o.optLong("ts")) >= cut) items.add(o)
        }
        val keep = if (items.size > MAX) items.subList(items.size - MAX, items.size) else items
        val out = JSONArray()
        keep.forEach { out.put(it) }
        return out
    }

    private fun save(ctx: Context, a: JSONArray) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, a.toString()).apply()
    }
}
