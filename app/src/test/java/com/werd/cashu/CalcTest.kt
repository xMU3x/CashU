package com.werd.cashu

import com.werd.cashu.data.Calc
import com.werd.cashu.data.FlutterImporter
import com.werd.cashu.data.model.*
import org.junit.Assert.*
import org.junit.Test

class CalcTest {
    private val a = Account(id = "a", name = "A", start = 100.0)
    private val b = Account(id = "b", name = "B", start = 0.0)

    @Test fun balanceFollowsDartRules() {
        val tx = listOf(
            Tx(id = "1", type = "inc", amt = 50.0, acc = "a", ts = 1),
            Tx(id = "2", type = "exp", amt = 30.0, acc = "a", ts = 2),
            Tx(id = "3", type = "exp", amt = 10.0, cur = "USD", rate = 2.0, acc = "a", ts = 3),   // base 20
            Tx(id = "4", type = "exp", amt = 999.0, acc = "a", ts = 4, del = true),
            Tx(id = "5", type = "exp", amt = 999.0, acc = "a", ts = 5, pend = true),
            Tx(id = "6", type = "adj", amt = 5.0, acc = "a", ts = 6, sign = -1),
        )
        assertEquals(100 + 50 - 30 - 20 - 5.0, Calc.bal(a, "a", tx), 1e-9)
    }

    @Test fun legacyTransferMigratesToTwoLinkedTxAndKeepsBalances() {
        val legacy = Tx(id = "x", type = "xfer", amt = 40.0, acc = "a", to = "b", ts = 1)
        val before = Calc.bal(a, "a", listOf(legacy)) to Calc.bal(b, "b", listOf(legacy))
        val m = Calc.migrateLegacyTransfers(listOf(legacy), { if (it == "a") "A" else "B" }, 99)
        assertEquals(2, m.size)
        assertEquals("x_in", m[1].id)
        assertTrue(m.all { it.xf == "x" })
        // المعاملة القديمة تُستبدل بنفس المعرّف (exp) فالرصيد ثابت
        val after = Calc.bal(a, "a", m) to Calc.bal(b, "b", m)
        assertEquals(before.first, after.first, 1e-9)
        assertEquals(before.second, after.second, 1e-9)
    }

    @Test fun balAtIgnoresLaterTx() {
        val tx = listOf(Tx(id = "1", type = "inc", amt = 10.0, acc = "a", ts = 10), Tx(id = "2", type = "inc", amt = 10.0, acc = "a", ts = 20))
        assertEquals(110.0, Calc.balAt(a, "a", tx, 15), 1e-9)
    }

    @Test fun monthTotalsExcludeTransferLegs() {
        val tx = listOf(
            Tx(id = "1", type = "inc", amt = 100.0, acc = "a", ts = 5),
            Tx(id = "2", type = "exp", amt = 40.0, acc = "a", ts = 6),
            Tx(id = "3", type = "exp", amt = 25.0, acc = "a", ts = 7, xf = "x"),
            Tx(id = "3_in", type = "inc", amt = 25.0, acc = "b", ts = 7, xf = "x"),
        )
        assertEquals(100.0 to 40.0, Calc.monthTotals(tx, 0, 100))
    }

    @Test fun loansTotals() {
        val loans = listOf(
            Loan(id = "1", dir = "owed", person = "p", amt = 100.0, ts = 1, paysJson = """[{"ts":1,"amt":40.0}]"""),
            Loan(id = "2", dir = "owe", person = "q", amt = 70.0, ts = 1),
            Loan(id = "3", dir = "owe", person = "r", amt = 70.0, ts = 1, settled = true),
        )
        assertEquals(60.0, Calc.receivables(loans), 1e-9)
        assertEquals(70.0, Calc.debts(loans), 1e-9)
    }

    @Test fun importerParsesFlutterMapAndIgnoresGarbage() {
        val raw = """{"t1":{"id":"t1","type":"exp","amt":5,"acc":"a","ts":1,"u":2},"bad":3}"""
        val recs = FlutterImporter.parseRecords(raw)
        assertEquals(1, recs.size)
        assertEquals("t1", Tx.fromJson(recs[0]).id)
        assertTrue(FlutterImporter.parseRecords(null).isEmpty())
        assertTrue(FlutterImporter.parseRecords("not json").isEmpty())
    }
}
