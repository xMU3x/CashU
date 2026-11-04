import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين دائم للصور البعيدة (أيقونات الخدمات والحسابات): الصورة بتتحمّل مرة واحدة، تتحفظ محليًا،
/// وبعد كده بتشتغل أوفلاين من غير ما تتحمّل تاني في كل مرة تفتح فيها الصفحة.
/// التخزين في SharedPreferences بمفاتيح منفصلة (imgcache_*) فمبتتزامنش مع السحابة.
class ImgCache {
  ImgCache._();

  static const _pre = 'imgcache_v1_';
  static const _doneKey = 'imgcache_prefetch_done_v1';
  static const _maxBytes = 1500 * 1024;
  static final Map<String, Uint8List> _mem = {};
  static final Map<String, Future<Uint8List?>> _pending = {};

  /// هاش FNV-1a ثابت بين مرات التشغيل (String.hashCode مش مضمون ثباته).
  static String _h(String s) {
    var h = 0xcbf29ce484222325;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return h.toRadixString(16);
  }

  /// نسخة الذاكرة (فورية) لو الصورة اتحمّلت قبل كده في الجلسة دي.
  static Uint8List? peek(String url) => _mem[url];

  /// الصورة من الذاكرة ← من التخزين المحلي ← من الشبكة (وتتحفظ). null لو فشلت ومفيش نسخة محفوظة.
  static Future<Uint8List?> get(String url) {
    final m = _mem[url];
    if (m != null) return Future.value(m);
    return _pending[url] ??= _load(url).whenComplete(() => _pending.remove(url));
  }

  static Future<Uint8List?> _load(String url) async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      final raw = p.getString('$_pre${_h(url)}');
      if (raw != null) {
        final j = jsonDecode(raw) as Map;
        if (j['u'] == url) {
          final b = base64Decode(j['b'] as String);
          _mem[url] = b;
          return b;
        }
      }
    } catch (_) {}
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty && r.bodyBytes.length <= _maxBytes) {
        _mem[url] = r.bodyBytes;
        try {
          await p?.setString('$_pre${_h(url)}', jsonEncode({'u': url, 'b': base64Encode(r.bodyBytes)}));
        } catch (_) {}
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// تحميل مسبق لقائمة روابط في الخلفية (مرة واحدة لكل تثبيت)، بحد أقصى ٤ طلبات متوازية.
  static Future<void> prefetchOnce(List<String> urls) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_doneKey) == true) {
        // مفيش تحميل شبكة؛ بس نسخّن الذاكرة من التخزين المحلي بهدوء.
        return;
      }
      var ok = 0;
      for (var i = 0; i < urls.length; i += 4) {
        final chunk = urls.skip(i).take(4);
        final res = await Future.wait(chunk.map(get));
        ok += res.where((e) => e != null).length;
      }
      // لو أغلبها اتحمّل نعتبر التحميل المسبق تم؛ غير كده نحاول المرة الجاية.
      if (ok >= (urls.length * .8).floor()) await p.setBool(_doneKey, true);
    } catch (_) {}
  }
}

/// صورة بعيدة بتتحمّل مرة وتتحفظ محليًا (انظر [ImgCache]). [fallback] يظهر أثناء التحميل أو لو مفيش صورة.
class CachedImg extends StatefulWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  final Widget fallback;
  const CachedImg(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, required this.fallback});
  @override
  State<CachedImg> createState() => _CachedImgState();
}

class _CachedImgState extends State<CachedImg> {
  Uint8List? _b;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CachedImg old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    _b = ImgCache.peek(url);
    if (_b != null) return;
    ImgCache.get(url).then((v) {
      if (mounted && widget.url == url && v != null) setState(() => _b = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) return widget.fallback;
    return Image.memory(b, width: widget.width, height: widget.height, fit: widget.fit, gaplessPlayback: true, errorBuilder: (c, e, s) => widget.fallback);
  }
}
