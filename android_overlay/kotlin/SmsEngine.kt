package __PKG__

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.regex.Pattern

/**
 * محرّك تتبع رسائل البنك (محلي بالكامل): يستبعد رموز التحقق والعمليات الفاشلة،
 * يصنّف العملية بالكلمات المتتبَّعة، يستخرج المبلغ/العملة/آخر 4 أرقام/التاجر ثم يقرر:
 * auto (يُسجَّل تلقائيًا) أو review (يحتاج مراجعة) أو excluded (مستبعد).
 */
object SmsEngine {
    @Volatile var sink: EventChannel.EventSink? = null
    private const val PREFS = "cashu_sms_native"

    // ---------- بيانات ثابتة ----------
    private val secretWords = listOf(
        "otp", "one time password", "one-time password", "verification code", "activation code", "security code",
        "passcode", "do not share", "don't share", "never share", "رمز التحقق", "رمز التأكيد", "رمز التفعيل",
        "كود التحقق", "كود التفعيل", "رمز المرور", "كلمة المرور لمرة واحدة", "كلمة السر المؤقتة", "الرقم السري المؤقت",
        "لا تشارك", "لا تعطي", "لا تفصح"
    )
    private val failedWords = listOf(
        "declined", "rejected", "failed", "unsuccessful", "not successful", "insufficient", "could not be completed",
        "was not completed", "رفض", "مرفوضة", "مرفوض", "تم رفض", "فشل", "فشلت", "غير ناجحة", "لم تتم", "لم يتم",
        "رصيد غير كاف", "الرصيد غير كافي", "تعذر"
    )
    private val balanceWords = listOf(
        "المتاح", "الحد المتاح", "available balance", "avail bal", "avl bal", "balance", "bal ", "available limit",
        "limit is", "الرصيد", "رصيدك", "رصيد"
    )
    // مفتاح المرسل -> الاسم المعروض
    private val banks: Map<String, String> = mapOf(
        "alahly" to "NBE", "nbe" to "NBE", "bankalahly" to "NBE", "cib" to "CIB", "bankmisr" to "Banque Misr", "bm" to "Banque Misr",
        "banquemisr" to "Banque Misr", "banqueducaire" to "BDC", "bdc" to "BDC", "qnb" to "QNB", "alexbank" to "Alexbank", "hsbc" to "HSBC",
        "aaib" to "AAIB", "adib" to "ADIB", "faisal" to "Faisal", "fibe" to "Faisal", "creditagricole" to "CAE", "cae" to "CAE",
        "emiratesnbd" to "ENBD", "enbd" to "ENBD", "mashreq" to "Mashreq", "nbk" to "NBK", "saib" to "SAIB", "aib" to "AIB", "abk" to "ABK",
        "vodafonecash" to "Vodafone Cash", "vodafone" to "Vodafone Cash", "vfcash" to "Vodafone Cash", "ecash" to "e& cash",
        "etisalat" to "e& cash", "etisalatcash" to "e& cash", "orangecash" to "Orange Cash", "orange" to "Orange Cash", "wepay" to "WE Pay",
        "instapay" to "InstaPay", "ipn" to "InstaPay", "fawry" to "Fawry", "valu" to "valU", "meeza" to "Meeza", "telda" to "Telda"
    )
    private val curAliases: List<Pair<String, String>> = listOf(
        "egp" to "EGP", "l.e." to "EGP", "l.e" to "EGP", "le" to "EGP", "e£" to "EGP", "جم" to "EGP", "ج.م." to "EGP", "ج.م" to "EGP",
        "جنيهات" to "EGP", "جنيها" to "EGP", "جنيه" to "EGP",
        "usd" to "USD", "$" to "USD", "دولار" to "USD", "eur" to "EUR", "€" to "EUR", "يورو" to "EUR",
        "sar" to "SAR", "ريال" to "SAR", "aed" to "AED", "درهم" to "AED", "gbp" to "GBP", "£" to "GBP"
    )
    private val kindOrder = listOf("refund", "atm", "xfer_in", "xfer_out", "purchase", "deduct")

    // ---------- أدوات ----------
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun norm(s: String): String {
        val b = StringBuilder()
        for (ch0 in s.lowercase()) {
            var ch = ch0
            when (ch) {
                'أ', 'إ', 'آ' -> ch = 'ا'
                'ة' -> ch = 'ه'
                'ى' -> ch = 'ي'
                'ـ' -> continue
            }
            if (ch in '\u064B'..'\u0652') continue
            if (ch in '\u0660'..'\u0669') ch = '0' + (ch - '\u0660')
            if (ch in '\u06F0'..'\u06F9') ch = '0' + (ch - '\u06F0')
            b.append(ch)
        }
        return b.toString().replace(Regex("\\s+"), " ").trim()
    }

    private fun wordRegex(w: String): Pattern {
        val n = norm(w)
        val arabic = n.isNotEmpty() && n[0] in '\u0600'..'\u06FF'
        val pre = if (arabic) "(?:وال|بال|لل|ال|ف|و|ب|ل)?" else ""
        return Pattern.compile("(?<![\\p{L}\\p{N}])" + pre + Pattern.quote(n) + "(?![\\p{L}\\p{N}])")
    }

    private fun containsWord(text: String, w: String): Boolean = wordRegex(w).matcher(text).find()

    private fun sha(s: String): String {
        val d = MessageDigest.getInstance("SHA-256").digest(s.toByteArray())
        return d.joinToString("") { "%02x".format(it) }.substring(0, 24)
    }

    fun loadConfig(c: Context): JSONObject = try { JSONObject(prefs(c).getString("config", "{}") ?: "{}") } catch (e: Exception) { JSONObject() }
    fun saveConfig(c: Context, json: String) { prefs(c).edit().putString("config", json).apply() }

    private fun parseAmount(t: String): Triple<Double, String, Int>? {
        val num = "(\\d{1,3}(?:,\\d{3})+(?:\\.\\d{1,2})?|\\d+(?:\\.\\d{1,2})?)"
        val alts = curAliases.sortedByDescending { it.first.length }.joinToString("|") { Pattern.quote(it.first) }
        val cur = "(?:$alts)"
        val after = Pattern.compile("(?<![\\d.,])$num\\s?($cur)(?![a-z\\u0600-\\u06FF])")
        val before = Pattern.compile("(?<![a-z\\u0600-\\u06FF])($cur)\\s?$num(?!\\d)")
        data class Hit(val start: Int, val amt: Double, val cur: String)
        val hits = ArrayList<Hit>()
        var m = after.matcher(t)
        while (m.find()) hits.add(Hit(m.start(), m.group(1)!!.replace(",", "").toDouble(), curAliases.first { it.first == m.group(2) }.second))
        m = before.matcher(t)
        while (m.find()) hits.add(Hit(m.start(), m.group(2)!!.replace(",", "").toDouble(), curAliases.first { it.first == m.group(1) }.second))
        hits.sortBy { it.start }
        for (h in hits) {
            val from = maxOf(0, h.start - 30)
            val ctx = t.substring(from, h.start)
            if (balanceWords.any { ctx.contains(norm(it)) }) continue
            if (h.amt <= 0) continue
            return Triple(h.amt, h.cur, h.start)
        }
        return null
    }

    private fun merchantOf(orig: String): String {
        val m = Pattern.compile("(?:\\bat\\b|\\bfrom merchant\\b|\\bmerchant:?|لدى|لدي|عند|في متجر|من التاجر|التاجر:?)\\s*([^\\n]{2,80})", Pattern.CASE_INSENSITIVE).matcher(orig)
        if (!m.find()) return ""
        var r = m.group(1)!!
        val cuts = listOf(";", "|", " on ", " dated ", " date ", " via ", " using ", " with ", " card ", " ref ", " بتاريخ", " يوم", " الساعه", " الساعة", " في ", " بطاقة", " ببطاقة", " كارت", " رقم ", " الرصيد", " رصيد", " المتاح", " للمزيد", " balance", " avail", ". ", ",")
        var idx = r.length
        val low = r.lowercase()
        for (c in cuts) { val i = low.indexOf(c); if (i in 1 until idx) idx = i }
        r = r.substring(0, idx).trim().trim('.', ',', ':', '-')
        return r
    }

    /** يحلّل رسالة. يعيد null إن كانت يجب أن تُتجاهل نهائيًا (شخص/OTP/غير مالية). */
    fun parse(ctx: Context, sender: String, body: String, ts: Long): JSONObject? {
        val cfg = loadConfig(ctx)
        val text = norm(body)
        val s = sender.trim()
        // رسائل الأشخاص (أرقام فقط) تُتجاهل
        if (!s.any { it.isLetter() }) return null
        if (secretWords.any { containsWord(text, it) }) return null
        val key = norm(s).replace(Regex("[^a-z0-9\\u0600-\\u06FF]"), "")
        val bankKey = banks.keys.firstOrNull { key == it || (it.length >= 4 && key.contains(it)) }
        val bankName = if (bankKey != null) banks[bankKey]!! else s
        val out = JSONObject()
        out.put("id", sha("$s|${ts / 60000}|$body"))
        out.put("ts", ts); out.put("sender", s); out.put("body", body)
        out.put("bank", bankKey ?: key); out.put("bankName", bankName)
        if (failedWords.any { containsWord(text, it) }) {
            out.put("status", "excluded"); out.put("reason", "failed"); out.put("kind", ""); out.put("amt", 0.0); out.put("cur", ""); out.put("last4", ""); out.put("merchant", ""); out.put("acc", "")
            return out
        }
        // الكلمات المتتبَّعة
        val words = cfg.optJSONArray("words") ?: JSONArray()
        var kind = ""
        for (k in kindOrder) {
            for (i in 0 until words.length()) {
                val w = words.optJSONObject(i) ?: continue
                if (w.optString("k") == k && containsWord(text, w.optString("t"))) { kind = k; break }
            }
            if (kind.isNotEmpty()) break
        }
        val am = parseAmount(text)
        if (kind.isEmpty() || am == null) {
            // رسالة مالية غير مفهومة لكن فيها مبلغ من جهة معروفة → مراجعة؛ غير ذلك تُتجاهل
            if (am != null && bankKey != null) {
                out.put("status", "review"); out.put("reason", "unknown_kind"); out.put("kind", ""); out.put("amt", am.first); out.put("cur", am.second)
                out.put("last4", last4Of(text)); out.put("merchant", merchantOf(body)); out.put("acc", "")
                return out
            }
            return null
        }
        val l4 = last4Of(text)
        out.put("kind", kind); out.put("amt", am.first); out.put("cur", am.second); out.put("last4", l4); out.put("merchant", merchantOf(body))
        // ربط البطاقة
        var acc = ""; var cardAuto = false
        val cards = cfg.optJSONArray("cards") ?: JSONArray()
        for (i in 0 until cards.length()) {
            val c = cards.optJSONObject(i) ?: continue
            val sameCard = l4.isNotEmpty() && c.optString("last4") == l4
            val sameBank = c.optString("bank").isEmpty() || c.optString("bank") == (bankKey ?: key)
            if (sameCard && sameBank) { acc = c.optString("acc"); cardAuto = c.optBoolean("auto", true); break }
        }
        out.put("acc", acc)
        var status = "auto"; var reason = ""
        if (am.second != "EGP") { status = "review"; reason = "foreign_currency" }
        else if (acc.isEmpty()) { status = "review"; reason = "unlinked_card" }
        else if (kind == "refund") { status = "review"; reason = "kind_needs_review" }
        else if (!cardAuto) { status = "review"; reason = "auto_off" }
        else if (!cfg.optBoolean("auto", true)) { status = "review"; reason = "auto_post_off" }
        else if (bankKey == null) { status = "review"; reason = "unverified_sender" }
        out.put("status", status); out.put("reason", reason)
        return out
    }

    private fun last4Of(t: String): String {
        val m = Pattern.compile("(?:card|account|acct|a/c|ending with|ending|بطاقه|البطاقه|كارت|الكارت|حساب|الحساب|المنتهي|المنتهيه|ينتهي)[^\\d\\n]{0,25}?(?:[*x•#]+)?(\\d{4})(?!\\d)").matcher(t)
        if (m.find()) return m.group(1)!!
        val m2 = Pattern.compile("[*x•#]{2,}\\s?(\\d{4})(?!\\d)").matcher(t)
        return if (m2.find()) m2.group(1)!! else ""
    }

    // ---------- تسليم ----------
    private fun seen(c: Context): MutableList<String> {
        val a = try { JSONArray(prefs(c).getString("seen", "[]")) } catch (e: Exception) { JSONArray() }
        return MutableList(a.length()) { a.getString(it) }
    }
    private fun markSeen(c: Context, id: String) {
        val l = seen(c); l.add(id)
        val t = if (l.size > 600) l.subList(l.size - 600, l.size) else l
        prefs(c).edit().putString("seen", JSONArray(t).toString()).apply()
    }

    fun handle(ctx: Context, sender: String, body: String, ts: Long) {
        val cfg = loadConfig(ctx)
        if (!cfg.optBoolean("enabled", false)) return
        val c = parse(ctx, sender, body, ts) ?: return
        val id = c.getString("id")
        if (seen(ctx).contains(id)) return
        markSeen(ctx, id)
        if (c.getString("status") != "excluded" && cfg.optBoolean("notify", true)) notify(ctx, c, cfg.optString("lang", "ar"))
        val s = sink
        if (s != null) {
            Handler(Looper.getMainLooper()).post { try { s.success(c.toString()) } catch (e: Exception) { enqueue(ctx, c) } }
        } else enqueue(ctx, c)
    }

    private fun enqueue(c: Context, o: JSONObject) {
        synchronized(this) {
            val a = try { JSONArray(prefs(c).getString("queue", "[]")) } catch (e: Exception) { JSONArray() }
            a.put(o)
            prefs(c).edit().putString("queue", a.toString()).apply()
        }
    }

    fun drain(c: Context): String = synchronized(this) {
        val v = prefs(c).getString("queue", "[]") ?: "[]"
        prefs(c).edit().putString("queue", "[]").apply()
        v
    }

    /** مسح صندوق الوارد القديم: يعيد المرشّحين الجدد (لم يُرَوا من قبل) دون إشعارات. */
    fun scanInbox(ctx: Context, days: Int): String {
        val out = JSONArray()
        val since = System.currentTimeMillis() - days.toLong() * 86400000L
        val cur = ctx.contentResolver.query(android.net.Uri.parse("content://sms/inbox"), arrayOf("address", "body", "date"), "date > ?", arrayOf(since.toString()), "date DESC") ?: return "[]"
        cur.use {
            var n = 0
            while (it.moveToNext() && n < 800) {
                n++
                val addr = it.getString(0) ?: continue
                val body = it.getString(1) ?: continue
                val ts = it.getLong(2)
                val c = parse(ctx, addr, body, ts) ?: continue
                if (seen(ctx).contains(c.getString("id"))) continue
                markSeen(ctx, c.getString("id"))
                out.put(c)
            }
        }
        return out.toString()
    }

    // ---------- إشعار ----------
    private fun notify(ctx: Context, c: JSONObject, lang: String) {
        try {
            val ar = lang == "ar"
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val chId = "cashu_sms"
            if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(chId, if (ar) "رسائل البنك" else "Bank messages", NotificationManager.IMPORTANCE_DEFAULT))
            val kindAr = mapOf("purchase" to "شراء", "deduct" to "خصم", "atm" to "سحب نقدي", "xfer_out" to "تحويل صادر", "xfer_in" to "تحويل وارد", "refund" to "استرداد")
            val kindEn = mapOf("purchase" to "Purchase", "deduct" to "Debit", "atm" to "Cash withdrawal", "xfer_out" to "Outgoing transfer", "xfer_in" to "Incoming transfer", "refund" to "Refund")
            val k = c.optString("kind")
            val kl = (if (ar) kindAr else kindEn)[k] ?: (if (ar) "رسالة بنكية" else "Bank message")
            val amt = c.optDouble("amt", 0.0)
            val title = if (amt > 0) "$kl · ${"%.2f".format(amt)} ${c.optString("cur")}" else kl
            val st = c.optString("status")
            val state = if (st == "auto") (if (ar) "تم تسجيلها تلقائيًا" else "Recorded automatically") else (if (ar) "تحتاج مراجعتك" else "Needs your review")
            val l4 = c.optString("last4")
            val text = listOf(c.optString("bankName"), if (l4.isNotEmpty()) "•••• $l4" else "", c.optString("merchant"), state).filter { it.isNotEmpty() }.joinToString(" · ")
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val pi = PendingIntent.getActivity(ctx, 0, launch ?: android.content.Intent(), PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0))
            @Suppress("DEPRECATION")
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, chId) else Notification.Builder(ctx)
            b.setSmallIcon(ctx.applicationInfo.icon).setContentTitle(title).setContentText(text).setAutoCancel(true).setContentIntent(pi)
            nm.notify(c.getString("id").hashCode(), b.build())
        } catch (e: Exception) { /* الإشعار اختياري */ }
    }
}
