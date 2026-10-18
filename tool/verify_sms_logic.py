#!/usr/bin/env python3
"""يتحقق من منطق محرك الرسائل عبر نسخة Python مطابقة للخوارزمية في lib/sms (القواعد تُقرأ مباشرة من ملفات Dart).
هذا ليس تشغيلًا لـ Dart؛ تشغيل الاختبارات الحقيقي يتم بـ `flutter test` في GitHub Actions."""
import json, re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
rules = (root/'lib/sms/sms_rules.dart').read_text(encoding='utf8')

def lit(block):
    return [a or b for a, b in re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", block)]
def list_of(name):
    m = re.search(r'const List<String> %s = \[(.*?)\];' % name, rules, re.S); return lit(m.group(1))
words = {}
for m in re.finditer(r"'(\w+)': \[(.*?)\],\n", re.search(r'kDefaultWords = \{(.*?)\n\};', rules, re.S).group(1)+"\n", re.S):
    words[m.group(1)] = lit(m.group(2))
excluded, weak, promo = list_of('kDefaultExcluded'), list_of('kWeakExcluded'), list_of('kPromoWords')
hints = dict(re.findall(r"'([^']+)': '([^']+)'", re.search(r'kSenderHints = \{(.*?)\};', rules, re.S).group(1)))
kinds = ['purchase','debit','atm','xferOut','xferIn','refund']
dirs = {'purchase':'out','debit':'out','atm':'out','xferOut':'out','xferIn':'in','refund':'in'}
prio = ['refund','atm','xferOut','xferIn','purchase','debit']
CUR = r'(?:egp|usd|eur|sar|aed|kwd|qar|gbp|l\.?e\.?|ج\.?م\.?|جنيه|دولار|يورو|\$|€|£)'
NUM = r'(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?)'
AR, FA = '٠١٢٣٤٥٦٧٨٩', '۰۱۲۳۴۵۶۷۸۹'
def digits(s):
    o = []
    for ch in s:
        i = AR.find(ch); i = FA.find(ch) if i < 0 else i
        o.append(str(i) if i >= 0 else ('.' if ch=='٫' else ',' if ch=='٬' else ch))
    return ''.join(o)
def norm(s):
    t = digits(s).lower(); t = re.sub('[\u064B-\u0652\u0640]', '', t)
    t = re.sub('[أإآٱ]', 'ا', t).replace('ى','ي').replace('ة','ه'); return re.sub(r'\s+',' ',t).strip()
def has(h, n):
    if not n: return False
    latin = bool(re.match(r'[a-z0-9]', n[0]) or re.match(r'[a-z0-9]', n[-1]))
    return bool(re.search(r'(?<![a-z0-9])'+re.escape(n)+r'(?![a-z0-9])', h)) if latin else n in h
def minor(raw):
    s = digits(raw).replace(' ','')
    if not re.fullmatch(r'[0-9][0-9.,]*', s): return None
    lc, ld = s.rfind(','), s.rfind('.'); frac = ''
    if lc>=0 and ld>=0:
        i = max(lc, ld); ip = re.sub(r'[.,]','',s[:i]); frac = s[i+1:]
    elif lc>=0 or ld>=0:
        i = lc if lc>=0 else ld; after = s[i+1:]
        if len(re.findall(r'[.,]', s))>1 or len(after)==3: ip = re.sub(r'[.,]','',s)
        else: ip, frac = s[:i], after
    else: ip = s
    if len(frac)>2: return None
    return int(ip)*100 + (int(frac.ljust(2,'0')) if frac else 0)
def curcode(tok):
    t = tok.lower().replace('.','')
    return {'egp':'EGP','le':'EGP','جم':'EGP','جنيه':'EGP','usd':'USD','$':'USD','دولار':'USD','eur':'EUR','€':'EUR','يورو':'EUR','gbp':'GBP','£':'GBP'}.get(t, t.upper())
BAL = re.compile(r'(balance|available|avail\b|bal\b|رصيد|الرصيد|المتاح|المتبقي|limit|حد )')
FEE = re.compile(r'(fees?\b|commission|رسوم|عموله|مصاريف)')
def amounts(t):
    out, seen = [], set()
    def add(start, n, c):
        m = minor(n)
        if not m or m <= 0 or start in seen: return
        seen.add(start); b = t[max(0,start-32):start]
        out.append((m, curcode(c) if c else 'EGP', start, bool(BAL.search(b)), bool(FEE.search(b))))
    for m in re.finditer(r'(?<![a-z])(%s)\s*[:.]?\s*%s' % (CUR, NUM), t, re.I): add(m.start(), m.group(2), m.group(1))
    for m in re.finditer(r'%s\s*(%s)(?![a-z])' % (NUM, CUR), t, re.I): add(m.start(), m.group(1), m.group(2))
    for m in re.finditer(r'(?:amount|amt|مبلغ|بمبلغ|قيمه|بقيمه)\s*[:=]?\s*%s' % NUM, t, re.I):
        if any(abs(a[2]-m.start())<18 for a in out): continue
        add(m.start(), m.group(1), '')
    return sorted(out, key=lambda a: a[2])
def last4(t):
    a = re.search(r'(?:ending(?:\s+in|\s+with)?|last\s*(?:4|four)(?:\s*digits)?|(?:تنتهي|ينتهي|منتهيه?)\s*ب|اخر\s*4\s*ارقام)\s*[:#]?\s*(\d{4})\b', t)
    if a: return a.group(1)
    b = re.search(r'(?:[x*•·]\s*){2,}(\d{4})\b', t); return b.group(1) if b else ''
def parse(sender, body, cfg):
    t = norm(body)
    if not t: return ('reject','empty')
    for w in excluded:
        if has(t, norm(w)):
            return ('reject', 'otp' if re.search(r'otp|code|رمز|كود|passcode|share|تشارك|الرقم السري|كلمه', norm(w)) else 'failed')
    wk = any(has(t, norm(w)) for w in weak)
    if any(has(t, norm(w)) for w in promo) and (re.search(r'(https?://|www\.)', t) or re.search(r'\d+\s*%', t)): return ('reject','ad')
    matched = {}
    for k in kinds:
        best = 0
        for w in words.get(k, []):
            nw = norm(w)
            if nw and has(t, nw) and len(nw) > best: best = len(nw)
        if best: matched[k] = best
    if 'xferIn' in matched and 'xferOut' in matched and matched['xferIn'] > matched['xferOut']: del matched['xferOut']
    am = amounts(t); cands = [a for a in am if not a[3] and not a[4]]
    distinct = {(a[0], a[1]) for a in cands}
    s = norm(sender); known = any(k in s for k in hints)
    trusted = known or any(x and norm(x) in s for x in cfg.get('trusted', []))
    numeric = bool(re.fullmatch(r'[+0-9 ]{3,}', sender.strip()))
    if wk and (not matched or not cands): return ('reject','otp')
    if not matched and not cands: return ('reject','not_financial')
    if not trusted and numeric: return ('reject','personal_sender')
    if not matched: return ('review','unclear_kind') if trusted else ('reject','not_financial')
    if not cands: return ('review','no_amount') if trusted else ('reject','not_financial')
    ds = {dirs[k] for k in matched}
    if 'refund' in matched: kind = 'refund'
    elif len(ds) > 1: return ('review','mixed_direction')
    else: kind = next(k for k in prio if k in matched)
    a = cands[0]; l4 = last4(t)
    bank = next((v for k, v in hints.items() if k in s), sender.strip())
    acc = cfg['cardAcc'].get(l4) if l4 else None
    acc = acc or cfg.get('bankAcc', {}).get(bank, '')
    def res(v, r): return (v, r, kind, a[0], a[1], l4)
    if not trusted: return res('review','unknown_sender')
    if len(distinct) > 1: return res('review','multiple_amounts')
    if not acc: return res('review','no_account')
    return res('accept','ok')
cfg = {'cardAcc': {'7748': 'acc1'}, 'bankAcc': {}, 'trusted': []}
cases = json.loads((root/'test/sms_vectors.json').read_text(encoding='utf8'))['cases']
bad = 0
for c in cases:
    r = parse(c['s'], c['b'], cfg); ok = r[0] == c['v']
    if 'r' in c: ok &= r[1] == c['r']
    if 'k' in c: ok &= len(r) > 2 and r[2] == c['k']
    if 'm' in c: ok &= len(r) > 3 and r[3] == c['m']
    if 'c' in c: ok &= len(r) > 4 and r[4] == c['c']
    if 'l4' in c: ok &= len(r) > 5 and r[5] == c['l4']
    print(('PASS' if ok else 'FAIL'), c['n'], '' if ok else f'-> got {r}')
    bad += (not ok)
print(f'\n{len(cases)-bad}/{len(cases)} passed'); sys.exit(1 if bad else 0)
