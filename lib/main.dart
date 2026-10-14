import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/store.dart';
import 'core/sync.dart';
import 'data/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('ar');
  await store.init();
  await Repo().ensureDefaults();
  try {
    await sync.init();
  } catch (e) {
    debugPrint('sync init: $e');
  }
  runApp(const ProviderScope(child: App()));
}
