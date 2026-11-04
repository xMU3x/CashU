package com.werd.cashu.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: MainViewModel) {
    val h by vm.home.collectAsStateWithLifecycle()
    Scaffold(topBar = { CenterAlignedTopAppBar(title = { Text("الرئيسية") }) }) { pad ->
        LazyColumn(Modifier.padding(pad), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                ElevatedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(20.dp)) {
                        Text("مجموع الحسابات", style = MaterialTheme.typography.labelLarge)
                        Text(money(h.total), style = MaterialTheme.typography.headlineLarge)
                        if (h.receivables != 0.0) Text("لك عند الناس: ${money(h.receivables)}", style = MaterialTheme.typography.bodyMedium)
                        if (h.debts != 0.0) Text("عليك ديون: ${money(h.debts)}", style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Card(Modifier.weight(1f)) { Column(Modifier.padding(16.dp)) { Text("دخل الشهر"); Text(money(h.income), style = MaterialTheme.typography.titleLarge) } }
                    Card(Modifier.weight(1f)) { Column(Modifier.padding(16.dp)) { Text("مصروف الشهر"); Text(money(h.expense), style = MaterialTheme.typography.titleLarge) } }
                }
            }
        }
    }
}
