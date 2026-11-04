package com.werd.cashu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.werd.cashu.data.CatBook
import com.werd.cashu.data.model.base
import com.werd.cashu.ui.motion.Motion

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionsScreen(vm: MainViewModel) {
    val txs by vm.txs.collectAsStateWithLifecycle()
    val accounts by vm.accounts.collectAsStateWithLifecycle()
    val book by vm.cats.collectAsStateWithLifecycle()
    val names = remember(accounts) { accounts.associate { it.id to it.name } }
    var query by remember { mutableStateOf("") }
    var showAdd by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    val shown = remember(txs, query, names, book) {
        if (query.isBlank()) txs else txs.filter { it.note.contains(query, true) || (names[it.acc] ?: "").contains(query, true) || (it.cat.isNotEmpty() && book.nameOf(it.cat).contains(query, true)) || it.sub.contains(query, true) }
    }

    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("المعاملات") }) },
        floatingActionButton = {
            if (accounts.isNotEmpty()) FloatingActionButton(onClick = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); showAdd = true }) {
                Icon(Icons.Default.Add, contentDescription = "معاملة جديدة")
            }
        },
    ) { pad ->
        Column(Modifier.padding(pad)) {
            OutlinedTextField(query, { query = it }, label = { Text("بحث") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
            if (accounts.isEmpty()) {
                Text("أضف حسابًا أولًا من تبويب الحسابات.", Modifier.padding(24.dp))
            } else if (shown.isEmpty()) {
                Text("لا توجد معاملات.", Modifier.padding(24.dp))
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(shown, key = { it.id }) { t ->
                        Card(Modifier.fillMaxWidth().alpha(if (t.pend) 0.6f else 1f).animateItem(fadeInSpec = Motion.tween(Motion.SMALL), fadeOutSpec = Motion.tween(Motion.SMALL))) {
                            Row(Modifier.padding(horizontal = 8.dp, vertical = 12.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                IconButton(onClick = { haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove); vm.togglePend(t) }) {
                                    Icon(if (t.pend) Icons.Default.Schedule else Icons.Default.CheckCircle, contentDescription = if (t.pend) "معلّقة" else "مؤكدة")
                                }
                                Column(Modifier.weight(1f)) {
                                    Text(t.note.ifBlank { if (t.type == "inc") "دخل" else "مصروف" }, style = MaterialTheme.typography.titleSmall)
                                    val catLine = if (t.cat.isEmpty()) "" else book.nameOf(t.cat) + (if (t.sub.isNotEmpty()) " › ${t.sub}" else "") + " · "
                                    Text("$catLine${names[t.acc] ?: "—"} · ${dateStr(t.ts)}", style = MaterialTheme.typography.bodySmall)
                                }
                                val sign = if (t.type == "inc") "+" else "−"
                                Text("$sign${money(t.base)}", style = MaterialTheme.typography.titleMedium,
                                    color = if (t.type == "inc") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
                                IconButton(onClick = { vm.deleteTx(t) }) { Icon(Icons.Default.Delete, contentDescription = "حذف") }
                            }
                        }
                    }
                }
            }
        }
    }
    if (showAdd) AddTxSheet(accounts.map { it.id to it.name }, book, { showAdd = false }) { type, amt, acc, to, note, cat, sub -> vm.addTx(type, amt, acc, to, note, cat, sub); showAdd = false }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun AddTxSheet(accs: List<Pair<String, String>>, book: CatBook, onDismiss: () -> Unit, onSave: (String, Double, String, String, String, String, String) -> Unit) {
    var type by remember { mutableStateOf("exp") }
    var amount by remember { mutableStateOf("") }
    var acc by remember { mutableStateOf(accs.first().first) }
    var to by remember { mutableStateOf(accs.getOrNull(1)?.first ?: "") }
    var note by remember { mutableStateOf("") }
    var cat by remember { mutableStateOf("") }
    var sub by remember { mutableStateOf("") }
    val amt = amount.replace(',', '.').toDoubleOrNull() ?: 0.0
    val canSave = amt > 0 && (type != "xfer" || (to.isNotEmpty() && to != acc))
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("معاملة جديدة", style = MaterialTheme.typography.titleLarge)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("exp" to "مصروف", "inc" to "دخل", "xfer" to "تحويل").forEach { (k, l) -> FilterChip(type == k, { type = k; cat = ""; sub = "" }, { Text(l) }) }
            }
            OutlinedTextField(amount, { amount = it }, label = { Text("المبلغ") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
            Text(if (type == "xfer") "من" else "الحساب", style = MaterialTheme.typography.labelLarge)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { accs.forEach { (id, n) -> FilterChip(acc == id, { acc = id }, { Text(n) }) } }
            if (type == "xfer") {
                Text("إلى", style = MaterialTheme.typography.labelLarge)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { accs.filter { it.first != acc }.forEach { (id, n) -> FilterChip(to == id, { to = id }, { Text(n) }) } }
            }
            if (type != "xfer") {
                Text("التصنيف", style = MaterialTheme.typography.labelLarge)
                val mains = book.mains(type == "inc")
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    mains.forEach { c -> FilterChip(cat == c.id, { if (cat == c.id) { cat = ""; sub = "" } else { cat = c.id; sub = "" } }, { Text(c.name) }) }
                }
                val subs = mains.firstOrNull { it.id == cat }?.subs ?: emptyList()
                if (subs.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        subs.forEach { n -> FilterChip(sub == n, { sub = if (sub == n) "" else n }, { Text(n) }) }
                    }
                }
            }
            OutlinedTextField(note, { note = it }, label = { Text("ملاحظة") }, modifier = Modifier.fillMaxWidth())
            Button(onClick = { onSave(type, amt, acc, to, note, cat, sub) }, enabled = canSave, modifier = Modifier.fillMaxWidth()) { Text("حفظ") }
        }
    }
}
