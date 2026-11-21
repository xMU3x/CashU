#!/usr/bin/env python3
"""يولّد ملفات Lottie الأصلية لـ CashU (تصميم أصلي، بدون أي أصول خارجية).
التشغيل: python3 tool/gen_lottie.py  → assets/lottie/{success_check,empty_state,loading_dots}.json
المدة الفعلية بتتحكم فيها CashUMotion من الكود (controller)، فـ fr/op هنا مجرد تقسيم إطارات."""
import json, os

FR = 60
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'lottie')

def ez(o=(0.2, 0.0), i=(0.0, 1.0), n=1):
    # نفس منحنى CashUMotion.curve = Cubic(.2, 0, 0, 1)
    return {'o': {'x': [o[0]] * n, 'y': [o[1]] * n}, 'i': {'x': [i[0]] * n, 'y': [i[1]] * n}}

def kf(frames, n=1, ease=None):
    """frames: [(t, value)] → keyframes (value list)."""
    out = []
    for idx, (t, v) in enumerate(frames):
        k = {'t': t, 's': v if isinstance(v, list) else [v]}
        if idx < len(frames) - 1:
            k.update(ease or ez(n=n))
        out.append(k)
    return {'a': 1, 'k': out}

def static(v):
    return {'a': 0, 'k': v}

def transform(p=(60, 60), s=None, o=None, r=None):
    return {
        'o': o or static(100),
        'r': r or static(0),
        'p': static(list(p) + [0]) if not isinstance(p, dict) else p,
        'a': static([0, 0, 0]),
        's': s or static([100, 100, 100]),
    }

def layer(ind, name, shapes, ks, op):
    return {'ddd': 0, 'ind': ind, 'ty': 4, 'nm': name, 'sr': 1, 'ks': ks, 'ao': 0,
            'shapes': shapes, 'ip': 0, 'op': op, 'st': 0, 'bm': 0}

def grp(name, items):
    return {'ty': 'gr', 'nm': name, 'it': items + [{'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]),
                                                     's': static([100, 100]), 'r': static(0), 'o': static(100)}]}

def fill(c, o=100):
    return {'ty': 'fl', 'c': static(c + [1]), 'o': static(o), 'r': 1}

def stroke(c, w, o=100):
    return {'ty': 'st', 'c': static(c + [1]), 'o': static(o), 'w': static(w), 'lc': 2, 'lj': 2}

def ellipse(w, h, p=(0, 0)):
    return {'ty': 'el', 'p': static(list(p)), 's': static([w, h])}

def wrap(name, op, w, h, layers):
    return {'v': '5.7.0', 'fr': FR, 'ip': 0, 'op': op, 'w': w, 'h': h, 'nm': name, 'ddd': 0, 'assets': [], 'layers': layers}

GREEN = [0.188, 0.82, 0.345]
WHITE = [1, 1, 1]

# ───────── ١) شيك نجاح (٤٢ إطار ≈ ٧٠٠ms) ─────────
def success():
    op = 42
    pop = {'a': 1, 'k': [
        {'t': 0, 's': [0, 0, 100], 'o': {'x': [0.2] * 3, 'y': [0] * 3}, 'i': {'x': [0.3] * 3, 'y': [1.5] * 3}},  # ارتداد واحد خفيف (≈ pop)
        {'t': 14, 's': [100, 100, 100]},
    ]}
    fade_out = {'a': 1, 'k': [
        {'t': 0, 's': [100], 'o': {'x': [0] * 1, 'y': [0] * 1}, 'i': {'x': [1], 'y': [1]}},
        {'t': 32, 's': [100], 'o': {'x': [0.3], 'y': [0]}, 'i': {'x': [1], 'y': [1]}},
        {'t': 41, 's': [0]},
    ]}
    disc = layer(2, 'disc', [grp('disc', [ellipse(88, 88), fill(GREEN)])], transform(s=pop, o=fade_out), op)
    check_path = {'ty': 'sh', 'ks': static({'c': False, 'v': [[-20, 2], [-6, 16], [22, -14]],
                                            'i': [[0, 0]] * 3, 'o': [[0, 0]] * 3})}
    trim = {'ty': 'tm', 's': static(0), 'e': kf([(12, 0), (30, 100)]), 'o': static(0), 'm': 1}
    check = layer(1, 'check', [grp('check', [check_path, trim, stroke(WHITE, 8)])], transform(o=fade_out), op)
    return wrap('success_check', op, 120, 120, [check, disc])

# ───────── ٢) حالة فاضية (حلقة هادية ٩٦ إطار ≈ ١٦٠٠ms) ─────────
def empty():
    op = 96
    half = op // 2
    TINT = [0.55, 0.58, 0.64]  # بيتلوّن من الكود (ValueDelegate.color) حسب ثيم التطبيق
    layers = []
    # حلقتين نابضتين بينهم نص دورة: كل حلقة بتكبر وتتلاشى، والتانية بتبدأ من منتصف الدورة (الحلقة بلا قفزات).
    ring_a_s = kf([(0, [60, 60, 100]), (op, [118, 118, 100])], n=3)
    ring_a_o = kf([(0, 55), (op, 0)])
    ring_b_s = kf([(0, [89, 89, 100]), (half, [118, 118, 100]), (half + 1, [60, 60, 100]), (op, [89, 89, 100])], n=3)
    ring_b_o = kf([(0, 28), (half, 0), (half + 1, 55), (op, 28)])
    for idx, (sc, opc) in enumerate(((ring_a_s, ring_a_o), (ring_b_s, ring_b_o))):
        layers.append(layer(10 + idx, f'ring{idx}', [grp('ring', [ellipse(84, 84), stroke(TINT, 3, 100)])], transform(s=sc, o=opc), op))
    # نقطتين بتدوروا حوالين الدايرة (دوران كامل في الدورة = حلقة بلا نتوءات)
    def orbit(ind, name, r, size, phase):
        rot = kf([(0, phase), (op, phase + 360)], ease=ez((0.0, 0.0), (1.0, 1.0)))
        dot = grp('dot', [ellipse(size, size, (0, -r)), fill(TINT, 70)])
        return layer(ind, name, [dot], transform(r=rot), op)
    layers += [orbit(3, 'orbitA', 46, 7, 0), orbit(4, 'orbitB', 46, 5, 180)]
    # دايرة القاعدة الثابتة (خلفية ناعمة لمكان الأيقونة)
    layers.append(layer(5, 'base', [grp('base', [ellipse(68, 68), fill(TINT, 14)])], transform(), op))
    return wrap('empty_state', op, 120, 120, layers)

# ───────── ٣) لودينج خفيف (٣ نقط بتنبض بالتتابع، حلقة ٥٤ إطار ≈ ٩٠٠ms) ─────────
def loading():
    op = 54
    BLUE = [0.2, 0.5, 1.0]  # بيتلوّن من الكود بلون التطبيق
    layers = []
    for idx, x in enumerate((-18, 0, 18)):
        d = idx * 6
        # نبضة: تصغير ← تكبير ← رجوع، متأخرة d إطار، بحلقة كاملة op
        frames = [(0, [70, 70, 100]), (d + 9, [70, 70, 100]), (d + 21, [130, 130, 100]), (d + 33, [70, 70, 100]), (op, [70, 70, 100])]
        frames = [(t, v) for t, v in frames if t <= op]
        frames = sorted({t: v for t, v in frames}.items())
        a = kf(frames, n=3, ease=ez((0.3, 0.0), (0.2, 1.0), 3))
        o = kf([(t, [{70: 45, 130: 100}[v[0]]]) for t, v in frames], ease=ez())
        layers.append(layer(idx + 1, f'dot{idx}', [grp('dot', [ellipse(14, 14), fill(BLUE)])],
                            {'o': o, 'r': static(0), 'p': static([60 + x, 60, 0]), 'a': static([0, 0, 0]), 's': a}, op))
    return wrap('loading_dots', op, 120, 120, layers)

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, data in (('success_check', success()), ('empty_state', empty()), ('loading_dots', loading())):
        with open(os.path.join(OUT, name + '.json'), 'w', encoding='utf-8') as f:
            json.dump(data, f, separators=(',', ':'))
        print('wrote', name)

if __name__ == '__main__':
    main()
