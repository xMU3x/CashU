package com.werd.cashu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.werd.cashu.ui.motion.Motion

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountsScreen(vm: MainViewModel) {
    val accounts by vm.accounts.collectAsStateWithLifecycle()
    val home by vm.home.collectAsStateWithLifecycle()
    var showAdd by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current

    Scaffold(
        topBar = { CenterAlignedTopAppBar(title = { Text("الحسابات") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = { haptic.performHapticFeedback(HapticFeedbackType.LongPress); showAdd = true }) {
                Icon(Icons.Default.Add, contentDescription = "إضافة حساب")
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize()) {
            if (accounts.isEmpty()) {
                Text("لا توجد حسابات بعد. اضغط + لإضافة أول حساب.", Modifier.align(Alignment.Center).padding(24.dp))
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(accounts, key = { it.id }) { a ->
                        Card(Modifier.fillMaxWidth().animateItem(fadeInSpec = Motion.tween(Motion.SMALL), fadeOutSpec = Motion.tween(Motion.SMALL))) {
                            Row(Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(a.name, style = MaterialTheme.typography.titleMedium)
                                    Text(accountKinds.firstOrNull { it.first == a.kind }?.second ?: a.kind, style = MaterialTheme.typography.bodySmall)
                                }
                                Text(money(home.balances[a.id] ?: a.start), style = MaterialTheme.typography.titleMedium)
                                IconButton(onClick = { vm.deleteAccount(a) }) { Icon(Icons.Default.Delete, contentDescription = "حذف") }
                            }
                        }
                    }
                }
            }
        }
    }
    if (showAdd) AddAccountSheet(onDismiss = { showAdd = false }, onSave = { n, k, s -> vm.addAccount(n, k, s); showAdd = false })
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun AddAccountSheet(onDismiss: () -> Unit, onSave: (String, String, Double) -> Unit) {
    var name by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf("bank") }
    var start by remember { mutableStateOf("") }
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("حساب جديد", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(name, { name = it }, label = { Text("اسم الحساب") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(
                start, { start = it }, label = { Text("الرصيد الافتتاحي") }, singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth(),
            )
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                accountKinds.forEach { (k, label) -> FilterChip(selected = kind == k, onClick = { kind = k }, label = { Text(label) }) }
            }
            Button(onClick = { onSave(name, kind, start.replace(',', '.').toDoubleOrNull() ?: 0.0) }, enabled = name.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Text("حفظ") }
        }
    }
}
