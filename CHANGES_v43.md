# CashU v43 — التعديلات عن v42

## الحركة (Part A)
- pubspec: حزمة `lottie` + `assets/lottie/` ؛ ملفات Lottie أصلية (tool/gen_lottie.py): success_check / empty_state / loading_dots
- lib/ui/lottie_views.dart (جديد): LottieSuccess / LottieEmpty / LottieLoading — المدد من CashUMotion
- lib/ui/motion.dart: sharedAxisX + fadeThrough + PushFade + ثوابت (toast, warm, typeLine, syncedHold, imageRetry, navActiveScale…)
- theme.dart: انتقال الصفحات = CashUMotion.sharedAxisX (flowRoute/الثيم)
- shell_scope.dart: fade-through بين التبويبات (هيكل ثابت للحفاظ على الحالة)
- app.dart: أيقونة التبويب النشط بتكبر (navActiveScale)
- anim.dart: Reveal بتلاشي لأول ٦ عناصر، successCheck = Lottie، CountText يحترم تقليل الحركة
- widgets.dart emptyState = Lottie؛ track_pages لودينج = Lottie؛ add_tx صفوف متدرجة؛ acc_tx أول عناصر القائمة متدرجة
- نقل كل المدد/المنحنيات اليدوية لـ motion.dart (lib/ui + lib/pages)

## تكرار الرسايل/الإشعارات (Part B)
- lib/sms/sms_dedup.dart (جديد): منطق نقي (crossMatch / isDuplicateOp / sameAmount / NotifHold)
- sms_tracker.dart: احتجاز الإشعار 75 ثانية (يتحفظ في store)، SMS تشيله لو نفس العملية؛ المرجع المختلف يفصل جوه نفس القناة بس؛ نافذة 10 دقايق بين القنوات؛ _crossDupTx بيمرر اختلاف القناة (خريطة tyr_sms_txch)؛ سماحية رسوم إنستاباي
- اختبارات: test/sms_dedup_test.dart, no_handwritten_motion_test.dart, lottie_assets_test.dart, motion_test.dart
