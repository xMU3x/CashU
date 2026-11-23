# CashU v47 — منع تكرار (SMS ↔ إشعار) + أداء الحركات

## الملفات المتغيّرة

### lib/sms/sms_dedup.dart
- `enum DupLevel { none, maybe, sure }` + ثابتين لأسباب المراجعة `kReasonMaybeDupFromSms = 'maybe_dup'` و`kReasonMaybeDupFromNotif = 'maybe_dup_n'`.
- ثابت واجهة جديد `kHeldUiTick` (ثانية واحدة) لتحديث العدّاد التنازلي في كارت الانتظار فقط. **قيمة جديدة** (مفيش في الملف ما يغطي تحديث عدّاد ثواني) — مالهاش أي تأثير على الاحتجاز. باقي ثوابت الاحتجاز والنوافذ بنفس الأسماء والقيم.
- `namesSimilar()` (نفس قاعدة `smsNm`: ٣ حروف على الأقل ومحتوى أحدهم في التاني).
- `dupLevel(a, b)`: مرجع متطابق ← sure. قناتين مختلفتين: آخر ٤ أرقام متطابقة (من الطرفين) أو اسم متشابه ← sure، غير كده ← maybe. آخر ٤ مختلفة ← none. نفس القناة: القواعد القديمة بالظبط (sure أو none).
- `isDuplicateOp` بقت = `dupLevel == sure` (الـmaybe مش بيتعامل كتكرار).
- `ledgerDupLevel()` جديدة (sure يغلب maybe) و`ledgerDup` = `sure` فقط.
- `crossMatchLevel()` جديدة (نفس المنطق للمعاملات المسجّلة وعناصر المراجعة) و`crossMatch` = `sure` فقط.
- `NotifHold.takeDuplicatesOf` = sure فقط (زي الأول)، وجديدة `takeMaybeDuplicatesOf` ترجّع الإشعارات «محتمل» وتشيلها من الانتظار.

### lib/sms/sms_tracker.dart
1. **الاحتجاز بس لما التتبع شغال:** شرط الاحتجاز بقى `hold && enabled && !maybeDup && sender.startsWith('N:')`. لو تتبع الرسايل مقفول الإشعار يتعالج فورًا.
   **Flush عند القفل:** `setEnabled(false)` بينادي `releaseHeld(all: true)` لو في إشعارات محتجزة (الوسيط `all` بقى مستخدم).
2. **ممنوع الحذف الصامت:**
   - `_dropHeldDuplicatesOf`: المتأكد يتشال زي الأول. المحتمل بيتشال من الانتظار وبيتسجّل في المراجعة (`_reviewMaybeHeld`) بعد ما رسالة الـSMS تتعالج (جوه `try/finally` في `_ingestCore` الجديد، فمفيش إشعار بيضيع لو المعالجة فشلت). ما بيتضافش للدفتر عشان الرسالة ما تتحسبش «محتمل» عليه.
   - المسار العكسي: `_ledgerDup` بقت `_ledgerDupLevel`، و`_crossDupTx` و`_crossDupReview` بترجّع `(sure, maybe)`. sure ← مكرر زي الأول. maybe ← العنصر يدخل المراجعة بسبب `محتمل تكرار لمعاملة اتسجلت من رسالة` (لو الجاي إشعار) أو `... من إشعار` (لو الجاي رسالة)، من غير تسجيل تلقائي ومن غير انتظار.
   - `_ingestCore` بقت wrapper حوالين `_ingestOne` (نفس الجسم القديم)، و`_reviewEntry()` مصنع واحد لعنصر المراجعة (نفس الحقول).
3. **المراجعة تتحدّث:** `notifyListeners()` بعد إضافة إشعار للانتظار وبعد الإفراج. getter جديد `heldItems` (قراءة فقط).
4. `_crossMatch` بقت `_crossLevel` (بترجّع `DupLevel`).

### lib/pages/sms_pages.dart
- كارت «إشعارات في الانتظار» في أول قايمة المراجعة (`_HeldCard`): لكل إشعار المبلغ والاسم والوقت المتبقي (عدّاد تنازلي لحد `dueAt`)، وزرار «سجّل دلوقتي» بينادي `releaseHeld(all: true)`. الكارت ظاهر حتى لو قايمة المراجعة فاضية.
- نصوص الأسباب `maybe_dup` / `maybe_dup_n` في `_reasonText`.

### lib/ui/anim.dart
- `Reveal` بيشتغل **مرة واحدة لكل key**: لو اتمرّر `key` وكان اتحرّك قبل كده بيبدأ `on = true` بدون حركة (Set ثابتة مقصوصة على ٦٠٠ مفتاح). من غير key السلوك زي ما هو. ترتيب التتابع لأول ظهور ما اتغيرش.
- تصحيح التعليق: «بحد أقصى ٦ عناصر ([CashUMotion.staggerMax])» بدل ٨.

### lib/pages/goals_page.dart · lib/pages/extra_tabs.dart · lib/pages/assoc_inst.dart
- تمرير `ValueKey` ثابت (id الهدف / الميزانية / الجمعية) للـ`Reveal` في القوايم الديناميكية.

### test/sms_dedup_test.dart
- المودل بقى فيه `reviewed`، والاختبارات اتحدّثت لقاعدة المستويين، وأُضيفت: محتمل ← مراجعة، `takeMaybeDuplicatesOf`، تفريغ `takeDue(1 << 62)`، آخر ٤ أرقام متطابقة، تحويلين بنفس المبلغ.

## بدون تغيير (اتراجعت)
- `lib/ui/shell_scope.dart`: `KeepAliveTabs` **بالفعل** بتلف كل تبويب بـ`TickerMode(enabled: id == current)` + `TabActivity`، فكل tickers (`WaveFill`/`Bob`/`CashULottie`/`DotsSpinner`/المدار) بتقف في التبويب المخفي. مفيش تعديل لازم.
- `CashUMotion` و`kGlassBlur`: ما اتلمسوش. Supabase: ما اتلمسش.

## اختبار
- `test/sms_dedup_test.dart` اتشغّل تحت Dart 3.14.1 الحقيقي بـ shim بسيط بدل flutter_test: ٤٢ تأكيد نجحوا، ٠ فشل.
- كل الملفات المعدّلة عدّت فحص الصياغة (`dart format`).
- **لم يتم** `flutter analyze` ولا بناء ولا تشغيل على جهاز (مفيش Flutter SDK هنا).
