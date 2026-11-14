import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import 'anim.dart';
import 'theme.dart';
import 'motion.dart';

/// زرّين جنب بعض (مثل «الأيام / الأسبوع» في صفحة التقارير) بخلفية منزلقة.
/// قابل لإعادة الاستخدام في أي صفحة:
///
/// ```dart
/// bool days = true;
/// SegToggle(first: 'الأيام', second: 'الأسبوع', firstSelected: days, onChanged: (v) => setState(() => days = v))
/// ```
class SegToggle extends StatelessWidget {
  final String first, second;

  /// true = الزر الأول مختار.
  final bool firstSelected;
  final ValueChanged<bool> onChanged;
  final double height;

  /// لون مميّز للخلفية المنزلقة (مثلًا البرتقالي) — لو null بيستخدم لون البطاقة العادي.
  final Color? accent;
  const SegToggle({super.key, required this.first, required this.second, required this.firstSelected, required this.onChanged, this.height = 52, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
      child: Stack(children: [
        AnimatedAlign(
          duration: CashUMotion.of(context, CashUMotion.tab),
          curve: CashUMotion.curve,
          alignment: firstSelected ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
          child: FractionallySizedBox(widthFactor: .5, child: Container(decoration: BoxDecoration(color: accent ?? p.card, borderRadius: BorderRadius.circular(14)))),
        ),
        Row(children: [
          Expanded(child: Tap(onTap: () => onChanged(true), child: Center(child: Text(first, style: TextStyle(fontWeight: FontWeight.w700, color: firstSelected ? (accent != null ? Colors.white : p.ink) : p.ink2))))),
          Expanded(child: Tap(onTap: () => onChanged(false), child: Center(child: Text(second, style: TextStyle(fontWeight: FontWeight.w700, color: firstSelected ? p.ink2 : (accent != null ? Colors.white : p.ink)))))),
        ]),
      ]),
    );
  }
}

/// نفس شكل SegToggle لكن لعدد أي من الخيارات (٢ أو أكتر) — الخلفية المنزلقة بتتحرك لتحت الخيار المختار.
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;
  final Color? accent;
  const SegTabs({super.key, required this.labels, required this.selected, required this.onChanged, this.height = 48, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final n = labels.length;
    final x = n <= 1 ? 0.0 : -1.0 + 2.0 * selected / (n - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
      child: Stack(children: [
        AnimatedAlign(
          duration: CashUMotion.of(context, CashUMotion.tab),
          curve: CashUMotion.curve,
          alignment: AlignmentDirectional(x, 0),
          child: FractionallySizedBox(widthFactor: 1 / n, child: Container(decoration: BoxDecoration(color: accent ?? p.card, borderRadius: BorderRadius.circular(14)))),
        ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Tap(
                onTap: () => onChanged(i),
                child: Center(child: Text(labels[i], maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected == i ? (accent != null ? Colors.white : p.ink) : p.ink2))),
              ),
            ),
        ]),
      ]),
    );
  }
}
