import 'package:flutter/widgets.dart' hide Text;

/// يصغّر/يكبّر الواجهة كلها (الخط والأزرار والمسافات) بنسبة واحدة متناسقة،
/// ويتجاهل تكبير خط النظام الذي كان يسبب تداخل الأزرار.
class UiScale extends StatelessWidget {
  final double scale;
  final Widget child;
  const UiScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = scale.clamp(.6, 1.0).toDouble();
    if (s >= .999) {
      return MediaQuery(data: mq.copyWith(textScaler: TextScaler.noScaling), child: child);
    }
    final w = mq.size.width / s, h = mq.size.height / s;
    final data = mq.copyWith(
      size: Size(w, h),
      padding: mq.padding / s,
      viewPadding: mq.viewPadding / s,
      viewInsets: mq.viewInsets / s,
      systemGestureInsets: mq.systemGestureInsets / s,
      textScaler: TextScaler.noScaling,
    );
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: w,
        maxWidth: w,
        minHeight: h,
        maxHeight: h,
        child: Transform.scale(
          scale: s,
          alignment: Alignment.topLeft,
          child: SizedBox(width: w, height: h, child: MediaQuery(data: data, child: child)),
        ),
      ),
    );
  }
}
