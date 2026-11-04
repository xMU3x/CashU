package com.werd.cashu.ui.nav

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.werd.cashu.ui.motion.Motion
import com.werd.cashu.ui.screens.*

private enum class Tab(val route: String, val label: String, val icon: ImageVector) {
    Home("home", "الرئيسية", Icons.Default.Home),
    Tx("tx", "المعاملات", Icons.Default.SwapHoriz),
    Accounts("accounts", "الحسابات", Icons.Default.AccountBalanceWallet),
    Profile("profile", "حسابي", Icons.Default.Person),
}

/** كل الانتقالات من Motion.* (مدة واحدة + easing واحد). تُضاف الشاشات الجديدة هنا فقط بعد اكتمالها فعليًا. */
@Composable
fun AppNav(vm: MainViewModel = viewModel()) {
    val nav = rememberNavController()
    val current = nav.currentBackStackEntryAsState().value?.destination?.route
    Scaffold(bottomBar = {
        NavigationBar {
            Tab.entries.forEach { t ->
                NavigationBarItem(
                    selected = current == t.route,
                    onClick = {
                        if (current != t.route) nav.navigate(t.route) {
                            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true; restoreState = true
                        }
                    },
                    icon = { androidx.compose.material3.Icon(t.icon, contentDescription = t.label) },
                    label = { Text(t.label) },
                )
            }
        }
    }) { pad ->
        NavHost(
            navController = nav, startDestination = Tab.Home.route, modifier = Modifier.padding(pad),
            enterTransition = { Motion.tabEnter }, exitTransition = { Motion.tabExit },
            popEnterTransition = { Motion.tabEnter }, popExitTransition = { Motion.tabExit },
        ) {
            composable(Tab.Home.route) { HomeScreen(vm) }
            composable(Tab.Tx.route) { TransactionsScreen(vm) }
            composable(Tab.Accounts.route) { AccountsScreen(vm) }
            composable(Tab.Profile.route) { ProfileScreen(vm) }
        }
    }
}
