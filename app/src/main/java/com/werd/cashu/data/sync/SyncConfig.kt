package com.werd.cashu.data.sync

import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

@OptIn(ExperimentalEncodingApi::class)
object SyncConfig {
    const val TABLE = "cash_sync"
    const val NATIVE_REDIRECT = "com.werd.cashu://auth"
    const val STORE_PREFIX = "tyr:"
    val SYNC_KEYS = listOf("tyr_acc", "tyr_bud", "tyr_tx", "tyr_loan", "tyr_goal", "tyr_cat", "tyr_ctg", "tyr_set", "tyr_sub", "tyr_assoc", "tyr_inst")

    private val jwtShape = Regex("^eyJ[\\w-]+\\.[\\w-]+\\.[\\w-]+$")

    /** فحص شكلي: publishable أو anon JWT، ولا يقبل مفتاح service/secret أبدًا. */
    fun keyLooksValid(key: String): Boolean {
        val t = key.trim()
        if (t.isEmpty() || t.startsWith("sb_secret_")) return false
        if (t.startsWith("sb_publishable_") && t.length > 25) return true
        if (jwtShape.matches(t)) {
            return try {
                val payload = String(Base64.UrlSafe.withPadding(Base64.PaddingOption.ABSENT_OPTIONAL).decode(t.split('.')[1]))
                !payload.contains("service_role")
            } catch (e: Exception) { false }
        }
        return false
    }
}
