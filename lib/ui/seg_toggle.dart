import 'package:flutter/material.dart' hide Text;
import 'loc_text.dart';
import 'anim.dart';
import 'theme.dart';

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
  const SegToggle({super.key, required this.first, required this.second, required this.firstSelected, required this.onChanged, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(18)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: firstSelected ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
          child: FractionallySizedBox(widthFactor: .5, child: Container(decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)))),
        ),
        Row(children: [
          Expanded(child: Tap(onTap: () => onChanged(true), child: Center(child: Text(first, style: TextStyle(fontWeight: FontWeight.w700, color: firstSelected ? p.ink : p.ink2))))),
          Expanded(child: Tap(onTap: () => onChanged(false), child: Center(child: Text(second, style: TextStyle(fontWeight: FontWeight.w700, color: firstSelected ? p.ink2 : p.ink))))),
        ]),
      ]),
    );
  }
}
