package com.werd.cashu.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

/** مفاتيح مزامَنة لسه ما اتنقلتش لواجهة native (tyr_sub / tyr_assoc / tyr_inst / tyr_set / tyr_cat): بتتخزن خام وما بتتعدّلش، عشان تفضل سليمة على السيرفر. */
@Entity(tableName = "kv")
data class RawKv(@PrimaryKey val key: String, val value: String, val ts: Long)
