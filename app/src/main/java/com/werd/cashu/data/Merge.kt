package com.werd.cashu.data

import kotlinx.serialization.json.*

/** نسخة Kotlin مطابقة لـ merge.dart: دمج على مستوى السجل — لكل id يفوز الأحدث (`u`). */
object Merge {
    fun values(a: JsonElement?, b: JsonElement?): JsonElement? {
        if (a == null || a is JsonNull) return b
        if (b == null || b is JsonNull) return a
        if (a is JsonPrimitive && b is JsonPrimitive && !a.isString && !b.isString && a.doubleOrNull != null && b.doubleOrNull != null) {
            return if (a.double > b.double) a else b
        }
        if (a is JsonArray && b is JsonArray) {
            val seen = HashSet<String>()
            return JsonArray((a + b).filter { seen.add(it.toString()) })
        }
        if (a is JsonObject && b is JsonObject) {
            val o = LinkedHashMap<String, JsonElement>(a)
            for ((k, v) in b) o[k] = if (o.containsKey(k)) values(o[k], v) ?: v else v
            return JsonObject(o)
        }
        return a
    }

    private fun isRecords(m: JsonObject) = m.values.all { it is JsonObject && it.containsKey("u") }
    private fun u(e: JsonElement?) = ((e as? JsonObject)?.get("u") as? JsonPrimitive)?.doubleOrNull ?: 0.0

    fun flow(a: JsonElement?, b: JsonElement?): JsonElement? {
        if (a is JsonObject && b is JsonObject && isRecords(a) && isRecords(b)) {
            val o = LinkedHashMap<String, JsonElement>(a)
            for ((id, v) in b) {
                val cur = o[id]
                if (cur == null) o[id] = v else if (u(v) > u(cur)) o[id] = v
            }
            return JsonObject(o)
        }
        return values(a, b)
    }
}
