package com.werd.cashu.data

import com.werd.cashu.data.model.CatDef
import com.werd.cashu.data.model.isSub

/** نقل models.dart: التصنيفات الافتراضية + البحث بالاسم (الأولوية لتصنيف المستخدم المعدَّل، حتى المحذوف، عشان العمليات القديمة تفضل بتعرض اسمها). */
data class Cat(val id: String, val name: String, val subs: List<String> = emptyList())

val kExpCats = listOf(
    Cat("bills", "فواتير", listOf("كهرباء", "مياه", "غاز", "رسوم النظافة")),
    Cat("food", "طعام وشراب", listOf("مطاعم", "بقالة", "قهوة")),
    Cat("transport", "مواصلات", listOf("وقود", "أوبر", "صيانة")),
    Cat("shop", "تسوق", listOf("ملابس", "إلكترونيات")),
    Cat("health", "صحة", listOf("دواء", "كشف")),
    Cat("fun", "ترفيه"),
    Cat("edu", "تعليم"),
    Cat("home", "منزل", listOf("إيجار", "صيانة")),
    Cat("other", "أخرى"),
)

val kIncCats = listOf(
    Cat("salary", "راتب"),
    Cat("free", "عمل حر"),
    Cat("gift", "هدية"),
    Cat("invest", "استثمار"),
    Cat("other_i", "دخل"),
)

class CatBook(private val defs: List<CatDef>) {
    private val byId = defs.associateBy { it.id }
    private val custom = defs.isNotEmpty()

    private fun childNames(parent: String) =
        defs.filter { it.parent == parent && !it.del }.sortedBy { it.ord }.map { it.name }

    /** التصنيفات الرئيسية الظاهرة بالترتيب (الافتراضية لو المستخدم لسه ما عدّلش). */
    fun mains(inc: Boolean): List<Cat> {
        if (!custom) return if (inc) kIncCats else kExpCats
        val kind = if (inc) "inc" else "exp"
        return defs.filter { it.kind == kind && !it.isSub && !it.del }.sortedBy { it.ord }
            .map { Cat(it.id, it.name, childNames(it.id)) }
    }

    fun subsOf(catId: String): List<String> = mains(false).plus(mains(true)).firstOrNull { it.id == catId }?.subs ?: emptyList()

    fun nameOf(id: String): String {
        byId[id]?.takeIf { !it.isSub }?.let { return it.name }
        (kExpCats + kIncCats).firstOrNull { it.id == id }?.let { return it.name }
        return kExpCats.last().name
    }
}

/** نفس منطق seedCats في repo.dart (u=1 عشان أي تعديل لاحق/بعيد يفوز). معرّف الفرعي نسخة Kotlin (hashCode في Dart غير قابل للتطابق). */
object CatSeeder {
    private fun subId(parent: String, name: String) = "sub_${parent}_${(name.hashCode().toLong() and 0xFFFFFFFFL).toString(36)}"

    fun seed(): List<CatDef> {
        val out = ArrayList<CatDef>()
        var o = 0
        for ((inc, list) in listOf(false to kExpCats, true to kIncCats)) {
            val kind = if (inc) "inc" else "exp"
            for (c in list) {
                out += CatDef(id = c.id, kind = kind, name = c.name, ord = o++, u = 1)
                var so = 0
                for (n in c.subs.toSet()) out += CatDef(id = subId(c.id, n), kind = kind, name = n, parent = c.id, ord = so++, u = 1)
            }
        }
        return out
    }
}
