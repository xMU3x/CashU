package com.werd.cashu.ui.screens

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.werd.cashu.CashUApp
import com.werd.cashu.data.Calc
import com.werd.cashu.data.model.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.Calendar

data class HomeState(
    val total: Double = 0.0, val receivables: Double = 0.0, val debts: Double = 0.0,
    val income: Double = 0.0, val expense: Double = 0.0,
    val balances: Map<String, Double> = emptyMap(),
)

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val db = (app as CashUApp).db
    val accounts = db.accounts().observeActive().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val txs = db.tx().observeActive().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val home: StateFlow<HomeState> = combine(db.accounts().observeActive(), db.tx().observeActive(), db.loans().observeActive()) { a, t, l ->
        val cal = Calendar.getInstance().apply { set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
        val from = cal.timeInMillis
        cal.add(Calendar.MONTH, 1)
        val (inc, exp) = Calc.monthTotals(t, from, cal.timeInMillis)
        HomeState(
            total = Calc.accountsTotal(a, t), receivables = Calc.receivables(l), debts = Calc.debts(l), income = inc, expense = exp,
            balances = a.associate { it.id to Calc.bal(it, it.id, t) },
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeState())

    fun addAccount(name: String, kind: String, start: Double) {
        val now = System.currentTimeMillis()
        viewModelScope.launch { db.accounts().upsert(Account(id = "acc_$now", name = name.trim(), kind = kind, start = start, u = now)) }
    }

    fun deleteAccount(a: Account) {
        viewModelScope.launch { db.accounts().upsert(a.copy(del = true, u = System.currentTimeMillis())) }
    }

    fun addTx(type: String, amount: Double, acc: String, to: String, note: String) {
        val now = System.currentTimeMillis()
        viewModelScope.launch {
            if (type == "xfer") {
                val names = db.accounts().all().associate { it.id to it.name }
                val id = "tx_$now"
                db.tx().upsertAll(listOf(
                    Tx(id = id, type = "exp", amt = amount, acc = acc, ts = now, xf = id, note = note.ifBlank { "تحويل إلى ${names[to] ?: ""}" }, u = now),
                    Tx(id = "${id}_in", type = "inc", amt = amount, acc = to, ts = now, xf = id, note = note.ifBlank { "تحويل من ${names[acc] ?: ""}" }, u = now),
                ))
            } else {
                db.tx().upsert(Tx(id = "tx_$now", type = type, amt = amount, acc = acc, note = note, ts = now, u = now))
            }
        }
    }

    /** حذف ناعم، وحذف أحد طرفي التحويل يحذف الاتنين (زي Dart). */
    fun deleteTx(t: Tx) {
        val now = System.currentTimeMillis()
        viewModelScope.launch {
            val all = db.tx().all()
            val victims = if (t.xf.isNotEmpty()) all.filter { it.xf == t.xf } else listOf(t)
            db.tx().upsertAll(victims.map { it.copy(del = true, u = now) })
        }
    }
}
