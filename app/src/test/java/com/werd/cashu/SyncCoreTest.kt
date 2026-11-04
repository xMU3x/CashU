package com.werd.cashu

import com.werd.cashu.data.sync.SyncCore
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class SyncCoreTest {
    private fun obj(s: String) = Json.parseToJsonElement(s).jsonObject

    @Test fun noRemoteAndLocalHasData_pushes() {
        val out = SyncCore.mergeRecords(obj("""{"a":{"id":"a","u":1}}"""), null)
        assertTrue(out.push)
    }

    @Test fun noRemoteAndEmptyLocal_doesNotPush() {
        assertFalse(SyncCore.mergeRecords(obj("{}"), null).push)
    }

    @Test fun remoteOnly_isPulledAndNotPushed() {
        val remote = obj("""{"a":{"id":"a","amt":5,"u":9}}""")
        val out = SyncCore.mergeRecords(obj("{}"), remote)
        assertEquals(remote, out.merged)
        assertFalse(out.push)
    }

    @Test fun numberFormattingDifferenceAloneDoesNotPush() {
        val local = obj("""{"a":{"id":"a","amt":5.0,"u":9}}""")
        val remote = obj("""{"a":{"id":"a","amt":5,"u":9}}""")
        assertFalse(SyncCore.mergeRecords(local, remote).push)
    }

    @Test fun newerLocalWinsAndPushes() {
        val local = obj("""{"a":{"id":"a","amt":7,"u":20}}""")
        val remote = obj("""{"a":{"id":"a","amt":5,"u":10}}""")
        val out = SyncCore.mergeRecords(local, remote)
        assertTrue(out.push)
        assertEquals(7.0, out.merged["a"]!!.jsonObject["amt"]!!.jsonPrimitive.double, 0.0)
    }

    @Test fun newerRemoteWinsWithoutPush() {
        val local = obj("""{"a":{"id":"a","amt":7,"u":10}}""")
        val remote = obj("""{"a":{"id":"a","amt":5,"u":20}}""")
        val out = SyncCore.mergeRecords(local, remote)
        assertFalse(out.push)
        assertEquals(5.0, out.merged["a"]!!.jsonObject["amt"]!!.jsonPrimitive.double, 0.0)
    }

    @Test fun disjointRecordsAreUnionedAndPushed() {
        val out = SyncCore.mergeRecords(obj("""{"a":{"id":"a","u":1}}"""), obj("""{"b":{"id":"b","u":2}}"""))
        assertEquals(2, out.merged.size)
        assertTrue(out.push)
    }

    @Test fun softDeletePropagates() {
        val local = obj("""{"a":{"id":"a","del":true,"u":30}}""")
        val remote = obj("""{"a":{"id":"a","del":false,"u":10}}""")
        val out = SyncCore.mergeRecords(local, remote)
        assertTrue(out.merged["a"]!!.jsonObject["del"]!!.jsonPrimitive.boolean)
        assertTrue(out.push)
    }
}
