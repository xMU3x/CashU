package com.werd.cashu.data.sync

import android.content.Context
import android.net.Uri
import androidx.room.InvalidationTracker
import com.werd.cashu.BuildConfig
import com.werd.cashu.data.CatSeeder
import com.werd.cashu.data.db.AppDb
import com.werd.cashu.data.model.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder

enum class SyncStatus { OFF, SYNCING, OK, ERROR, OFFLINE }

data class SyncUi(
    val status: SyncStatus = SyncStatus.OFF,
    val error: String = "",
    val last: Long = 0,
    val email: String = "",
    val signedIn: Boolean = false,
    val ready: Boolean = false,
)

data class AuthResult(val error: String? = null, val needsConfirm: Boolean = false)

private class AuthExpired : Exception()
private class Resp(val code: Int, val body: String)
private class Row(val value: JsonElement?, val ts: Long)
private class Spec(val key: String, val read: suspend () -> JsonObject, val write: suspend (JsonObject) -> Unit)

/**
 * مزامنة Supabase عبر REST (GoTrue + PostgREST) على جدول cash_sync بنفس شكل بيانات تطبيق Flutter.
 * القاعدة: سحب ← دمج على مستوى السجل (الأحدث u يفوز) ← رفع لو الناتج مختلف. لا حذف فعلي أبدًا.
 * المفاتيح اللي لسه ما اتنقلتش لواجهة native بتتخزن خام وما بتترفعش (ما نلمسهاش على السيرفر).
 */
class SyncService(ctx: Context, private val db: AppDb, private val scope: CoroutineScope) {
    private val prefs = ctx.applicationContext.getSharedPreferences("cashu_session", Context.MODE_PRIVATE)
    private val base = BuildConfig.SUPABASE_URL
    private val anon = BuildConfig.SUPABASE_ANON_KEY.trim()
    val ready: Boolean get() = base.isNotEmpty() && SyncConfig.keyLooksValid(anon)

    private val _ui = MutableStateFlow(SyncUi(ready = ready))
    val ui: StateFlow<SyncUi> = _ui

    private val mutex = Mutex()
    private var again = false
    private var debounce: Job? = null
    private var retry: Job? = null

    private val rawKeys = listOf("tyr_cat", "tyr_set", "tyr_sub", "tyr_assoc", "tyr_inst")

    private fun uid(): String = prefs.getString("uid", "") ?: ""
    private fun signedIn(): Boolean = ready && uid().isNotEmpty() && !prefs.getString("refresh", "").isNullOrEmpty()
    private fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")

    private fun pushUi(status: SyncStatus? = null, err: String = "") {
        _ui.update {
            it.copy(
                ready = ready, signedIn = signedIn(), email = prefs.getString("email", "") ?: "",
                status = status ?: it.status, error = err, last = prefs.getLong("last", 0),
            )
        }
    }

    fun start() {
        pushUi(if (signedIn()) SyncStatus.OK else SyncStatus.OFF)
        db.invalidationTracker.addObserver(
            object : InvalidationTracker.Observer(arrayOf("accounts", "tx", "budgets", "goals", "categories", "loans")) {
                override fun onInvalidated(tables: Set<String>) {
                    if (signedIn()) scheduleRun()
                }
            },
        )
        scope.launch { if (signedIn()) run() else seedCategories() }
    }

    fun onResume() {
        if (signedIn() && System.currentTimeMillis() - prefs.getLong("last", 0) > 60_000) runAsync()
    }

    fun runAsync() {
        scope.launch { run() }
    }

    private fun scheduleRun() {
        debounce?.cancel()
        debounce = scope.launch { delay(2500); run() }
    }

    private fun retryLater() {
        retry?.cancel()
        retry = scope.launch { delay(30_000); run() }
    }

    // ---------------- HTTP ----------------
    private fun http(method: String, url: String, headers: Map<String, String>, body: String? = null): Resp {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 15_000
            c.readTimeout = 30_000
            headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
            if (body != null) {
                c.doOutput = true
                c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = c.responseCode
            val stream = if (code in 200..299) c.inputStream else c.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            return Resp(code, text)
        } finally {
            c.disconnect()
        }
    }

    private fun authHeaders() = mapOf("apikey" to anon, "Content-Type" to "application/json")
    private fun bearer(token: String) = mapOf("apikey" to anon, "Authorization" to "Bearer $token", "Content-Type" to "application/json")
    private fun parseObj(s: String): JsonObject? = runCatching { Json.parseToJsonElement(s) as? JsonObject }.getOrNull()
    private fun JsonObject.str(k: String): String? = (this[k] as? JsonPrimitive)?.contentOrNull

    private fun errMsg(r: Resp): String {
        val o = parseObj(r.body)
        return listOf("error_description", "msg", "message", "error").firstNotNullOfOrNull { o?.str(it) } ?: "HTTP ${r.code}"
    }

    // ---------------- Auth ----------------
    suspend fun signIn(email: String, password: String, create: Boolean): AuthResult = withContext(Dispatchers.IO) {
        if (!ready) return@withContext AuthResult("لم يتم ضبط المزامنة (SUPABASE_ANON_KEY).")
        try {
            val body = buildJsonObject { put("email", email); put("password", password) }.toString()
            val r = if (create) {
                http("POST", "$base/auth/v1/signup?redirect_to=${enc(SyncConfig.NATIVE_REDIRECT)}", authHeaders(), body)
            } else {
                http("POST", "$base/auth/v1/token?grant_type=password", authHeaders(), body)
            }
            val o = parseObj(r.body)
            if (r.code in 200..299 && o != null && o["access_token"] != null) {
                saveSession(o)
                runAsync()
                AuthResult()
            } else if (r.code in 200..299 && create) {
                AuthResult(needsConfirm = true)
            } else {
                AuthResult(errMsg(r))
            }
        } catch (e: IOException) {
            AuthResult("تعذّر الاتصال بالإنترنت")
        }
    }

    fun googleUrl(): String =
        "$base/auth/v1/authorize?provider=google&redirect_to=${enc(SyncConfig.NATIVE_REDIRECT)}&prompt=select_account"

    /** العودة من جوجل/رابط تأكيد البريد: com.werd.cashu://auth#access_token=... */
    fun handleRedirect(uri: Uri) {
        scope.launch(Dispatchers.IO) {
            val frag = uri.encodedFragment ?: uri.encodedQuery ?: return@launch
            val p = frag.split('&').mapNotNull { kv ->
                kv.split('=', limit = 2).takeIf { it.size == 2 }
                    ?.let { URLDecoder.decode(it[0], "UTF-8") to URLDecoder.decode(it[1], "UTF-8") }
            }.toMap()
            val err = p["error_description"] ?: p["error"]
            if (err != null) {
                pushUi(SyncStatus.ERROR, err)
                return@launch
            }
            val access = p["access_token"] ?: return@launch
            try {
                prefs.edit().putString("uid", "").apply()
                saveSession(
                    buildJsonObject {
                        put("access_token", access)
                        put("refresh_token", p["refresh_token"] ?: "")
                        put("expires_in", p["expires_in"]?.toLongOrNull() ?: 3600L)
                    },
                )
                run()
            } catch (e: IOException) {
                pushUi(SyncStatus.OFFLINE, e.message ?: "")
            }
        }
    }

    private fun saveSession(o: JsonObject) {
        val access = o.str("access_token") ?: return
        val refresh = o.str("refresh_token") ?: prefs.getString("refresh", "") ?: ""
        val expIn = (o["expires_in"] as? JsonPrimitive)?.longOrNull ?: 3600L
        val user = o["user"] as? JsonObject
        val e = prefs.edit()
            .putString("access", access)
            .putString("refresh", refresh)
            .putLong("exp", System.currentTimeMillis() + expIn * 1000)
        user?.str("id")?.let { e.putString("uid", it) }
        user?.str("email")?.let { e.putString("email", it) }
        e.apply()
        if (uid().isEmpty()) fetchUser(access)
        pushUi()
    }

    private fun fetchUser(access: String) {
        val r = http("GET", "$base/auth/v1/user", mapOf("apikey" to anon, "Authorization" to "Bearer $access"))
        val o = parseObj(r.body) ?: return
        val e = prefs.edit()
        o.str("id")?.let { e.putString("uid", it) }
        o.str("email")?.let { e.putString("email", it) }
        e.apply()
    }

    private fun ensureToken(): String {
        val access = prefs.getString("access", "") ?: ""
        if (access.isNotEmpty() && prefs.getLong("exp", 0) - System.currentTimeMillis() > 60_000) return access
        val refresh = prefs.getString("refresh", "") ?: ""
        if (refresh.isEmpty()) throw AuthExpired()
        val r = http(
            "POST", "$base/auth/v1/token?grant_type=refresh_token", authHeaders(),
            buildJsonObject { put("refresh_token", refresh) }.toString(),
        )
        val o = parseObj(r.body)
        if (r.code in 200..299 && o != null) {
            saveSession(o)
            return prefs.getString("access", "") ?: throw AuthExpired()
        }
        if (r.code == 400 || r.code == 401 || r.code == 403) throw AuthExpired()
        throw IOException("HTTP ${r.code}")
    }

    private fun clearSession() {
        prefs.edit().clear().apply()
    }

    fun logout() {
        clearSession()
        pushUi(SyncStatus.OFF)
    }

    /** يحذف الحساب من السيرفر (RPC delete_my_account) ثم يمسح البيانات المحلية — المستخدم لازم يكون أكّد في الواجهة. */
    suspend fun deleteAccount(): Boolean = withContext(Dispatchers.IO) {
        try {
            val token = ensureToken()
            val r = http("POST", "$base/rest/v1/rpc/delete_my_account", bearer(token), "{}")
            if (r.code !in 200..299) return@withContext false
            clearSession()
            db.clearAllTables()
            pushUi(SyncStatus.OFF)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ---------------- Sync ----------------
    suspend fun seedCategories() {
        if (db.cats().all().isEmpty()) db.cats().upsertAll(CatSeeder.seed())
    }

    suspend fun run() {
        if (!signedIn()) return
        if (!mutex.tryLock()) {
            again = true
            return
        }
        try {
            pushUi(SyncStatus.SYNCING)
            withContext(Dispatchers.IO) { doSync() }
            prefs.edit().putLong("last", System.currentTimeMillis()).apply()
            pushUi(SyncStatus.OK)
            seedCategories()
        } catch (e: AuthExpired) {
            clearSession()
            pushUi(SyncStatus.OFF, "انتهت الجلسة — سجّل الدخول من جديد")
        } catch (e: CancellationException) {
            throw e
        } catch (e: IOException) {
            pushUi(SyncStatus.OFFLINE, e.message ?: "")
            retryLater()
        } catch (e: Exception) {
            pushUi(SyncStatus.ERROR, e.message ?: e.toString())
            retryLater()
        } finally {
            mutex.unlock()
            if (again) {
                again = false
                scope.launch { delay(500); run() }
            }
        }
    }

    private suspend fun doSync() {
        val token = ensureToken()
        val uid = uid()
        val remote = fetchRows(uid, token)
        val rows = ArrayList<JsonObject>()
        val now = System.currentTimeMillis()
        for (s in specs()) {
            val remoteMap = remote[s.key]?.value as? JsonObject
            val out = SyncCore.mergeRecords(s.read(), remoteMap)
            s.write(out.merged)
            if (out.push) {
                rows += buildJsonObject {
                    put("user_id", uid)
                    put("key", s.key)
                    put("value", out.merged)
                    put("ts", now)
                }
            }
        }
        for (k in rawKeys) {
            val row = remote[k] ?: continue
            val v = row.value ?: continue
            val cur = db.kv().get(k)
            if (cur == null || row.ts > cur.ts) db.kv().upsert(RawKv(k, v.toString(), row.ts))
        }
        if (rows.isNotEmpty()) pushRows(rows, token)
    }

    private fun fetchRows(uid: String, token: String): Map<String, Row> {
        val r = http(
            "GET", "$base/rest/v1/${SyncConfig.TABLE}?select=key,value,ts&user_id=eq.${enc(uid)}",
            bearer(token) + ("Accept" to "application/json"),
        )
        if (r.code == 401) throw AuthExpired()
        if (r.code !in 200..299) throw IOException("HTTP ${r.code}: ${errMsg(r)}")
        val arr = Json.parseToJsonElement(r.body) as? JsonArray ?: return emptyMap()
        val out = HashMap<String, Row>()
        for (e in arr) {
            val o = e as? JsonObject ?: continue
            val k = o.str("key") ?: continue
            if (k !in SyncConfig.SYNC_KEYS) continue
            out[k] = Row(o["value"]?.takeIf { it !is JsonNull }, (o["ts"] as? JsonPrimitive)?.longOrNull ?: 0L)
        }
        return out
    }

    private fun pushRows(rows: List<JsonObject>, token: String) {
        val r = http(
            "POST", "$base/rest/v1/${SyncConfig.TABLE}?on_conflict=user_id,key",
            bearer(token) + ("Prefer" to "resolution=merge-duplicates,return=minimal"),
            JsonArray(rows).toString(),
        )
        if (r.code == 401) throw AuthExpired()
        if (r.code !in 200..299) throw IOException("HTTP ${r.code}: ${errMsg(r)}")
    }

    private fun <T> toObj(items: List<T>, id: (T) -> String, json: (T) -> JsonObject): JsonObject =
        JsonObject(items.filter { id(it).isNotEmpty() }.associate { id(it) to json(it) })

    /** يكتب فقط السجلات اللي اتغيّرت فعلًا (عشان ما نعملش invalidation وحلقة مزامنة لا نهائية). */
    private suspend fun <T> applyChanged(items: List<T>, existing: List<T>, id: (T) -> String, save: suspend (List<T>) -> Unit) {
        val ex = existing.associateBy(id)
        val changed = items.filter { id(it).isNotEmpty() && ex[id(it)] != it }
        if (changed.isNotEmpty()) save(changed)
    }

    private fun <T> spec(
        key: String,
        all: suspend () -> List<T>,
        id: (T) -> String,
        toJ: (T) -> JsonObject,
        fromJ: (JsonObject) -> T,
        save: suspend (List<T>) -> Unit,
    ): Spec = Spec(
        key,
        { toObj(all(), id, toJ) },
        { m -> applyChanged(m.values.mapNotNull { (it as? JsonObject)?.let(fromJ) }, all(), id, save) },
    )

    private fun specs(): List<Spec> = listOf(
        spec<Account>("tyr_acc", { db.accounts().all() }, { it.id }, { it.toJson() }, { Account.fromJson(it) }, { db.accounts().upsertAll(it) }),
        spec<Budget>("tyr_bud", { db.budgets().all() }, { it.id }, { it.toJson() }, { Budget.fromJson(it) }, { db.budgets().upsertAll(it) }),
        spec<Tx>("tyr_tx", { db.tx().all() }, { it.id }, { it.toJson() }, { Tx.fromJson(it) }, { db.tx().upsertAll(it) }),
        spec<Loan>("tyr_loan", { db.loans().all() }, { it.id }, { it.toJson() }, { Loan.fromJson(it) }, { db.loans().upsertAll(it) }),
        spec<Goal>("tyr_goal", { db.goals().all() }, { it.id }, { it.toJson() }, { Goal.fromJson(it) }, { db.goals().upsertAll(it) }),
        spec<CatDef>("tyr_ctg", { db.cats().all() }, { it.id }, { it.toJson() }, { CatDef.fromJson(it) }, { db.cats().upsertAll(it) }),
    )
}
