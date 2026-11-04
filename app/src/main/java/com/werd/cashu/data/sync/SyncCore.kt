package com.werd.cashu.data.sync

import com.werd.cashu.data.Merge
import kotlinx.serialization.json.*

/** منطق المزامنة الصافي (بدون شبكة) علشان يتجرّب بـ JUnit. */
object SyncCore {
    class Out(val merged: JsonObject, val push: Boolean)

    /** 5 و 5.0 نفس القيمة — نوحّد الأرقام قبل المقارنة عشان ما نرفعش من غير داعي. */
    fun norm(e: JsonElement): JsonElement = when (e) {
        is JsonObject -> JsonObject(e.mapValues { norm(it.value) })
        is JsonArray -> JsonArray(e.map { norm(it) })
        is JsonPrimitive -> if (!e.isString && e.doubleOrNull != null) JsonPrimitive(e.double) else e
    }

    /** دمج على مستوى السجل (الأحدث u يفوز) — لا حذف فعلي أبدًا؛ الرفع فقط لو الناتج مختلف عن السيرفر. */
    fun mergeRecords(local: JsonObject, remote: JsonObject?): Out {
        if (remote == null) return Out(local, local.isNotEmpty())
        val merged = Merge.flow(local, remote) as? JsonObject ?: local
        return Out(merged, merged.isNotEmpty() && norm(merged) != norm(remote))
    }
}
