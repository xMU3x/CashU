import 'package:flutter/widgets.dart';

/// مصدر واحد لقيم الحركة في CashU (Material 3 Motion): مدد قصيرة + منحنيات قياسية.
/// أي انتقال جديد لازم يستخدم القيم والـ builders دي بدل أرقام أو منحنيات مكتوبة يدويًا.
///
/// | الحركة                  | المدة     |
/// |--------------------------|-----------|
/// | ضغط الأزرار              | ٩٠–١٢٠ms  |
/// | الأيقونات                | ١٠٠–١٥٠ms |
/// | انتقالات صغيرة           | ١٢٠–١٦٠ms |
/// | التبديل بين التبويبات     | ١٥٠–١٨٠ms |
/// | التنقل بين الشاشات        | ١٨٠–٢٢٠ms |
/// | النوافذ (Dialogs)         | ١٥٠–١٨٠ms |
/// | الأوراق السفلية           | ١٨٠–٢٢٠ms |
/// | فتح/غلق العناصر           | ١٥٠–٢٠٠ms |
class CashUMotion {
  CashUMotion._();

  // ───────── المدد ─────────
  /// ضغط الأزرار وتغذية الضغط.
  static const Duration press = Duration(milliseconds: 90);

  /// ارتداد الضغط (الرجوع لحجمه الطبيعي بعد الرفع).
  static const Duration release = Duration(milliseconds: 120);

  /// تبديل الأيقونات.
  static const Duration icon = Duration(milliseconds: 130);

  /// انتقالات العناصر الصغيرة (ألوان، شفافية، شيبس).
  static const Duration small = Duration(milliseconds: 140);

  /// التبديل بين التبويبات / SegToggle / الشريط السفلي.
  static const Duration tab = Duration(milliseconds: 170);

  /// «عقد حركة SegToggle»: المدة + المنحنى المرجعيان لكل حركة تبديل/ظهور/اختفاء في التطبيق.
  static const Duration seg = tab;
  static const Curve segCurve = curve;

  /// التنقل بين الشاشات (دخول وخروج بنفس المدة).
  static const Duration page = seg;

  /// النوافذ المنبثقة والقوائم.
  static const Duration dialog = seg;

  /// الأوراق السفلية (Bottom sheets).
  static const Duration sheet = seg;

  /// فتح/غلق العناصر القابلة للتوسيع.
  static const Duration expand = seg;

  /// ظهور عناصر القوائم أول مرة.
  static const Duration reveal = seg;

  /// عدّادات الأرقام (الأرصدة).
  static const Duration counter = Duration(milliseconds: 320);

  /// أعمدة/أشرطة الرسوم البيانية (أساس المدة؛ استخدم [chart] للتتابع).
  static const Duration chartBase = Duration(milliseconds: 260);

  /// امتلاء الموجة/شريط التقدّم عند تغيّر القيمة.
  static const Duration fill = Duration(milliseconds: 360);

  /// تأثيرات النجاح (علامة الصح / عملات) — مرة واحدة وقصيرة.
  static const Duration celebrate = Duration(milliseconds: 700);

  /// اهتزاز الرفض (خطأ إدخال).
  static const Duration shake = Duration(milliseconds: 320);

  /// فاصل ظهور حرف حرف (Typewriter).
  static const Duration typeStep = Duration(milliseconds: 22);

  /// دورات الحركة الهادئة المتكررة (لا تؤثر على التفاعل).
  static const Duration spinner = Duration(milliseconds: 900);
  static const Duration ambient = Duration(milliseconds: 1600);
  static const Duration orbit = Duration(milliseconds: 2600);
  static const Duration wave = Duration(seconds: 6);

  /// المدة الافتراضية (تنقّل الصفحات) — موجودة للتوافق مع الكود القديم.
  static const Duration duration = page;

  /// أقصى عدد عناصر في تتابع الظهور (عشان القوائم الطويلة ما تتأخرش).
  static const int staggerMax = 6;

  /// الفاصل الزمني بين عناصر التتابع.
  static const Duration staggerStep = Duration(milliseconds: 16);

  /// مدد واجهة (مش حركة بصرية بحتة) — متجمّعة هنا عشان مفيش أي مدة مكتوبة يدويًا خارج الملف ده.
  /// مدة بقاء التوست (عادي / فيه زر إجراء) والـ Island (عادي / فيه زر إجراء).
  static const Duration toast = Duration(milliseconds: 2400);
  static const Duration toastAction = Duration(milliseconds: 4600);
  static const Duration toastIsland = Duration(milliseconds: 2050);
  static const Duration toastIslandAction = Duration(milliseconds: 4250);

  /// تسخين التبويبات في الخلفية (أول مرة / بين كل تبويب والتاني).
  static const Duration warmFirst = Duration(milliseconds: 900);
  static const Duration warmGap = Duration(milliseconds: 450);

  /// فاصل بداية كل سطر في الـ Typewriter، وبقاء مؤشر «تمت المزامنة»، وإعادة محاولة تحميل أيقونة.
  static const Duration typeLine = Duration(milliseconds: 450);
  static const Duration syncedHold = Duration(seconds: 3);
  static const Duration imageRetry = Duration(seconds: 4);

  // ───────── قيم انتقالات (fade-through / shared-axis) ─────────
  /// إزاحة الصفحة الداخلة أفقيًا (نسبة من العرض) — shared-axis X.
  static const double sharedAxisShift = .1;

  /// الصفحة اللي تحت بتتزحزح بنسبة من إزاحة الداخلة (إحساس عمق).
  static const double sharedAxisBehind = .3;


  /// تكبير أيقونة التبويب النشط في الشريط السفلي.
  static const double navActiveScale = 1.14;

  /// إزاحة رأسية لعنصر القائمة قبل ظهوره (نسبة من ارتفاعه).
  static const double revealShift = .03;

  // ───────── المنحنيات ─────────
  /// المنحنى القياسي (دخول) — Material 3 emphasized-decelerate.
  static const Curve curve = Cubic(.2, 0, 0, 1);

  /// منحنى الخروج — Material 3 standard-accelerate (بيتسارع لحد آخر لحظة).
  /// ⚠️ ما تحطّهوش مباشرة في reverseCurve: Flutter بيطبّق reverseCurve على قيمة الأنيميشن وهي نازلة ١→٠،
  /// فالمنحنى المتسارع بيطلع «سريع في الأول ثم ساكن» (٨٥٪ من الحركة في أول نص المدة ونص المدة التاني الصفحة واقفة)
  /// = اللاج اللي كان بيبان عند الرجوع. استخدم [exitReverse] أو [DirectionalCurve].
  static const Curve exitCurve = Cubic(.3, 0, 1, 1);

  /// [exitCurve] مقلوب — القيمة الصح لـ reverseCurve (الخروج يبدأ فورًا ويتسارع لآخر الحركة بدون وقت ميت).
  static final Curve exitReverse = exitCurve.flipped;

  /// منحنى الحركات المتماثلة (تبويب/تبديل).
  static const Curve standard = Curves.easeInOutCubic;

  /// ارتداد واحد خفيف (علامة النجاح فقط).
  static const Curve pop = Curves.easeOutBack;

  /// حركة دورية هادئة (طفو/موجة).
  static const Curve loop = Curves.easeInOut;


  // ───────── أدوات ─────────
  /// هل المستخدم مفعّل «تقليل الحركة» في الجهاز؟
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

  /// المدة الفعلية (صفر لو تقليل الحركة مفعّل).
  static Duration of(BuildContext c, [Duration d = page]) => reduced(c) ? Duration.zero : d;

  /// تأخير تتابع الظهور لعنصر رقم [i] (بحد أقصى [staggerMax]).
  static Duration stagger(int i) => staggerStep * (i < 0 ? 0 : (i > staggerMax ? staggerMax : i));

  /// مدة عمود/عنصر رسم بياني رقم [i] (تتابع خفيف بحد أقصى).
  static Duration chart(int i, {int step = 16, int max = 8}) => Duration(milliseconds: chartBase.inMilliseconds + step * (i < 0 ? 0 : (i > max ? max : i)));

  // ───────── انتقالات الشاشات والتبويبات ─────────
  /// shared-axis (X) خفيف: الصفحة الداخلة بتنزلق والتحتها بتتزحزح شوية. الاتجاه حسب اللغة (RTL/LTR).
  /// بدون أي شفافية على الصفحة كلها (الـ FadeTransition على صفحة كاملة = saveLayer كل إطار = تقل) — الأداء أهم.
  static Widget sharedAxisX(BuildContext c, Animation<double> a, Animation<double> sa, Widget child) {
    if (reduced(c)) return child;
    final dx = (Directionality.of(c) == TextDirection.rtl ? -1 : 1) * sharedAxisShift;
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: Offset(-dx * sharedAxisBehind, 0)).animate(DirectionalCurve(sa)),
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(DirectionalCurve(a)),
        child: RepaintBoundary(child: child),
      ),
    );
  }

  // ───────── Builders موحّدة للنوافذ والقوائم ─────────
  /// transitionBuilder للنوافذ/القوائم المنبثقة: تلاشي + تكبير خفيف، خروج أسرع بمنحنى مختلف.
  static Widget dialogTransition(BuildContext c, Animation<double> a, Animation<double> sa, Widget child, {double from = .92}) {
    if (reduced(c)) return child;
    final cv = DirectionalCurve(a);
    return FadeTransition(
      opacity: cv,
      child: ScaleTransition(scale: Tween<double>(begin: from, end: 1).animate(cv), child: child),
    );
  }
}

/// أنيميشن بمنحنى دخول [CashUMotion.curve] ومنحنى خروج [CashUMotion.exitReverse] حسب اتجاه الأنيميشن الأب.
/// بديل لـ CurvedAnimation جوه transitionsBuilder: ما بيسجّلش listeners دايمة على أنيميشن الـ route
/// (CurvedAnimation اللي بتتعمل جوه builder بتتسرّب مع كل إعادة بناء لأنها مش بتتعمل لها dispose).
class DirectionalCurve extends Animation<double> with AnimationWithParentMixin<double> {
  DirectionalCurve(this.parent, {this.forwardCurve = CashUMotion.curve, Curve? reverseCurve}) : reverseCurve = reverseCurve ?? CashUMotion.exitReverse;

  @override
  final Animation<double> parent;
  final Curve forwardCurve;
  final Curve reverseCurve;

  @override
  double get value {
    final t = parent.value;
    if (t == 0.0 || t == 1.0) return t;
    return (parent.status == AnimationStatus.reverse ? reverseCurve : forwardCurve).transform(t);
  }

  @override
  String toString() => 'DirectionalCurve($parent)';
}
