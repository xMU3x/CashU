package com.werd.cashu

import com.werd.cashu.data.sync.SyncConfig
import org.junit.Assert.*
import org.junit.Test

class SyncConfigTest {
    @Test fun rejectsEmptyAndSecretKeys() {
        assertFalse(SyncConfig.keyLooksValid(""))
        assertFalse(SyncConfig.keyLooksValid("sb_secret_abcdefghijklmnopqrstuvwxyz"))
    }

    @Test fun acceptsPublishableKey() {
        assertTrue(SyncConfig.keyLooksValid("sb_publishable_abcdefghijklmnopqrstuvwxyz"))
    }

    @Test fun rejectsServiceRoleJwt() {
        // payload {"role":"service_role"}
        val payload = "eyJyb2xlIjoic2VydmljZV9yb2xlIn0"
        assertFalse(SyncConfig.keyLooksValid("eyJhbGciOiJIUzI1NiJ9.$payload.sig"))
    }

    @Test fun acceptsAnonJwt() {
        // payload {"role":"anon"}
        val payload = "eyJyb2xlIjoiYW5vbiJ9"
        assertTrue(SyncConfig.keyLooksValid("eyJhbGciOiJIUzI1NiJ9.$payload.sig"))
    }
}
