package com.werd.cashu

import com.werd.cashu.data.Merge
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class MergeTest {
    private fun obj(s: String) = Json.parseToJsonElement(s)

    @Test fun newerRecordWins() {
        val a = obj("""{"t1":{"id":"t1","amt":10,"u":100}}""")
        val b = obj("""{"t1":{"id":"t1","amt":20,"u":200},"t2":{"id":"t2","amt":5,"u":50}}""")
        val m = Merge.flow(a, b)!!.jsonObject
        assertEquals(20.0, m["t1"]!!.jsonObject["amt"]!!.jsonPrimitive.double, 0.0)
        assertTrue(m.containsKey("t2"))
    }

    @Test fun olderRemoteDoesNotOverwrite() {
        val a = obj("""{"t1":{"id":"t1","amt":10,"u":300}}""")
        val b = obj("""{"t1":{"id":"t1","amt":99,"u":200}}""")
        assertEquals(10.0, Merge.flow(a, b)!!.jsonObject["t1"]!!.jsonObject["amt"]!!.jsonPrimitive.double, 0.0)
    }

    @Test fun softDeleteWinsWhenNewer() {
        val a = obj("""{"t1":{"id":"t1","del":false,"u":100}}""")
        val b = obj("""{"t1":{"id":"t1","del":true,"u":101}}""")
        assertTrue(Merge.flow(a, b)!!.jsonObject["t1"]!!.jsonObject["del"]!!.jsonPrimitive.boolean)
    }

    @Test fun arraysAreUnionedWithoutDuplicates() {
        val m = Merge.values(obj("[1,2]"), obj("[2,3]"))!!.jsonArray
        assertEquals(3, m.size)
    }

    @Test fun numbersTakeMax() {
        assertEquals(7.0, Merge.values(obj("3"), obj("7"))!!.jsonPrimitive.double, 0.0)
    }
}
