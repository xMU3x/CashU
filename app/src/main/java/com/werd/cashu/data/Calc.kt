package com.werd.cashu.data

import com.werd.cashu.data.model.*

/** منطق الأرصدة — نقل حرفي من repo.dart (bal / balAt / receivables / liabilities). دوال نقية قابلة للاختبار. */
object Calc {
    private fun delta(t: Tx, accId: String): Double {
        val v = t.base
        return when (t.type) {
            "adj", "loan" -> if (t.acc == accId) t.sign * v else 0.0
            "inc" -> if (t.acc == accId) v else 0.0
            "exp" -> if (t.acc == accId) -v else 0.0
            "xfer" -> (if (t.acc == accId) -v else 0.0) + (if (t.to == accId) v else 0.0)
            else -> 0.0
        }
    }

    fun bal(acc: Account?, accId: String, tx: Collection<Tx>): Double =
        (acc?.start ?: 0.0) + tx.filter { !it.del && !it.pend }.sumOf { delta(it, accId) }

    /** رصيد الحساب قبل اللحظة [beforeTs] (للشرائح الشهرية). */
    fun balAt(acc: Account?, accId: String, tx: Collection<Tx>, beforeTs: Long): Double =
        (acc?.start ?: 0.0) + tx.filter { !it.del && !it.pend && it.ts < beforeTs }.sumOf { delta(it, accId) }

    fun receivables(loans: Collection<Loan>): Double =
        loans.filter { !it.del && !it.settled && it.dir == "owed" && it.nw }.sumOf { it.leftBase }

    fun debts(loans: Collection<Loan>): Double =
        loans.filter { !it.del && !it.settled && it.dir == "owe" && it.nw }.sumOf { it.leftBase }

    /** مجموع أرصدة الحسابات النشطة. (بطاقات الائتمان: الرصيد الخام لحد ما extras.cardEffBal يتنقل.) */
    fun accountsTotal(accs: Collection<Account>, tx: Collection<Tx>): Double =
        accs.filter { !it.del && !it.arch }.sumOf { bal(it, it.id, tx) }

    fun monthTotals(tx: Collection<Tx>, fromTs: Long, toTs: Long): Pair<Double, Double> {
        val inRange = tx.filter { !it.del && !it.pend && it.ts in fromTs until toTs && it.xf.isEmpty() }
        return inRange.filter { it.type == "inc" }.sumOf { it.base } to inRange.filter { it.type == "exp" }.sumOf { it.base }
    }

    /** ترحيل التحويلات القديمة (xfer) لمعاملتين مربوطتين، المعرّف `<id>_in` ثابت فلا يتكرر. */
    fun migrateLegacyTransfers(tx: Collection<Tx>, accName: (String) -> String, now: Long): List<Tx> {
        val out = ArrayList<Tx>()
        for (t in tx) {
            if (t.type != "xfer" || t.del || t.to.isEmpty() || t.to == t.acc) continue
            out += t.copy(type = "exp", to = "", xf = t.id, note = t.note.ifEmpty { "تحويل إلى ${accName(t.to)}" }, u = now)
            out += t.copy(id = "${t.id}_in", type = "inc", acc = t.to, to = "", xf = t.id, note = t.note.ifEmpty { "تحويل من ${accName(t.acc)}" }, u = now)
        }
        return out
    }
}
