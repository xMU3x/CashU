package com.werd.cashu

import com.werd.cashu.data.*
import com.werd.cashu.data.model.CatDef
import org.junit.Assert.*
import org.junit.Test

class CatsTest {
    @Test fun defaultsWhenNoCustomCategories() {
        val b = CatBook(emptyList())
        assertEquals(kExpCats, b.mains(false))
        assertEquals(kIncCats, b.mains(true))
    }

    @Test fun seedMatchesDefaultsAndKeepsSubs() {
        val seeded = CatSeeder.seed()
        val b = CatBook(seeded)
        assertEquals(kExpCats.map { it.id }, b.mains(false).map { it.id })
        assertEquals(listOf("كهرباء", "مياه", "غاز", "رسوم النظافة"), b.mains(false).first { it.id == "bills" }.subs)
        assertEquals(seeded.size, seeded.map { it.id }.toSet().size)   // معرّفات فريدة
        assertTrue(seeded.all { it.u == 1L })
    }

    @Test fun renamedAndDeletedCategoriesStillResolveNames() {
        val seeded = CatSeeder.seed().map { if (it.id == "food") it.copy(name = "أكل", u = 5) else if (it.id == "fun") it.copy(del = true, u = 5) else it }
        val b = CatBook(seeded)
        assertEquals("أكل", b.nameOf("food"))
        assertEquals("ترفيه", b.nameOf("fun"))                       // محذوف لكن الاسم يفضل ظاهر للعمليات القديمة
        assertFalse(b.mains(false).any { it.id == "fun" })
    }

    @Test fun unknownIdFallsBackToOther() {
        assertEquals("أخرى", CatBook(emptyList()).nameOf("nope"))
    }

    @Test fun customCategoryIsOrdered() {
        val defs = listOf(
            CatDef(id = "b", kind = "exp", name = "ب", ord = 2),
            CatDef(id = "a", kind = "exp", name = "أ", ord = 1),
        )
        assertEquals(listOf("a", "b"), CatBook(defs).mains(false).map { it.id })
    }
}
