package com.werd.cashu.ui.screens

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun money(v: Double): String = String.format(Locale.US, "%,.2f", v)
fun dateStr(ts: Long): String = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.US).format(Date(ts))

val accountKinds = listOf("bank" to "حساب بنكي", "cash" to "نقدي", "wallet" to "محفظة", "credit" to "بطاقة ائتمان", "debit" to "بطاقة خصم")
