import 'package:flutter/material.dart';

import '../core/sync.dart';
import '../core/theme.dart';
import '../core/util.dart';
import 'accounts/accounts_page.dart';
import 'home/home_page.dart';
import 'settings/settings_page.dart';
import 'stats/stats_page.dart';
import 'transactions/add_transaction_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int i = 0;
  static const _titles = ['الرئيسية', 'الإحصائيات', 'حساباتي', 'الإعدادات'];
  static const _pages = [
    HomePage(),
    StatsPage(),
    AccountsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync.onResume();
  }

  void _add() {
    tick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[i]), centerTitle: false),
      extendBody: true,
      body: IndexedStack(index: i, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              // في RTL أول عنصر على اليمين: زر الإضافة ثم الشريط
              Material(
                color: kInk,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _add,
                  child: const SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PillNav(
                  index: i,
                  onTap: (v) {
                    tick();
                    setState(() => i = v);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, 'الرئيسية'),
    (Icons.bar_chart_rounded, 'الإحصائيات'),
    (Icons.account_balance_wallet_outlined, 'حساباتي'),
    (Icons.settings_outlined, 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          for (var k = 0; k < _items.length; k++)
            Expanded(
              flex: k == index ? 3 : 1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(k),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_items[k].$1,
                          color: k == index ? Colors.white : Colors.white54),
                      if (k == index) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _items[k].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
