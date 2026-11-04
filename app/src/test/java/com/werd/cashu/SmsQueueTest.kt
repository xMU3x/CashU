package com.werd.cashu

import com.werd.cashu.sms.SmsQueue
import org.junit.Assert.*
import org.junit.Test

class SmsQueueTest {
    @Test fun dropsOtpMessages() {
        assertFalse(SmsQueue.shouldKeep("Your OTP is 123456"))
        assertFalse(SmsQueue.shouldKeep("رمز التحقق هو ٤٥٦٧٨٩"))
    }

    @Test fun keepsTransactionMessagesEvenWithOtpWarning() {
        assertTrue(SmsQueue.shouldKeep("تم خصم مبلغ 250 جنيه من بطاقتك. لا تشارك OTP مع أحد"))
    }

    @Test fun dropsMessagesWithoutDigits() {
        assertFalse(SmsQueue.shouldKeep("مرحبا بك"))
    }
}
