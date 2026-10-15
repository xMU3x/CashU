import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'features/shell.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storeProvider);
    final mode = cfg.get('mode');
    return MaterialApp(
      title: 'فلوسي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode == 'dark'
          ? ThemeMode.dark
          : mode == 'light'
              ? ThemeMode.light
              : ThemeMode.system,
      home: const Shell(),
    );
  }
}
