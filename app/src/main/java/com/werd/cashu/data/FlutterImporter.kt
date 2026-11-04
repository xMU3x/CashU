package com.werd.cashu.data

import android.content.Context
import com.werd.cashu.data.db.AppDb
import com.werd.cashu.data.model.*
import kotlinx.serialization.json.*

/**
 * ترحيل بيانات نسخة Flutter (SharedPreferences: ملف FlutterSharedPreferences، المفاتيح flutter.tyr:tyr_*).
 * يعمل مرة واحدة، لا يحذف أي شيء من ملف Flutter، ويدمج بقاعدة «الأحدث u يفوز» فلا يكتب فوق بيانات أحدث في Room.
 * ملاحظة: يقرأ فقط لو التطبيق الجديد بنفس applicationId (تحديث فوق النسخة القديمة) — غير ذلك استخدم النسخ الاحتياطي/المزامنة.
 */
object FlutterImporter {
    private const val DONE = "cashu_import"

    fun parseRecords(raw: String?): List<JsonObject> {
        if (raw.isNullOrBlank()) return emptyList()
        val root = runCatching { Json.parseToJsonElement(raw) }.getOrNull() as? JsonObject ?: return emptyList()
        return root.values.mapNotNull { it as? JsonObject }
    }

    private fun <T> newest(existing: Map<String, T>, incoming: List<T>, id: (T) -> String, u: (T) -> Long): List<T> =
        incoming.filter { x -> existing[id(x)]?.let { u(x) > u(it) } ?: true }

    suspend fun runOnce(ctx: Context, db: AppDb): Boolean {
        val flag = ctx.getSharedPreferences(DONE, Context.MODE_PRIVATE)
        if (flag.getBoolean("v1", false)) return false
        val p = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        fun raw(k: String) = p.getString("flutter.tyr:$k", null)

        val accs = parseRecords(raw("tyr_acc")).map(Account::fromJson).filter { it.id.isNotEmpty() }
        val txs = parseRecords(raw("tyr_tx")).map(Tx::fromJson).filter { it.id.isNotEmpty() }
        val buds = parseRecords(raw("tyr_bud")).map(Budget::fromJson).filter { it.id.isNotEmpty() }
        val loans = parseRecords(raw("tyr_loan")).map(Loan::fromJson).filter { it.id.isNotEmpty() }
        val goals = parseRecords(raw("tyr_goal")).map(Goal::fromJson).filter { it.id.isNotEmpty() }
        val cats = parseRecords(raw("tyr_ctg")).map(CatDef::fromJson).filter { it.id.isNotEmpty() }

        db.accounts().upsertAll(newest(db.accounts().all().associateBy { it.id }, accs, { it.id }, { it.u }))
        db.tx().upsertAll(newest(db.tx().all().associateBy { it.id }, txs, { it.id }, { it.u }))
        db.budgets().upsertAll(newest(db.budgets().all().associateBy { it.id }, buds, { it.id }, { it.u }))
        db.loans().upsertAll(newest(db.loans().all().associateBy { it.id }, loans, { it.id }, { it.u }))
        db.goals().upsertAll(newest(db.goals().all().associateBy { it.id }, goals, { it.id }, { it.u }))
        db.cats().upsertAll(newest(db.cats().all().associateBy { it.id }, cats, { it.id }, { it.u }))

        // التحويلات القديمة → معاملتين مربوطتين (نفس سلوك Dart).
        val names = (db.accounts().all()).associate { it.id to it.name }
        val migrated = Calc.migrateLegacyTransfers(db.tx().all(), { names[it] ?: "" }, System.currentTimeMillis())
        if (migrated.isNotEmpty()) db.tx().upsertAll(migrated)

        flag.edit().putBoolean("v1", true).apply()
        return true
    }
}
