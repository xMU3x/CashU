import 'sms_rules.dart';
import 'sms_text.dart';

enum SmsVerdict { accept, review, reject }

/// إعدادات المحرك (كلها محلية، يملكها المستخدم).
class SmsConfig {
  final Map<String, List<String>> words;
  final List<String> excluded;
  final Set<String> trustedSenders; // نص صغير يُطابق جزءًا من اسم المرسل
  final Map<String, String> cardAcc; // last4 -> accountId
  final Map<String, String> bankAcc; // bankKey -> accountId (حساب افتراضي للمرسل)
  const SmsConfig({
    this.words = kDefaultWords,
    this.excluded = kDefaultExcluded,
    this.trustedSenders = const {},
    this.cardAcc = const {},
    this.bankAcc = const {},
  });
}

class ParsedSms {
  final SmsVerdict verdict;
  final String reason; // رمز السبب (otp, failed, ad, not_financial, ...)
  final String kind; // أحد kSmsKinds أو ''
  final int minor; // وحدات صغرى (قرش)
  final String currency;
  final String last4, merchant, ref, sender, bankKey, accId;
  final int ts;
  const ParsedSms({
    required this.verdict,
    required this.reason,
    this.kind = '',
    this.minor = 0,
    this.currency = 'EGP',
    this.last4 = '',
    this.merchant = '',
    this.ref = '',
    this.sender = '',
    this.bankKey = '',
    this.accId = '',
    this.ts = 0,
  });
  bool get isIncome => kSmsDir[kind] == 'in';
  double get amount => minor / 100.0;
}

class _Amt {
  final int minor, at;
  final String cur;
  final bool balance, fee;
  _Amt(this.minor, this.cur, this.at, this.balance, this.fee);
}

final RegExp _balCtx = RegExp(r'(balance|available|avail\b|bal\b|رصيد|الرصيد|المتاح|المتبقي|limit|حد )');
final RegExp _feeCtx = RegExp(r'(fees?\b|commission|رسوم|عموله|مصاريف)');
final RegExp _url = RegExp(r'(https?://|www\.)');
final RegExp _pct = RegExp(r'\d+\s*%');

/// "بنك" المرسل: اسم معروف من القائمة أو الاسم كما هو.
String bankKeyOf(String sender) {
  final s = normalizeForMatch(sender);
  for (final e in kSenderHints.entries) {
    if (s.contains(e.key)) return e.value;
  }
  return sender.trim();
}

bool _numericSender(String s) => RegExp(r'^[+0-9 ]{3,}$').hasMatch(s.trim());

List<_Amt> _findAmounts(String t) {
  final out = <_Amt>[];
  final seen = <int>{};
  void add(Match m, String numStr, String curTok) {
    final minor = parseMinor(numStr);
    if (minor == null || minor <= 0) return;
    if (!seen.add(m.start)) return;
    final before = t.substring(m.start < 32 ? 0 : m.start - 32, m.start);
    out.add(_Amt(minor, curTok.isEmpty ? 'EGP' : curCodeOf(curTok), m.start, _balCtx.hasMatch(before), _feeCtx.hasMatch(before)));
  }

  final curFirst = RegExp('(?<![a-z])($kCurPattern)\\s*[:.]?\\s*$kNumPattern', caseSensitive: false);
  for (final m in curFirst.allMatches(t)) {
    add(m, m.group(2)!, m.group(1)!);
  }
  final numFirst = RegExp('$kNumPattern\\s*($kCurPattern)(?![a-z])', caseSensitive: false);
  for (final m in numFirst.allMatches(t)) {
    add(m, m.group(1)!, m.group(2)!);
  }
  final labeled = RegExp('(?:amount|amt|مبلغ|بمبلغ|قيمه|بقيمه)\\s*[:=]?\\s*$kNumPattern', caseSensitive: false);
  for (final m in labeled.allMatches(t)) {
    // لا نضيفه إن كان مغطّى بمطابقة عملة قريبة
    if (out.any((a) => (a.at - m.start).abs() < 18)) continue;
    add(m, m.group(1)!, '');
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

String _last4(String t) {
  final a = RegExp(r'(?:ending(?:\s+in|\s+with)?|last\s*(?:4|four)(?:\s*digits)?|(?:تنتهي|ينتهي|منتهيه?)\s*ب|اخر\s*4\s*ارقام)\s*[:#]?\s*(\d{4})\b').firstMatch(t);
  if (a != null) return a.group(1)!;
  final b = RegExp(r'(?:[x*•·]\s*){2,}(\d{4})\b').firstMatch(t);
  return b?.group(1) ?? '';
}

String _ref(String t) =>
    RegExp(r'(?:ref(?:erence)?|rrn|auth(?:orization)?|رقم المرجع|مرجع)\s*(?:no\.?|number|#)?\s*[:#]?\s*([a-z0-9]{5,20})', caseSensitive: false).firstMatch(t)?.group(1) ?? '';

String _merchant(String t) {
  final en = RegExp(r"(?:\bat|@)\s+([A-Za-z0-9][A-Za-z0-9 .&'*_/\-]{1,40}?)(?=\s+(?:on|using|with|card|ref|from|dated|date|balance|avail|for|egp|usd|le)\b|[,;\n]|\.\s|$)", caseSensitive: false).firstMatch(t);
  if (en != null) return _clean(en.group(1)!);
  final ar = RegExp(r'(?:لدى|عند|لصالح)\s+([^\s,.:;\d]+(?:\s+[^\s,.:;\d]+){0,2})').firstMatch(t);
  if (ar != null) return _clean(ar.group(1)!);
  return '';
}

String _clean(String s) {
  var x = s.trim().replaceAll(RegExp(r'[\s.\-*]+$'), '');
  if (x.length > 40) x = x.substring(0, 40);
  return x;
}

/// تاريخ من الرسالة (يوم/شهر/سنة أو سنة-شهر-يوم) أو null. [now] لمقارنة المعقولية.
int? _date(String t, int receivedMs) {
  int? build(int y, int mo, int d, String? h, String? mi) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    if (y < 100) y += 2000;
    final dt = DateTime(y, mo, d, int.tryParse(h ?? '') ?? 12, int.tryParse(mi ?? '') ?? 0);
    if (dt.month != mo) return null;
    return dt.millisecondsSinceEpoch;
  }

  int? v;
  final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:[ t](\d{1,2}):(\d{2}))?').firstMatch(t);
  if (iso != null) {
    v = build(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!), iso.group(4), iso.group(5));
  } else {
    final dm = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b(?:\D{1,6}(\d{1,2}):(\d{2}))?').firstMatch(t);
    if (dm != null) { v = build(int.parse(dm.group(3)!), int.parse(dm.group(2)!), int.parse(dm.group(1)!), dm.group(4), dm.group(5)); }
  }
  if (v == null) return null;
  const day = 86400000;
  if (v > receivedMs + day || v < receivedMs - 45 * day) return null; // تاريخ غير معقول => نستخدم وقت الاستلام
  return v;
}

ParsedSms _rej(String reason, String sender) => ParsedSms(verdict: SmsVerdict.reject, reason: reason, sender: sender);

/// المحرك الرئيسي: نص + مرسل + وقت الاستلام => قرار. لا آثار جانبية ولا شبكة.
ParsedSms parseSms(String sender, String body, int receivedMs, [SmsConfig cfg = const SmsConfig()]) {
  final t = normalizeForMatch(body);
  if (t.isEmpty) return _rej('empty', sender);

  // 1) استبعاد دائم: رموز تحقق / عمليات فاشلة
  for (final w in cfg.excluded) {
    if (containsWord(t, normalizeForMatch(w))) {
      final otp = RegExp(r'otp|code|رمز|كود|passcode|share|تشارك|الرقم السري|كلمه').hasMatch(normalizeForMatch(w));
      return _rej(otp ? 'otp' : 'failed', sender);
    }
  }
  final weak = kWeakExcluded.any((w) => containsWord(t, normalizeForMatch(w)));
  // 2) إعلانات
  final promo = kPromoWords.any((w) => containsWord(t, normalizeForMatch(w)));
  if (promo && (_url.hasMatch(t) || _pct.hasMatch(t))) { return _rej('ad', sender); }

  // 3) النوع
  final matched = <String, int>{};
  for (final k in kSmsKinds) {
    var best = 0;
    for (final w in (cfg.words[k] ?? const <String>[])) {
      final nw = normalizeForMatch(w);
      if (nw.isNotEmpty && containsWord(t, nw) && nw.length > best) { best = nw.length; }
    }
    if (best > 0) matched[k] = best;
  }
  // الأطول تطابقًا يُسقط الأقصر المحتوى فيه (تحويل وارد > تحويل)
  if (matched.containsKey('xferIn') && matched.containsKey('xferOut') && matched['xferIn']! > matched['xferOut']!) { matched.remove('xferOut'); }

  // 4) المبالغ
  final amts = _findAmounts(t);
  final cands = amts.where((a) => !a.balance && !a.fee).toList();
  final distinct = <String>{for (final a in cands) '${a.minor}|${a.cur}'};

  // 5) المرسل
  final sNorm = normalizeForMatch(sender);
  final knownBank = kSenderHints.keys.any((k) => sNorm.contains(k));
  final trusted = knownBank || cfg.trustedSenders.any((s) => s.isNotEmpty && sNorm.contains(normalizeForMatch(s)));
  final numeric = _numericSender(sender);

  if (weak && (matched.isEmpty || cands.isEmpty)) return _rej('otp', sender);
  if (matched.isEmpty && cands.isEmpty) return _rej('not_financial', sender);
  if (!trusted && numeric) return _rej('personal_sender', sender);
  if (matched.isEmpty) { return trusted ? _rev('unclear_kind', sender, t, receivedMs, cands.isEmpty ? null : cands.first) : _rej('not_financial', sender); }
  if (cands.isEmpty) { return trusted ? _rev('no_amount', sender, t, receivedMs, null) : _rej('not_financial', sender); }

  // اختيار النوع
  String kind;
  final dirs = <String>{for (final k in matched.keys) kSmsDir[k]!};
  if (matched.containsKey('refund')) {
    kind = 'refund';
  } else if (dirs.length > 1) {
    return _rev('mixed_direction', sender, t, receivedMs, cands.first);
  } else {
    kind = kSmsPriority.firstWhere(matched.containsKey);
  }

  final a = cands.first;
  final l4 = _last4(t);
  final bank = bankKeyOf(sender);
  final acc = (l4.isNotEmpty ? cfg.cardAcc[l4] : null) ?? cfg.bankAcc[bank] ?? '';
  final ts = _date(t, receivedMs) ?? receivedMs;

  ParsedSms mk(SmsVerdict v, String reason) => ParsedSms(
        verdict: v, reason: reason, kind: kind, minor: a.minor, currency: a.cur, last4: l4, merchant: _merchant(asciiDigits(body)),
        ref: _ref(t), sender: sender, bankKey: bank, accId: acc, ts: ts,
      );

  if (!trusted) return mk(SmsVerdict.review, 'unknown_sender');
  if (distinct.length > 1) return mk(SmsVerdict.review, 'multiple_amounts');
  if (acc.isEmpty) return mk(SmsVerdict.review, 'no_account');
  return mk(SmsVerdict.accept, 'ok');
}

ParsedSms _rev(String reason, String sender, String t, int ts, _Amt? a) => ParsedSms(
      verdict: SmsVerdict.review, reason: reason, minor: a?.minor ?? 0, currency: a?.cur ?? 'EGP', sender: sender, bankKey: bankKeyOf(sender), ts: ts, last4: _last4(t),
    );

/// مفتاح التكرار: بصمة النص + مفتاح دلالي (للرسائل المكررة بصياغة مختلفة).
String bodyFingerprint(String sender, String body) =>
    fingerprint('${normalizeForMatch(sender)}|${normalizeForMatch(body).replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '')}');

String semanticKey(ParsedSms p) => p.ref.isNotEmpty ? 'r|${p.bankKey}|${p.ref}' : 's|${p.bankKey}|${p.minor}|${p.kind}|${p.last4}';
