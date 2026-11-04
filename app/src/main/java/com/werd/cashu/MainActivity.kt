package com.werd.cashu

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
        setContent { CashUTheme { AppNav() } }
    }
}
