import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'store.dart';

/// مفتاح موافقة المستخدم على إرسال تقارير الأعطال (محلي على الجهاز فقط — غير مُزامَن).
const String kCrashConsentKey = 'crash_reports';

/// تقارير الأعطال عبر Firebase Crashlytics.
///
/// - اختياري بالكامل: لو `google-services.json` غير موجود وقت البناء فالتهيئة بتفشل بهدوء والتطبيق يكمل عادي.
/// - مقفول افتراضيًا (opt-in): مفيش أي إرسال إلا لو المستخدم فعّله من الإعدادات.
/// - لا نرسل بيانات مالية: بنسجّل الأعطال (stack trace) فقط، ومفيش setCustomKey/معرّف مستخدم.
class CrashReporter {
  bool _ready = false;

  /// هل Firebase اتهيّأ بنجاح على الجهاز ده؟
  bool get ready => _ready;

  /// موافقة المستخدم المحفوظة.
  bool get consented => store.get(kCrashConsentKey, false) == true;

  /// التجميع الفعلي: جاهز + موافقة + مش وضع debug.
  bool get active => _ready && consented && !kDebugMode;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(active);
    } catch (e) {
      // google-services.json غير موجود أو Firebase غير مهيّأ: نكمل بدون Crashlytics.
      debugPrint('crash init skipped: $e');
      return;
    }
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      if (prevFlutter != null) {
        prevFlutter(details);
      } else {
        FlutterError.presentError(details);
      }
      if (active) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (active) FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// يحفظ موافقة المستخدم ويطبّقها فورًا.
  Future<void> setConsent(bool v) async {
    store.set(kCrashConsentKey, v);
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(active);
    } catch (e) {
      debugPrint('crash consent: $e');
    }
  }
}

final CrashReporter crash = CrashReporter();
