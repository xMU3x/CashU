import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart' hide Text;
import '../core/i18n.dart';

export '../core/i18n.dart' show L, tr, monthName, monthShort, weekdayName;

/// بديل لـ Text يترجم النص تلقائيًا حسب لغة التطبيق (عربي / English).
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;

  const Text(String this.data, {super.key, this.style, this.strutStyle, this.textAlign, this.textDirection, this.softWrap, this.overflow, this.maxLines, this.semanticsLabel, this.textWidthBasis}) : textSpan = null;

  const Text.rich(InlineSpan this.textSpan, {super.key, this.style, this.strutStyle, this.textAlign, this.textDirection, this.softWrap, this.overflow, this.maxLines, this.semanticsLabel, this.textWidthBasis}) : data = null;

  @override
  Widget build(BuildContext context) {
    if (textSpan != null) {
      return m.Text.rich(textSpan!, style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, softWrap: softWrap, overflow: overflow, maxLines: maxLines, semanticsLabel: semanticsLabel, textWidthBasis: textWidthBasis);
    }
    return m.Text(L.t(data!), style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, softWrap: softWrap, overflow: overflow, maxLines: maxLines, semanticsLabel: semanticsLabel, textWidthBasis: textWidthBasis);
  }
}
