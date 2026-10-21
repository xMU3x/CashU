package __PKG__

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

    fun shouldKeep(body: String): Boolean {
        if (!body.any { it.isDigit() }) return false
        val low = body.lowercase()
        return otpMarkers.none { low.contains(it) }
    }

    @Synchronized
    fun add(ctx: Context, sender: String, body: String, ts: Long) {
        if (!shouldKeep(body)) return
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = load(p.getString(KEY, null))
        val o = JSONObject()
        o.put("id", "$ts-${(sender + body).hashCode()}")
        o.put("sender", sender)
        o.put("body", body)
        o.put("ts", ts)
        arr.put(o)
        save(ctx, trim(arr))
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
            if (o.optLong("ts") >= cut) items.add(o)
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
