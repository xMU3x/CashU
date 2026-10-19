import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/currency.dart';
import 'core/extras.dart';
import 'core/repo.dart';
import 'core/store.dart';
import 'core/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await store.init();
  repo.init();
  extras.init();
  rates.load();
  try {
    await sync.init();
  } catch (e) {
    debugPrint('sync init: $e');
  }
  runApp(const CashUApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    rates.refresh();
    repo.runRecurring();
    extras.runAuto();
  });
}
