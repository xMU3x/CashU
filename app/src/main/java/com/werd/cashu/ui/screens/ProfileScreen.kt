package com.werd.cashu.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.werd.cashu.data.sync.SyncStatus

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(vm: MainViewModel) {
    val ui by vm.syncUi.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    var email by rememberSaveable { mutableStateOf("") }
    var pw by rememberSaveable { mutableStateOf("") }
    var create by rememberSaveable { mutableStateOf(false) }
    var msg by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    Scaffold(topBar = { CenterAlignedTopAppBar(title = { Text("حسابي") }) }) { pad ->
        Column(
            Modifier.padding(pad).padding(16.dp).fillMaxWidth().verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (!ui.ready) {
                Card(Modifier.fillMaxWidth()) {
                    Text("المزامنة غير مفعّلة في هذا البناء (لم يُضبط SUPABASE_ANON_KEY). التطبيق يعمل محليًا بالكامل.", Modifier.padding(16.dp))
                }
            }
            if (ui.signedIn) {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(ui.email.ifBlank { "مسجَّل الدخول" }, style = MaterialTheme.typography.titleMedium)
                        Text(statusText(ui.status), style = MaterialTheme.typography.bodyMedium)
                        if (ui.last > 0) Text("آخر مزامنة: ${dateStr(ui.last)}", style = MaterialTheme.typography.bodySmall)
                        if (ui.error.isNotBlank()) Text(ui.error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    }
                }
                Button(onClick = { vm.syncNow() }, enabled = ui.status != SyncStatus.SYNCING, modifier = Modifier.fillMaxWidth()) { Text("مزامنة الآن") }
                OutlinedButton(onClick = { vm.logout() }, modifier = Modifier.fillMaxWidth()) { Text("تسجيل الخروج") }
                TextButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text("حذف الحساب نهائيًا", color = MaterialTheme.colorScheme.error)
                }
            } else {
                Text(if (create) "إنشاء حساب" else "تسجيل الدخول", style = MaterialTheme.typography.titleLarge)
                OutlinedTextField(
                    email, { email = it }, label = { Text("البريد الإلكتروني") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    pw, { pw = it }, label = { Text("كلمة المرور") }, singleLine = true, visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = {
                        busy = true; msg = ""
                        vm.signIn(email, pw, create) { r ->
                            busy = false
                            msg = when {
                                r.error != null -> r.error
                                r.needsConfirm -> "تم إنشاء الحساب — أكّد بريدك الإلكتروني ثم سجّل الدخول."
                                else -> ""
                            }
                        }
                    },
                    enabled = ui.ready && !busy && email.isNotBlank() && pw.length >= 6, modifier = Modifier.fillMaxWidth(),
                ) { Text(if (create) "إنشاء الحساب" else "دخول") }
                OutlinedButton(
                    onClick = { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(vm.googleUrl()))) } },
                    enabled = ui.ready, modifier = Modifier.fillMaxWidth(),
                ) { Text("الدخول بحساب جوجل") }
                TextButton(onClick = { create = !create; msg = "" }, modifier = Modifier.fillMaxWidth()) {
                    Text(if (create) "عندي حساب بالفعل" else "إنشاء حساب جديد")
                }
                if (msg.isNotBlank()) Text(msg, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
                if (ui.error.isNotBlank()) Text(ui.error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("حذف الحساب نهائيًا؟") },
            text = { Text("سيُحذف حسابك وكل بياناتك من السيرفر ومن هذا الجهاز، ولا يمكن التراجع.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    vm.deleteCloudAccount { ok -> msg = if (ok) "تم حذف الحساب." else "تعذّر حذف الحساب. حاول مرة أخرى." }
                }) { Text("حذف", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("إلغاء") } },
        )
    }
}

private fun statusText(s: SyncStatus): String = when (s) {
    SyncStatus.OFF -> "غير متصل"
    SyncStatus.SYNCING -> "جارٍ المزامنة…"
    SyncStatus.OK -> "تمت المزامنة"
    SyncStatus.OFFLINE -> "لا يوجد إنترنت — ستُعاد المحاولة تلقائيًا"
    SyncStatus.ERROR -> "تعذّرت المزامنة"
}
