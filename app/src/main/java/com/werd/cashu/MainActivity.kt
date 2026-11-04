package com.werd.cashu

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.werd.cashu.ui.nav.AppNav
import com.werd.cashu.ui.theme.CashUTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleLink(intent)
        setContent { CashUTheme { AppNav() } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLink(intent)
    }

    override fun onResume() {
        super.onResume()
        (application as CashUApp).sync.onResume()
    }

    /** رابط العودة بعد تسجيل الدخول بجوجل / تأكيد البريد: com.werd.cashu://auth */
    private fun handleLink(i: Intent?) {
        val d = i?.data ?: return
        if (d.scheme == "com.werd.cashu" && d.host == "auth") (application as CashUApp).sync.handleRedirect(d)
    }
}
