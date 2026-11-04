package com.werd.cashu

import android.app.Application
import com.werd.cashu.data.FlutterImporter
import com.werd.cashu.data.db.AppDb
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class CashUApp : Application() {
    val db: AppDb by lazy { AppDb.get(this) }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        // ترحيل بيانات Flutter مرة واحدة (آمن: لا يحذف ولا يكتب فوق الأحدث).
        scope.launch { runCatching { FlutterImporter.runOnce(this@CashUApp, db) } }
    }
}
