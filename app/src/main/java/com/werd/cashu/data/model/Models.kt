package com.werd.cashu.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import kotlinx.serialization.json.*

/** نفس حقول وأسماء JSON في تطبيق Dart (models.dart) كي تبقى المزامنة مع Supabase متوافقة 100%. */

private fun JsonObject.s(k: String, d: String = "") = (this[k] as? JsonPrimitive)?.takeIf { it.isString }?.content ?: d
private fun JsonObject.n(k: String) = (this[k] as? JsonPrimitive)?.takeIf { !it.isString }
private fun JsonObject.d(k: String, d: Double = 0.0) = n(k)?.doubleOrNull ?: d
private fun JsonObject.i(k: String, d: Int = 0) = n(k)?.doubleOrNull?.toInt() ?: d
private fun JsonObject.l(k: String, d: Long = 0) = n(k)?.doubleOrNull?.toLong() ?: d
private fun JsonObject.b(k: String, d: Boolean = false) = (this[k] as? JsonPrimitive)?.booleanOrNull ?: d

@Entity(tableName = "accounts")
data class Account(
    @PrimaryKey val id: String,
    val name: String,
    val kind: String = "bank",
    val last4: String = "",
    val bud: String = "bud_main",
    val grp: String = "",
    val info: String = "",
    val icon: String = "",
    val sms: String = "",
    val showAvail: Boolean = false,
    val stmtDay: Int = 31,
    val wkend: String = "none",
    val start: Double = 0.0,
    val limit: Double = 0.0,
    val showBud: Boolean = true,
    val del: Boolean = false,
    val nw: Boolean = true,
    val gb: Boolean = true,
    val ac: Boolean = true,
    val arch: Boolean = false,
    val u: Long = 0,
) {
    fun toJson() = buildJsonObject {
        put("id", id); put("name", name); put("kind", kind); put("last4", last4); put("bud", bud); put("grp", grp)
        put("info", info); put("icon", icon); put("sms", sms); put("showAvail", showAvail); put("stmtDay", stmtDay)
        put("wkend", wkend); put("start", start); put("limit", limit); put("showBud", showBud); put("del", del)
        put("nw", nw); put("gb", gb); put("ac", ac); put("arch", arch); put("u", u)
    }

    companion object {
        fun fromJson(j: JsonObject) = Account(
            id = j.s("id"), name = j.s("name"), kind = j.s("kind", "bank"), last4 = j.s("last4"), bud = j.s("bud", "bud_main"),
            grp = j.s("grp"), info = j.s("info"), icon = j.s("icon"), sms = j.s("sms"), showAvail = j.b("showAvail"),
            stmtDay = j.i("stmtDay", 31), wkend = j.s("wkend", "none"), start = j.d("start"), limit = j.d("limit"),
            showBud = j.b("showBud", true), del = j.b("del"), nw = j.b("nw", true), gb = j.b("gb", true), ac = j.b("ac", true),
            arch = j.b("arch"), u = j.l("u"),
        )
    }
}

/** type: exp | inc | xfer | loan | adj */
@Entity(tableName = "tx")
data class Tx(
    @PrimaryKey val id: String,
    val type: String = "exp",
    val amt: Double,
    val cur: String = "EGP",
    val rate: Double = 1.0,
    val acc: String,
    val to: String = "",
    val cat: String = "",
    val sub: String = "",
    val note: String = "",
    val ts: Long,
    val rep: String = "none",
    val nx: Long = 0,
    val src: String = "",
    val loan: String = "",
    val sign: Int = 0,
    val pay: String = "",
    val split: String = "",
    val tags: String = "",
    val link: String = "",
    val xf: String = "",
    val pend: Boolean = false,
    val del: Boolean = false,
    val u: Long = 0,
) {
    val base: Double get() = amt * rate

    fun toJson() = buildJsonObject {
        put("id", id); put("type", type); put("amt", amt); put("cur", cur); put("rate", rate); put("acc", acc); put("to", to)
        put("cat", cat); put("sub", sub); put("note", note); put("ts", ts); put("rep", rep); put("nx", nx); put("src", src)
        put("loan", loan); put("sign", sign); put("pay", pay); put("split", split); put("tags", tags); put("link", link)
        put("xf", xf); put("pend", pend); put("del", del); put("u", u)
    }

    companion object {
        fun fromJson(j: JsonObject) = Tx(
            id = j.s("id"), type = j.s("type", "exp"), amt = j.d("amt"), cur = j.s("cur", "EGP"), rate = j.d("rate", 1.0),
            acc = j.s("acc"), to = j.s("to"), cat = j.s("cat"), sub = j.s("sub"), note = j.s("note"), ts = j.l("ts"),
            rep = j.s("rep", "none"), nx = j.l("nx"), src = j.s("src"), loan = j.s("loan"), sign = j.i("sign"), pay = j.s("pay"),
            split = j.s("split"), tags = j.s("tags"), link = j.s("link"), xf = j.s("xf"), pend = j.b("pend"), del = j.b("del"), u = j.l("u"),
        )
    }
}

@Entity(tableName = "budgets")
data class Budget(
    @PrimaryKey val id: String,
    val name: String = "الميزانية الرئيسية",
    val limit: Double = 0.0,
    val del: Boolean = false,
    val u: Long = 0,
) {
    fun toJson() = buildJsonObject { put("id", id); put("name", name); put("limit", limit); put("del", del); put("u", u) }
    companion object {
        fun fromJson(j: JsonObject) = Budget(j.s("id"), j.s("name", "الميزانية الرئيسية"), j.d("limit"), j.b("del"), j.l("u"))
    }
}

@Entity(tableName = "goals")
data class Goal(
    @PrimaryKey val id: String,
    val name: String,
    val emoji: String = "",
    val target: Double = 0.0,
    val saved: Double = 0.0,
    val del: Boolean = false,
    val u: Long = 0,
) {
    fun toJson() = buildJsonObject {
        put("id", id); put("name", name); put("emoji", emoji); put("target", target); put("saved", saved); put("del", del); put("u", u)
    }
    companion object {
        fun fromJson(j: JsonObject) = Goal(j.s("id"), j.s("name"), j.s("emoji"), j.d("target"), j.d("saved"), j.b("del"), j.l("u"))
    }
}

/** تصنيف قابل للتعديل: رئيسي لو parent فاضي، فرعي لو parent = id الرئيسي. */
@Entity(tableName = "categories")
data class CatDef(
    @PrimaryKey val id: String,
    val kind: String = "exp",
    val name: String,
    val parent: String = "",
    val icon: String = "",
    val color: Long = 0,
    val ord: Int = 0,
    val del: Boolean = false,
    val u: Long = 0,
) {
    val isSub: Boolean get() = parent.isNotEmpty()
    fun toJson() = buildJsonObject {
        put("id", id); put("kind", kind); put("name", name); put("parent", parent); put("icon", icon)
        put("color", color); put("ord", ord); put("del", del); put("u", u)
    }
    companion object {
        fun fromJson(j: JsonObject) = CatDef(j.s("id"), j.s("kind", "exp"), j.s("name"), j.s("parent"), j.s("icon"), j.l("color"), j.i("ord"), j.b("del"), j.l("u"))
    }
}

data class LoanPay(val ts: Long, val amt: Double, val tx: String = "")

/** dir: owe (عليّا) | owed (ليّا). الدفعات تُخزَّن JSON داخل عمود واحد كي يبقى شكل المزامنة كما هو. */
@Entity(tableName = "loans")
data class Loan(
    @PrimaryKey val id: String,
    val dir: String = "owe",
    val person: String,
    val amt: Double,
    val cur: String = "EGP",
    val rate: Double = 1.0,
    val acc: String = "",
    val due: Long = 0,
    val note: String = "",
    val ts: Long,
    val settled: Boolean = false,
    val del: Boolean = false,
    val hidden: Boolean = false,
    val nw: Boolean = true,
    val rec: Boolean = true,
    val remJson: String = "[]",
    val paysJson: String = "[]",
    val u: Long = 0,
) {
    val pays: List<LoanPay> get() = (runCatching { Json.parseToJsonElement(paysJson).jsonArray }.getOrNull() ?: JsonArray(emptyList()))
        .mapNotNull { (it as? JsonObject)?.let { o -> LoanPay(o.l("ts"), o.d("amt"), o.s("tx")) } }
    val base: Double get() = amt * rate
    val left: Double get() = if (settled) 0.0 else (amt - pays.sumOf { it.amt }).coerceAtLeast(0.0)
    val paid: Double get() = if (settled) amt else pays.sumOf { it.amt }.coerceIn(0.0, amt)
    val leftBase: Double get() = left * rate
    val partial: Boolean get() = !settled && pays.isNotEmpty() && left > 0.004

    fun toJson() = buildJsonObject {
        put("id", id); put("dir", dir); put("person", person); put("amt", amt); put("cur", cur); put("rate", rate); put("acc", acc)
        put("due", due); put("note", note); put("ts", ts); put("settled", settled); put("del", del); put("hidden", hidden)
        put("u", u); put("nw", nw); put("rec", rec)
        put("rem", runCatching { Json.parseToJsonElement(remJson) }.getOrDefault(JsonArray(emptyList())))
        put("pays", runCatching { Json.parseToJsonElement(paysJson) }.getOrDefault(JsonArray(emptyList())))
    }

    companion object {
        fun fromJson(j: JsonObject) = Loan(
            id = j.s("id"), dir = j.s("dir", "owe"), person = j.s("person"), amt = j.d("amt"), cur = j.s("cur", "EGP"), rate = j.d("rate", 1.0),
            acc = j.s("acc"), due = j.l("due"), note = j.s("note"), ts = j.l("ts"), settled = j.b("settled"), del = j.b("del"),
            hidden = j.b("hidden"), nw = j.b("nw", true), rec = j.b("rec", true),
            remJson = (j["rem"] as? JsonArray)?.toString() ?: "[]", paysJson = (j["pays"] as? JsonArray)?.toString() ?: "[]", u = j.l("u"),
        )
    }
}
