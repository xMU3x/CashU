import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../core/currency.dart';
import '../core/extras.dart';
import '../core/icon_pick.dart';
import '../core/i18n.dart';
import '../core/repo.dart';
import '../core/settings.dart';
import '../ui/anim.dart';
import '../ui/ios.dart';
import '../ui/loc_text.dart';
import '../ui/pickers.dart';
import '../ui/sheets.dart';
import '../ui/theme.dart';
import '../ui/shell_scope.dart';
import '../ui/widgets.dart';

String _n(double v) {
  final s = fixed2(v);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _m(double v) => S.flag('hide') ? '••••' : '${_n(v)} ${curOf('EGP').sym}';

class _Svc {
  final String key, ar, en, group, domain;
  final Color color;
  const _Svc(this.key, this.ar, this.en, this.color, this.group, this.domain);
}

const _kSvcs = <_Svc>[
  _Svc('netflix', 'نتفليكس', 'Netflix', Color(0xFFE50914), 'مشاهدة وبث', 'netflix.com'),
  _Svc('shahid', 'شاهد', 'Shahid', Color(0xFF1F8A5B), 'مشاهدة وبث', 'shahid.mbc.net'),
  _Svc('watchit', 'ووتش إت', 'Watch iT', Color(0xFFE6007E), 'مشاهدة وبث', 'watchit.com'),
  _Svc('osn', 'أو إس إن+', 'OSN+', Color(0xFF6C3FD1), 'مشاهدة وبث', 'osn.com'),
  _Svc('starz', 'ستارزبلاي', 'StarzPlay', Color(0xFF1B6B7A), 'مشاهدة وبث', 'starzplay.com'),
  _Svc('disney', 'ديزني+', 'Disney+', Color(0xFF113CCF), 'مشاهدة وبث', 'disneyplus.com'),
  _Svc('prime', 'برايم فيديو', 'Prime Video', Color(0xFF00A8E1), 'مشاهدة وبث', 'primevideo.com'),
  _Svc('appletv', 'أبل تي في+', 'Apple TV+', Color(0xFF6E6E73), 'مشاهدة وبث', 'tv.apple.com'),
  _Svc('max', 'ماكس', 'Max', Color(0xFF5822B4), 'مشاهدة وبث', 'max.com'),
  _Svc('hulu', 'هولو', 'Hulu', Color(0xFF1CAE6B), 'مشاهدة وبث', 'hulu.com'),
  _Svc('paramount', 'باراماونت+', 'Paramount+', Color(0xFF0064FF), 'مشاهدة وبث', 'paramountplus.com'),
  _Svc('crunchyroll', 'كرنشي رول', 'Crunchyroll', Color(0xFFF47521), 'مشاهدة وبث', 'crunchyroll.com'),
  _Svc('youtube', 'يوتيوب بريميوم', 'YouTube Premium', Color(0xFFE62117), 'مشاهدة وبث', 'youtube.com'),
  _Svc('spotify', 'سبوتيفاي', 'Spotify', Color(0xFF1DB954), 'موسيقى', 'spotify.com'),
  _Svc('anghami', 'أنغامي', 'Anghami', Color(0xFF8E24AA), 'موسيقى', 'anghami.com'),
  _Svc('applemusic', 'أبل ميوزك', 'Apple Music', Color(0xFFFA243C), 'موسيقى', 'music.apple.com'),
  _Svc('ytmusic', 'يوتيوب ميوزك', 'YouTube Music', Color(0xFFFF0000), 'موسيقى', 'music.youtube.com'),
  _Svc('deezer', 'ديزر', 'Deezer', Color(0xFFA238FF), 'موسيقى', 'deezer.com'),
  _Svc('icloud', 'آي كلاود+', 'iCloud+', Color(0xFF3693F3), 'تخزين وأدوات', 'icloud.com'),
  _Svc('google', 'جوجل ون', 'Google One', Color(0xFF4285F4), 'تخزين وأدوات', 'one.google.com'),
  _Svc('dropbox', 'دروب بوكس', 'Dropbox', Color(0xFF0061FF), 'تخزين وأدوات', 'dropbox.com'),
  _Svc('chatgpt', 'ChatGPT', 'ChatGPT', Color(0xFF10A37F), 'تخزين وأدوات', 'chatgpt.com'),
  _Svc('claude', 'Claude', 'Claude', Color(0xFFD97757), 'تخزين وأدوات', 'claude.ai'),
  _Svc('m365', 'مايكروسوفت 365', 'Microsoft 365', Color(0xFFD83B01), 'تخزين وأدوات', 'microsoft365.com'),
  _Svc('adobe', 'أدوبي', 'Adobe', Color(0xFFFA0F00), 'تخزين وأدوات', 'adobe.com'),
  _Svc('canva', 'كانفا', 'Canva', Color(0xFF00A3AD), 'تخزين وأدوات', 'canva.com'),
  _Svc('notion', 'نوشن', 'Notion', Color(0xFF6E6E73), 'تخزين وأدوات', 'notion.so'),
  _Svc('telegram', 'تيليجرام بريميوم', 'Telegram Premium', Color(0xFF26A5E4), 'تواصل وتعلّم', 'telegram.org'),
  _Svc('xpremium', 'إكس بريميوم', 'X Premium', Color(0xFF1D9BF0), 'تواصل وتعلّم', 'x.com'),
  _Svc('linkedin', 'لينكدإن بريميوم', 'LinkedIn Premium', Color(0xFF0A66C2), 'تواصل وتعلّم', 'linkedin.com'),
  _Svc('duolingo', 'دولينجو', 'Duolingo', Color(0xFF58CC02), 'تواصل وتعلّم', 'duolingo.com'),
  _Svc('xbox', 'إكس بوكس جيم باس', 'Xbox Game Pass', Color(0xFF107C10), 'ألعاب', 'xbox.com'),
  _Svc('playstation', 'بلايستيشن بلس', 'PlayStation Plus', Color(0xFF0070D1), 'ألعاب', 'playstation.com'),
  _Svc('nintendo', 'نينتندو أونلاين', 'Nintendo Switch Online', Color(0xFFE60012), 'ألعاب', 'nintendo.com'),
];

_Svc? _svcOf(String k) {
  for (final s in _kSvcs) {
    if (s.key == k) return s;
  }
  return null;
}

Color _colorOf(Sub s) => s.colorV != 0 ? Color(s.colorV) : (_svcOf(s.svc)?.color ?? kBlue);

/// لون نص/تفاصيل واضح فوق خلفية الاشتراك المتلوّنة (فاتح في الداكن، غامق في الفاتح).
Color _fg(BuildContext c, Color col) => Theme.of(c).brightness == Brightness.dark ? Color.lerp(col, Colors.white, .5)! : Color.lerp(col, Colors.black, .35)!;

const _kPalette = <int>[0xFFE50914, 0xFFF5A623, 0xFFF2C94C, 0xFF1DB954, 0xFF16A394, 0xFF3693F3, 0xFF5822B4, 0xFF8E24AA, 0xFFE91E63, 0xFF6E6E73];

/// لوجو الخدمة: صورة مخصّصة (رفع/رابط) ← أيقونة الخدمة الرسمية (favicon عالي الجودة) ← حرف ملوّن.
class _SubLogo extends StatelessWidget {
  final String name, svc, img;
  final Color color;
  final double size;
  const _SubLogo({required this.name, required this.svc, this.img = '', required this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * .28);
    final fb = _logo(name, color, size: size);
    Widget net(String url, {bool white = false}) => ClipRRect(
          borderRadius: r,
          child: Container(
            width: size,
            height: size,
            color: white ? Colors.white : Colors.transparent,
            padding: EdgeInsets.all(white ? size * .14 : 0),
            child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => fb, loadingBuilder: (c, ch, pr) => pr == null ? ch : fb),
          ),
        );
    if (img.startsWith('data:image')) {
      try {
        return ClipRRect(borderRadius: r, child: Image.memory(base64Decode(img.substring(img.indexOf(',') + 1)), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (c, e, s) => fb));
      } catch (_) {
        return fb;
      }
    }
    if (img.startsWith('http')) return net(img);
    final sv = _svcOf(svc);
    if (sv != null) return net('https://www.google.com/s2/favicons?domain=${sv.domain}&sz=128', white: true);
    return fb;
  }
}

Widget _logo(String name, Color c, {double size = 48}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * .28)),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: size * .45, fontWeight: FontWeight.w800)),
    );

/// شاشة الاشتراكات الواحدة: نفس الصفحة من الشريط السفلي ومن «المزيد».
class SubscriptionsPage extends StatefulWidget {
  final bool embedded;
  const SubscriptionsPage({super.key, this.embedded = false});
  @override
  State<SubscriptionsPage> createState() => _SubsState();
}

class _SubsState extends State<SubscriptionsPage> {
  String filter = 'all';

  Future<void> _addFlow({bool pick = true}) async {
    if (pick) {
      final r = await showServicePicker(context);
      if (r == null || !mounted) return;
      Navigator.of(context).push(flowRoute(SubFormPage(name: r.$1, svc: r.$2)));
    } else {
      Navigator.of(context).push(flowRoute(const SubFormPage()));
    }
  }

  bool _match(Sub s) {
    switch (filter) {
      case 'active':
        return s.isActive && !s.inTrial;
      case 'trial':
        return s.inTrial && s.state != 'stopped';
      case 'paused':
        return s.state != 'active';
      default:
        return true;
    }
  }

  Widget _header(Pal p) => Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(30)),
        child: Row(children: [
          if (!widget.embedded)
            Tap(onTap: () => Navigator.of(context).maybePop(), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: p.field, shape: BoxShape.circle), child: Icon(Icons.arrow_back_rounded, color: p.ink2))),
          if (!widget.embedded) const SizedBox(width: 10),
          const Icon(Icons.widgets_rounded, color: Color(0xFF8B5CF6), size: 24),
          const SizedBox(width: 10),
          const Expanded(child: Text('اشتراكاتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _empty(Pal p) => ListView(padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 130), physics: const BouncingScrollPhysics(), children: [
        _header(p),
        const SizedBox(height: 18),
        Container(
          height: 150,
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(28)),
          child: Center(child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBlue, width: 6)), child: Icon(Icons.add_rounded, color: kBlue, size: 36))),
        ),
        const SizedBox(height: 22),
        const Text('بتدفع كام فعلًا على الاشتراكات؟', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 8),
        Text('ضيفهم وهتشوف كل واحد قد إيه من شهرك، وهنفكرك قبل ما أي واحد يتجدد.', style: TextStyle(fontSize: 15, color: p.ink2, height: 1.5)),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _bigCard(p, Icons.grid_view_rounded, 'اختار من القائمة', 'شاهد، Netflix، وغيرهم', p.card, kBlue, () => _addFlow())),
          const SizedBox(width: 12),
          Expanded(child: _bigCard(p, Icons.edit_rounded, 'ضيفه بنفسك', 'النادي، النت، أي حاجة', p.card, kBlue, () => _addFlow(pick: false))),
        ]),
      ]);

  Widget _bigCard(Pal p, IconData ic, String t, String sub, Color bg, Color fg, VoidCallback f) => Tap(
        scale: .97,
        onTap: f,
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, color: fg, size: 28),
            const Spacer(),
            Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: fg)),
          ]),
        ),
      );

  Widget _summary(Pal p, List<Sub> all) {
    final live = all.where((s) => s.isActive && !s.inTrial && s.cyc != 'once').toList()..sort((a, b) => b.monthly.compareTo(a.monthly));
    final total = live.fold(0.0, (a, s) => a + s.monthly);
    final soon = all.where((s) => s.state != 'stopped' && (s.daysLeft ?? 99) <= 7 && (s.daysLeft ?? 99) >= 0).length;
    final top = live.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line.withValues(alpha: .6))),
      child: Row(children: [
        SizedBox(
          width: 138,
          height: 138,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(138, 138), painter: _Donut([for (final s in live) (s.monthly, _colorOf(s))], p.field)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_m(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('كل شهر', style: TextStyle(fontSize: 12, color: p.ink2)),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in top)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: _colorOf(s), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                  Text('${total <= 0 ? 0 : (s.monthly / total * 100).round()}%', style: TextStyle(fontSize: 13, color: p.ink2)),
                ]),
              ),
            Text('كل سنة ${_m(total * 12)}', style: TextStyle(fontSize: 13, color: p.ink2)),
            if (soon > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(soon == 1 ? 'واحد هيتجدد الأسبوع ده' : '$soon هيتجددوا الأسبوع ده', style: const TextStyle(fontSize: 13, color: kOrange, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(Pal p, String k, String t) {
    final on = filter == k;
    return Expanded(
      child: Tap(
        scale: .96,
        onTap: () => setState(() => filter = k),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? p.field : p.card, borderRadius: BorderRadius.circular(18)),
          child: Text(t, style: TextStyle(fontSize: 14.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? p.ink : p.ink2)),
        ),
      ),
    );
  }

  String _sub(Sub s) {
    final d = s.daysLeft;
    if (s.state == 'paused') return 'متوقف مؤقتاً';
    if (s.state == 'stopped') return 'ملغي';
    if (s.inTrial) return 'تجربة مجاناً  ·  التجربة بتخلص بعد ${d ?? 0} يوم';
    if (s.overdue) return '${cycleName(s.cyc)}  ·  متأخر ${s.overdueDays} يوم (Overdue)';
    if (s.cyc == 'once') return 'دفعة واحدة';
    return '${cycleName(s.cyc)}  ·  ${d == null ? 'انتهى' : 'بيتجدد بعد $d يوم'}';
  }

  double _frac(Sub s) {
    final d = s.daysLeft;
    if (d == null || !s.isActive) return 0;
    final len = const {'week': 7, 'month': 30, 'q3': 91, 'h6': 182, 'year': 365}[s.cyc] ?? 30;
    return (1 - d / len).clamp(0.0, 1.0);
  }

  Widget _item(Pal p, Sub s) {
    final dim = s.state != 'active';
    final col = _colorOf(s);
    return Tap(
      scale: .985,
      onTap: () => showSubDetail(context, s.id),
      child: Opacity(
        opacity: dim ? .55 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(color: Color.alphaBlend(col.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .16 : .09), p.card), borderRadius: BorderRadius.circular(24), border: Border.all(color: col.withValues(alpha: .28))),
          child: Column(children: [
            Row(children: [
              _SubLogo(name: s.name, svc: s.svc, img: s.img, color: col),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(_sub(s), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.ink2)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_m(s.amt), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (s.cyc != 'once' && s.cyc != 'month') Text('≈ ${_m(s.monthly)}', style: TextStyle(fontSize: 12, color: p.ink2)),
              ]),
            ]),
            if (s.isActive && !s.inTrial && s.cyc != 'once') ...[
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _frac(s), minHeight: 4, backgroundColor: p.field, valueColor: AlwaysStoppedAnimation(col))),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Live(b: (c) {
        final all = extras.subs;
        if (all.isEmpty) return _empty(p);
        final list = all.where(_match).toList();
        return Stack(fit: StackFit.expand, children: [
          ListView(padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 150), physics: const BouncingScrollPhysics(), children: [
            _header(p),
            const SizedBox(height: 14),
            _summary(p, all),
            const SizedBox(height: 14),
            Row(children: [_chip(p, 'all', 'الكل'), _chip(p, 'active', 'شغالة'), _chip(p, 'trial', 'تجريبية'), _chip(p, 'paused', 'متوقفة')]),
            const SizedBox(height: 14),
            if (list.isEmpty) emptyState(p, Icons.widgets_outlined, 'مفيش اشتراكات في القسم ده.'),
            for (var i = 0; i < list.length; i++) Reveal(i: i, child: _item(p, list[i])),
          ]),
          addFab(context, () => _addFlow()),
        ]);
      }),
    );
  }
}

class _Donut extends CustomPainter {
  final List<(double, Color)> parts;
  final Color track;
  _Donut(this.parts, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(10, 10, s.width - 20, s.height - 20);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    final total = parts.fold(0.0, (a, x) => a + x.$1);
    if (total <= 0) return;
    var a0 = -math.pi / 2;
    for (final x in parts) {
      final sweep = x.$1 / total * math.pi * 2;
      final gap = parts.length > 1 ? .06 : 0.0;
      canvas.drawArc(r, a0, math.max(0, sweep - gap), false, Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.butt..color = x.$2);
      a0 += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut o) => o.parts != parts || o.track != track;
}

// ===================== اختيار الخدمة =====================
Future<(String, String)?> showServicePicker(BuildContext context) => showSheet<(String, String)>(context, (c) => const _SvcSheet());

class _SvcSheet extends StatefulWidget {
  const _SvcSheet();
  @override
  State<_SvcSheet> createState() => _SvcSheetState();
}

class _SvcSheetState extends State<_SvcSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = _kSvcs.where((s) => q.isEmpty || s.ar.contains(q) || s.en.toLowerCase().contains(q.toLowerCase())).toList();
    final groups = <String>[];
    for (final s in list) {
      if (!groups.contains(s.group)) groups.add(s.group);
    }
    return SheetFrame(
      title: 'اختار الخدمة',
      height: MediaQuery.of(context).size.height * .86,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
            child: TextField(onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(border: InputBorder.none, hintText: tl('دوّر على خدمة...'), hintStyle: TextStyle(color: p.ink2), icon: Icon(Icons.search_rounded, color: p.ink2))),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), children: [
            for (final g in groups) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text(g, style: TextStyle(color: p.ink2, fontSize: 14))),
              for (final s in list.where((x) => x.group == g))
                Tap(
                  onTap: () => Navigator.of(context).pop((s.ar, s.key)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      _SubLogo(name: s.en, svc: s.key, color: s.color, size: 52),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.ar, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), Text(s.en, style: TextStyle(fontSize: 14, color: p.ink2))])),
                    ]),
                  ),
                ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Tap(
            onTap: () async {
              final r = await promptText(context, 'اسم الخدمة', hint: 'اكتب الاسم');
              if (r != null && r.trim().isNotEmpty && context.mounted) Navigator.of(context).pop((r.trim(), ''));
            },
            child: Container(height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit_outlined, color: kOrange, size: 20), SizedBox(width: 8), Text('خدمة تانية — اكتب الاسم', style: TextStyle(color: kOrange, fontSize: 16, fontWeight: FontWeight.w600))])),
          ),
        ),
      ]),
    );
  }
}

// ===================== إضافة / تعديل اشتراك =====================
class SubFormPage extends StatefulWidget {
  final Sub? edit;
  final String? name, svc;
  const SubFormPage({super.key, this.edit, this.name, this.svc});
  @override
  State<SubFormPage> createState() => _SubFormState();
}

class _SubFormState extends State<SubFormPage> {
  String name = '', svc = '', cyc = 'month', acc = '', note = '', img = '';
  int colorV = 0;
  double amt = 0;
  DateTime first = DateTime.now(), trialEnd = DateTime.now().add(const Duration(days: 7));
  DateTime? until;
  bool trial = false, auto = false, budget = true;
  int remind = 2;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    name = widget.name ?? '';
    svc = widget.svc ?? '';
    if (e != null) {
      name = e.name;
      svc = e.svc;
      cyc = e.cyc;
      acc = e.acc;
      note = e.note;
      amt = e.amt;
      first = e.firstDate;
      until = e.until > 0 ? DateTime.fromMillisecondsSinceEpoch(e.until) : null;
      trial = e.trial;
      if (e.trialEnd > 0) trialEnd = DateTime.fromMillisecondsSinceEpoch(e.trialEnd);
      auto = e.auto;
      budget = e.budget;
      remind = e.remind;
      img = e.img;
      colorV = e.colorV;
    }
  }

  DateTime get _nextPreview {
    var d = first;
    final now = DateTime.now();
    if (cyc == 'once') return d;
    var g = 0;
    while (!d.isAfter(now) && g++ < 1200) {
      d = nextCycle(d, cyc);
    }
    return d;
  }

  Future<void> _save() async {
    if (name.trim().isEmpty) return toast(context, 'اكتب اسم الخدمة');
    if (amt <= 0) return toast(context, 'اكتب قيمة الدفعة');
    final old = widget.edit;
    final s = old?.clone() ?? Sub(id: 'sb_${DateTime.now().microsecondsSinceEpoch}', name: name, amt: amt, first: first.millisecondsSinceEpoch);
    s
      ..name = name.trim()
      ..svc = svc
      ..amt = amt
      ..cyc = cyc
      ..acc = acc
      ..note = note
      ..first = first.millisecondsSinceEpoch
      ..until = until?.millisecondsSinceEpoch ?? 0
      ..trial = trial
      ..trialEnd = trial ? trialEnd.millisecondsSinceEpoch : 0
      ..auto = auto
      ..budget = budget
      ..remind = remind
      ..img = img
      ..colorV = colorV;
    extras.saveSub(s);
    if (auto) extras.runAuto();
    if (mounted) Navigator.of(context).pop();
  }

  /// تخصيص صورة الاشتراك: رفع من الجهاز، سحب من رابط، أو العودة للأيقونة الرسمية.
  Future<void> _imageSheet() async {
    final p = Pal.of(context);
    Widget row(IconData ic, String t, Future<void> Function() f) => Tap(
          onTap: () async {
            Navigator.of(context).pop();
            await f();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: kBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: kBlue)),
              const SizedBox(width: 14),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            ]),
          ),
        );
    await showSheet<void>(context, (c) => SheetFrame(
          title: 'صورة الاشتراك',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              row(Icons.photo_library_rounded, 'رفع من الجهاز', () async {
                final r = await pickIconFromGallery();
                if (r != null && mounted) setState(() => img = r);
              }),
              row(Icons.link_rounded, 'سحب من رابط صورة', () async {
                final u = await promptText(context, 'رابط الصورة', hint: 'https://...');
                if (u == null || u.trim().isEmpty) return;
                if (mounted) toast(context, 'جارٍ تحميل الصورة...');
                final r = await iconFromUrl(u);
                if (!mounted) return;
                if (r == null) {
                  toast(context, 'تعذّر تحميل الصورة من الرابط');
                } else {
                  setState(() => img = r);
                }
              }),
              row(Icons.auto_awesome_rounded, 'استخدام الأيقونة الرسمية للخدمة', () async => setState(() => img = '')),
            ]),
          ),
        ));
  }

  Widget _palette(Pal p) => Wrap(spacing: 10, runSpacing: 10, children: [
        Tap(
          onTap: () => setState(() => colorV = 0),
          child: Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: BoxDecoration(color: colorV == 0 ? kBlue.withValues(alpha: .18) : p.card, borderRadius: BorderRadius.circular(19), border: Border.all(color: colorV == 0 ? kBlue : Colors.transparent)), child: Text('تلقائي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorV == 0 ? kBlue : p.ink2))),
        ),
        for (final v in _kPalette)
          Tap(
            onTap: () => setState(() => colorV = v),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Color(v), shape: BoxShape.circle, border: Border.all(color: colorV == v ? p.ink : Colors.transparent, width: 2.5)),
              child: colorV == v ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
            ),
          ),
      ]);

  Widget _label(Pal p, String t) => Padding(padding: const EdgeInsets.fromLTRB(6, 18, 6, 8), child: Text(t, style: TextStyle(fontSize: 15, color: p.ink2)));

  Widget _field(Pal p, IconData ic, String hint, String value, VoidCallback f, {String? small}) => Tap(
        onTap: f,
        scale: .99,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (small != null && value.isNotEmpty) Text(small, style: TextStyle(fontSize: 11.5, color: p.ink2)),
                Text(value.isEmpty ? hint : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: value.isEmpty ? p.ink2 : p.ink)),
              ]),
            ),
            Icon(ic, color: p.ink2, size: 22),
          ]),
        ),
      );

  Widget _chips(Pal p, List<(String, String)> opts, String sel, void Function(String) f) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          Tap(
            onTap: () => setState(() => f(o.$1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: o.$1 == sel ? kBlue.withValues(alpha: .18) : p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: o.$1 == sel ? kBlue : Colors.transparent)),
              child: Text(o.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: o.$1 == sel ? kBlue : p.ink2)),
            ),
          ),
      ]);

  Widget _switch(Pal p, IconData ic, String t, String sub, bool v, ValueChanged<bool> f) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          iosSwitch(v, f),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text(sub, style: TextStyle(fontSize: 13, color: p.ink2))])),
          Icon(ic, color: p.ink2, size: 22),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accName = repo.account(acc)?.name ?? '';
    return PageShell(
      title: widget.edit == null ? 'إضافة اشتراك' : 'تعديل اشتراك',
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), physics: const BouncingScrollPhysics(), children: [
            _label(p, 'التفاصيل'),
            Row(children: [
              Tap(
                onTap: _imageSheet,
                child: Stack(clipBehavior: Clip.none, children: [
                  _SubLogo(name: name, svc: svc, img: img, color: colorV != 0 ? Color(colorV) : (_svcOf(svc)?.color ?? kBlue), size: 64),
                  PositionedDirectional(bottom: -4, end: -4, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 2)), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: _field(p, Icons.inventory_2_outlined, 'اسم الخدمة', name, () async {
                final r = await promptText(context, 'اسم الخدمة', hint: 'اسم الخدمة', initial: name);
                if (r != null) setState(() => name = r.trim());
              }, small: 'اسم الخدمة')),
            ]),
            const SizedBox(height: 10),
            _field(p, Icons.payments_outlined, '${isAr ? 'قيمة الدفعة' : 'Payment amount'} (${curOf('EGP').sym})', amt == 0 ? '' : _n(amt), () async {
              final r = await showCalc(context, amt, 'EGP');
              if (r != null) setState(() => amt = r < 0 ? 0 : r);
            }, small: '${isAr ? 'قيمة الدفعة' : 'Payment amount'} (${curOf('EGP').sym})'),
            _label(p, 'لون الاشتراك'),
            _palette(p),
            _label(p, 'دورة الدفع'),
            _chips(p, kSubCycles, cyc, (v) => cyc = v),
            _label(p, 'المواعيد'),
            _field(p, Icons.event_rounded, 'أول دفعة كانت يوم', enDate(first), () async {
              final d = await showDateSheet(context, first, title: 'أول دفعة كانت يوم');
              if (d != null) setState(() => first = d);
            }, small: 'أول دفعة كانت يوم'),
            if (cyc != 'once')
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kBlue.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
                child: Text('يعني الدفعة الجاية يوم ${enDate(_nextPreview)}', style: TextStyle(color: kBlue, fontSize: 15)),
              ),
            _label(p, 'هيفضل شغال لحد إمتى؟'),
            _chips(p, const [('none', 'لحد ما ألغيه'), ('date', 'لحد يوم معيّن')], until == null ? 'none' : 'date', (v) => until = v == 'none' ? null : (until ?? DateTime.now().add(const Duration(days: 365)))),
            if (until != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: _field(p, Icons.event_busy_rounded, 'ينتهي يوم', enDate(until!), () async {
                final d = await showDateSheet(context, until!, title: 'ينتهي يوم');
                if (d != null) setState(() => until = d);
              })),
            _switch(p, Icons.card_giftcard_rounded, 'فترة تجريبية مجانية', 'هننبهك بيومين قبل ما تتحول لمدفوعة', trial, (v) => setState(() => trial = v)),
            if (trial)
              Padding(padding: const EdgeInsets.only(top: 10), child: _field(p, Icons.hourglass_bottom_rounded, 'التجربة بتخلص يوم', enDate(trialEnd), () async {
                final d = await showDateSheet(context, trialEnd, title: 'التجربة بتخلص يوم');
                if (d != null) setState(() => trialEnd = d);
              })),
            _switch(p, Icons.receipt_long_rounded, 'سجّل الدفعة عني', 'بتسجّل كل دفعة بنفسك', auto, (v) => setState(() => auto = v)),
            _label(p, 'فكّرني قبل التجديد'),
            _chips(p, const [('-1', 'من غير تذكير'), ('1', 'بيوم'), ('2', 'بيومين'), ('3', 'بـ 3 أيام'), ('7', 'بـ 7 أيام')], '$remind', (v) => remind = int.parse(v)),
            _label(p, 'خيارات زيادة'),
            _field(p, Icons.credit_card_rounded, 'بتدفع بإيه', accName, () async {
              final r = await showPickAccount(context, acc.isEmpty ? repo.defaultAcc : acc);
              if (r != null) setState(() => acc = r);
            }),
            const SizedBox(height: 10),
            _field(p, Icons.sticky_note_2_outlined, 'ملاحظة', note, () async {
              final r = await promptText(context, 'ملاحظة', hint: 'ملاحظة', initial: note);
              if (r != null) setState(() => note = r.trim());
            }),
            _switch(p, Icons.account_balance_wallet_outlined, 'احسبها من الميزانية', 'بتسجل في الحركات وبتتحسب في المصاريف', budget, (v) => setState(() => budget = v)),
            Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 0), child: Text('كل دفعة بتتسجل تحت تصنيف «الاشتراكات» في مصاريفك.', style: TextStyle(fontSize: 13, color: p.ink2))),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 14), child: bigButton(p, 'حفظ', kBlue, _save)),
      ]),
    );
  }
}

// ===================== تفاصيل الاشتراك =====================
Future<void> showSubDetail(BuildContext context, String id) => showSheet<void>(context, (c) => _SubDetail(id: id));

class _SubDetail extends StatefulWidget {
  final String id;
  const _SubDetail({required this.id});
  @override
  State<_SubDetail> createState() => _SubDetailState();
}

class _SubDetailState extends State<_SubDetail> {
  bool openLog = false;

  Sub? _cur() {
    for (final s in extras.subs) {
      if (s.id == widget.id) return s;
    }
    return null;
  }

  Future<void> _menu(Sub s) async {
    final p = Pal.of(context);
    final nav = Navigator.of(context);
    Widget row(IconData ic, Color c, String t, VoidCallback f) => Tap(
          onTap: () {
            Navigator.of(context).pop();
            f();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: c.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)), child: Icon(ic, color: c)),
              const SizedBox(width: 14),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            ]),
          ),
        );
    await showSheet<void>(context, (c) => SheetFrame(
          title: s.name,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              row(Icons.edit_rounded, kOrange, 'تعديل', () {
                nav.pop();
                nav.push(flowRoute(SubFormPage(edit: s)));
              }),
              if (s.state == 'stopped')
                row(Icons.restart_alt_rounded, kGreen, 'إعادة التفعيل', () => extras.saveSub(s..state = 'active'))
              else if (s.state == 'paused')
                row(Icons.play_circle_outline_rounded, kGreen, 'استئناف', () => extras.saveSub(s..state = 'active'))
              else
                row(Icons.pause_circle_outline_rounded, kOrange, 'إيقاف مؤقت', () => extras.saveSub(s..state = 'paused')),
              if (s.state != 'stopped')
                row(Icons.block_rounded, kRed, 'إلغاء الاشتراك', () async {
                  if (await confirmDialog(context, 'إلغاء الاشتراك', 'هيتحوّل "${s.name}" لملغي، وسجل الدفعات يفضل زي ما هو.', ok: 'إلغاء الاشتراك')) {
                    extras.saveSub(s..state = 'stopped');
                  }
                }),
              row(Icons.delete_outline_rounded, kRed, 'حذف نهائي', () async {
                if (await confirmDialog(context, 'حذف', 'هيتحذف "${s.name}" من القائمة.')) extras.delSub(s);
              }),
            ]),
          ),
        ));
  }

  /// بانل تسجيل دفعة: القيمة + التاريخ + الحساب اللي اتسحبت منه، وبتنزل في المعاملات.
  Future<void> _payPanel(Sub s) async {
    var amt = s.amt;
    var date = DateTime.now();
    var acc = s.acc.isEmpty ? repo.defaultAcc : s.acc;
    await showSheet<void>(context, (c) => StatefulBuilder(builder: (c, set) {
          final p = Pal.of(c);
          Widget field(IconData ic, String label, String value, Future<void> Function() f) => Tap(
                onTap: () => f(),
                scale: .99,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Icon(ic, color: p.ink2, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12.5, color: p.ink2)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))])),
                  ]),
                ),
              );
          final a = repo.account(acc);
          return SheetFrame(
            title: 'سجّل دفعة',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(s.name, style: TextStyle(fontSize: 15, color: p.ink2))),
                field(Icons.payments_outlined, '${isAr ? 'قيمة الدفعة' : 'Payment amount'} (${curOf('EGP').sym})', _n(amt), () async {
                  final r = await showCalc(c, amt, 'EGP');
                  if (r != null && r > 0) set(() => amt = r);
                }),
                field(Icons.event_rounded, 'تاريخ الدفعة', enDate(date), () async {
                  final d = await showDateSheet(c, date, title: 'تاريخ الدفعة');
                  if (d != null) set(() => date = d);
                }),
                field(Icons.credit_card_rounded, 'اتسحبت من حساب', a == null ? 'اختر الحساب' : a.name, () async {
                  final r = await showPickAccount(c, acc);
                  if (r != null) set(() => acc = r);
                }),
                const SizedBox(height: 6),
                bigButton(p, 'حفظ', kBlue, () {
                  final now = DateTime.now();
                  final ts = DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second).millisecondsSinceEpoch;
                  extras.paySub(s, ts: ts, amt: amt, acc: acc);
                  Navigator.of(c).pop();
                  toast(context, 'اتسجلت دفعة ${_m(amt)}');
                }),
              ]),
            ),
          );
        }));
  }

  Widget _timeline(Pal p, Sub s) {
    final base = _colorOf(s);
    final col = _fg(context, base);
    // التجديد الجاي ما يظهرش غير بعد ما تدفع المتأخر
    final next = s.overdue ? null : s.nextDue;
    final end = s.until > 0 ? enDate(DateTime.fromMillisecondsSinceEpoch(s.until)) : 'لحد ما تلغيه';
    Widget col3(String a, String b, CrossAxisAlignment al) => Column(crossAxisAlignment: al, children: [Text(a, style: TextStyle(fontSize: 14, color: col)), const SizedBox(height: 2), Text(b, style: TextStyle(fontSize: 15, color: col, fontWeight: FontWeight.w700))]);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: base.withValues(alpha: .18), borderRadius: BorderRadius.circular(24), border: Border.all(color: base.withValues(alpha: .35))),
      child: Column(children: [
        SizedBox(
          height: 22,
          child: Stack(alignment: Alignment.center, children: [
            Container(height: 4, decoration: BoxDecoration(color: col.withValues(alpha: .6), borderRadius: BorderRadius.circular(3))),
            Align(alignment: AlignmentDirectional.centerStart, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: col, shape: BoxShape.circle))),
            Container(width: 22, height: 22, decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle, border: Border.all(color: col, width: 4))),
            Align(alignment: AlignmentDirectional.centerEnd, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: col.withValues(alpha: .6), shape: BoxShape.circle))),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          col3('بدأ', enDate(s.firstDate), CrossAxisAlignment.start),
          col3(s.inTrial ? 'نهاية التجربة' : (s.overdue ? 'متأخر' : 'التجديد الجاي'), s.overdue ? 'Overdue ${s.overdueDays}d' : (next == null ? '—' : enDate(next)), CrossAxisAlignment.center),
          col3(s.until > 0 ? 'بيخلص' : 'مفيش نهاية', end, CrossAxisAlignment.end),
        ]),
        const SizedBox(height: 12),
        Text(s.inTrial ? 'بعد التجربة هيتسحب ${_m(s.amt)} يوم ${next == null ? '' : enDate(next)}' : (s.overdue ? 'متأخر ${s.overdueDays} يوم  ·  سجّل دفعة عشان يظهر ميعاد التجديد' : (next == null ? 'مفيش تجديد جاي' : '${_m(s.amt)}  ·  بيتجدد بعد ${s.daysLeft} يوم')), style: TextStyle(fontSize: 15, color: (s.inTrial || s.overdue) ? kRed : col, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Live(b: (c) {
      final s = _cur();
      if (s == null) return const SizedBox.shrink();
      final accName = repo.account(s.acc)?.name ?? repo.account(repo.defaultAcc)?.name ?? '—';
      return SheetFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _SubLogo(name: s.name, svc: s.svc, img: s.img, color: _colorOf(s), size: 58),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text('${_m(s.amt)}  ·  ${cycleName(s.cyc)}', style: TextStyle(fontSize: 15, color: p.ink2))])),
              Tap(onTap: () => _menu(s), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.more_horiz_rounded, color: p.ink2))),
            ]),
            const SizedBox(height: 14),
            _timeline(p, s),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('المدفوع لحد دلوقتي', style: TextStyle(fontSize: 15, color: p.ink2)), Text(_m(s.paid), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('بتدفع بإيه', style: TextStyle(fontSize: 15, color: p.ink2)), Text(accName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 14),
            if (s.state == 'active') bigButton(p, 'سجّل دفعة', kBlue, () => _payPanel(s)),
            const SizedBox(height: 12),
            Tap(
              onTap: () => setState(() => openLog = !openLog),
              child: Row(children: [
                Expanded(child: Text('سجل الدفعات', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                Text('${s.pays.length}', style: TextStyle(color: p.ink2)),
                const SizedBox(width: 4),
                AnimatedRotation(turns: openLog ? .5 : 0, duration: const Duration(milliseconds: 220), child: Icon(Icons.expand_more_rounded, color: p.ink2)),
              ]),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: openLog
                  ? Column(children: [
                      if (s.pays.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text('لسه مفيش دفعات.', style: TextStyle(color: p.ink2))),
                      for (final x in s.pays)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${enDate(DateTime.fromMillisecondsSinceEpoch(x.ts))}${x.acc.isEmpty ? '' : '  ·  ${repo.account(x.acc)?.name ?? ''}'}', style: TextStyle(color: p.ink2)), Text(_m(x.amt), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))])),
                    ])
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      );
    });
  }
}
