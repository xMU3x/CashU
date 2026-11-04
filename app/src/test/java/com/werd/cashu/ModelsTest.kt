package com.werd.cashu

import com.werd.cashu.data.model.*
import org.junit.Assert.*
import org.junit.Test

class ModelsTest {
    @Test fun txRoundTripKeepsAllFields() {
        val t = Tx(id = "t1", type = "exp", amt = 12.5, cur = "USD", rate = 50.0, acc = "a1", cat = "food", sub = "قهوة", ts = 1000, xf = "x1", pend = true, u = 9)
        assertEquals(t, Tx.fromJson(t.toJson()))
        assertEquals(625.0, t.base, 0.0001)
    }

    @Test fun accountRoundTrip() {
        val a = Account(id = "a1", name = "CIB", kind = "credit", limit = 5000.0, stmtDay = 25, u = 3)
        assertEquals(a, Account.fromJson(a.toJson()))
    }

    @Test fun loanPartialAndLeft() {
        val l = Loan(id = "l1", person = "أحمد", amt = 100.0, ts = 1, paysJson = """[{"ts":2,"amt":30.0}]""")
        assertEquals(70.0, l.left, 0.0001)
        assertEquals(30.0, l.paid, 0.0001)
        assertTrue(l.partial)
        val back = Loan.fromJson(l.toJson())
        assertEquals(70.0, back.left, 0.0001)
    }

    @Test fun settledLoanHasNothingLeft() {
        val l = Loan(id = "l2", person = "س", amt = 50.0, ts = 1, settled = true)
        assertEquals(0.0, l.left, 0.0)
        assertEquals(50.0, l.paid, 0.0)
    }
}
