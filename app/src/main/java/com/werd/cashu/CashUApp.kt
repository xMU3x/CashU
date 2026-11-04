package com.werd.cashu

import android.app.Application
import com.werd.cashu.data.FlutterImporter
import com.werd.cashu.data.db.AppDb
import com.werd.cashu.data.sync.SyncService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class CashUApp : Application() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    val db: AppDb by lazy { AppDb.get(this) }
    val sync: SyncService by lazy { SyncService(this, db, scope) }

    override fun onCreate() {
        super.onCreate()
        scope.launch {
            // 1) ترحيل بيانات Flutter مرة واحدة (آمن: لا يحذف ولا يكتب فوق الأحدث) 2) تشغيل المزامنة.
            runCatching { FlutterImporter.runOnce(this@CashUApp, db) }
            runCatching { sync.start() }
        }
    }
}
