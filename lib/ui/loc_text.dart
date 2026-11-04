import 'package:flutter/material.dart' as m;
import '../core/i18n.dart';

/// بديل لـ Text يترجم النص تلقائيًا حسب لغة التطبيق (عربي/إنجليزي).
/// يُستورد في الملفات مع `hide Text` فلا يتغيّر أي موضع استخدام.
class Text extends m.StatelessWidget {
  final String? data;
  final m.InlineSpan? span;
  final m.TextStyle? style;
  final int? maxLines;
  final m.TextOverflow? overflow;
  final m.TextAlign? textAlign;
  final bool? softWrap;
  final m.TextDirection? textDirection;
  final String? semanticsLabel;
  final m.TextScaler? textScaler;

  const Text(String this.data, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap, this.textDirection, this.semanticsLabel, this.textScaler}) : span = null;
  const Text.rich(m.InlineSpan this.span, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap, this.textDirection, this.semanticsLabel, this.textScaler}) : data = null;

  @override
  m.Widget build(m.BuildContext context) {
    if (span != null) {
      return m.Text.rich(span!, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, softWrap: softWrap, textDirection: textDirection, semanticsLabel: semanticsLabel, textScaler: textScaler);
    }
    return m.Text(tl(data!), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, softWrap: softWrap, textDirection: textDirection, semanticsLabel: semanticsLabel, textScaler: textScaler);
  }
}
