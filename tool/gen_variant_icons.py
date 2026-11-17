#!/usr/bin/env python3
"""يولّد كل أيقونات التطبيق من تصميم tool/source/cashu_10A_colors_ios27_flat.svg (المصدر الوحيد للحقيقة).

التصميم (فلات): مربع مدوّر بتدرّج رأسي + فينييت أبيض شعاعي خفيف من أعلى، قوس سميك بلون واحد وأطراف دائرية، نقطة بلون واحد.

المخرجات:
  • assets/brand/app_icon*.png          : الأيقونة الأساسية (الأسود) لـ flutter_launcher_icons (legacy + background + foreground + mono).
  • android_overlay/res/…               : لكل أيقونة (١٠ بما فيها الأسود والكحلي): adaptive XML + طبقتا PNG (خلفية/أمامية) + PNG احتياطي لـ API < 26.
  • android_overlay/res/drawable-nodpi/cashu_ic_mono.png : طبقة monochrome مشتركة (الأيقونات المتجاوبة مع ثيم أندرويد ١٣+).
  • lib/ui/app_icons_data.dart          : نفس الألوان لرسم الأيقونات داخل التطبيق (CustomPainter) — بدون ملفات صور.
شغّله بعد أي تعديل في الـ SVG: python3 tool/gen_variant_icons.py   (المتطلبات: pillow, numpy).
"""
import math
import pathlib
import re

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'tool' / 'source' / 'cashu_10A_colors_ios27_flat.svg'
RES = ROOT / 'android_overlay' / 'res'
BRAND = ROOT / 'assets' / 'brand'

PRIMARY = 'black'  # الأيقونة الأساسية (الافتراضية) للتطبيق
IDS = ['navy', 'black', 'blue', 'mint', 'green', 'gold', 'cream', 'graphite', 'royal', 'violet']  # نفس ترتيب الـ SVG
LABELS = {
    'navy': 'كحلي', 'black': 'أسود (الأساسية)', 'blue': 'أزرق', 'mint': 'نعناعي', 'green': 'أخضر داكن',
    'gold': 'كحلي وذهبي', 'cream': 'كحلي وكريمي', 'graphite': 'جرافيت', 'royal': 'أزرق ملكي', 'violet': 'بنفسجي',
}
DENS = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ADAPT_PX = 432  # لوحة adaptive ١٠٨dp × ٤
ADAPT_SCALE = 0.90  # حجم الرسم داخل المنطقة الآمنة


# ───────────────────────── قراءة الـ SVG ─────────────────────────
def hexrgb(h):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def stops(group, gid):
    m = re.search(r'<(?:linear|radial)Gradient id="%s"[^>]*>(.*?)</(?:linear|radial)Gradient>' % gid, group, re.S)
    out = []
    for st in re.finditer(r'<stop([^>]*)/>', m.group(1)):
        a = st.group(1)
        off = float(re.search(r'offset="([\d.]*)"', a).group(1) or 0)
        col = hexrgb(re.search(r'stop-color="(#\w+)"', a).group(1))
        op = re.search(r'stop-opacity="([\d.]+)"', a)
        out.append((off, col, float(op.group(1)) if op else 1.0))
    return out


def parse():
    s = re.sub(r'<metadata>.*?</metadata>', '', SRC.read_text(encoding='utf8'), flags=re.S)
    groups = re.split(r'(?=<g transform="translate\()', s)[1:]
    assert len(groups) == len(IDS), len(groups)
    V = {}
    for n, i in enumerate(IDS):
        g = groups[n]
        bg = stops(g, f'i{n}bg')
        vg = stops(g, f'i{n}vg')
        arc = re.search(r'<path d="M22 64 A26 26 0 0 1 74 64"[^>]*stroke="(#\w+)"', g).group(1)
        dot = re.search(r'<circle cx="48" cy="66" r="7" fill="(#\w+)"', g).group(1)
        V[i] = dict(bg0=bg[0][1], bg1=bg[1][1], vig=vg[0][2], arc=hexrgb(arc), dot=hexrgb(dot))
    return V


# ───────────────────────── الرسم (numpy + PIL) ─────────────────────────
def interp(stops_, t):
    """t مصفوفة ← ألوان (…،٣)."""
    xs = [s[0] for s in stops_]
    return np.stack([np.interp(t, xs, [s[1][c] for s in stops_]) for c in range(3)], -1)


def over(dst, rgb, a):
    a = a[..., None]
    dst[..., :3] = rgb * a + dst[..., :3] * (1 - a)
    dst[..., 3:] = a + dst[..., 3:] * (1 - a)


def mask(S, fn):
    im = Image.new('L', (S, S), 0)
    fn(ImageDraw.Draw(im))
    return np.asarray(im, dtype=np.float32) / 255


def glyph_masks(S, k, ox, oy):
    """أقنعة عناصر الرسم؛ (x,y) بوحدات الـ SVG (٩٦) ← بكسل: ox + k·x."""
    P = lambda x, y: (ox + k * x, oy + k * y)

    def arc(d, cx, cy, r, w, color=255):
        (x0, y0), (x1, y1) = P(cx - r - w / 2, cy - r - w / 2), P(cx + r + w / 2, cy + r + w / 2)
        d.arc([x0, y0, x1, y1], 180, 360, fill=color, width=max(1, round(k * w)))
        for ex in (cx - r, cx + r):  # أطراف دائرية
            (a0, b0), (a1, b1) = P(ex - w / 2, cy - w / 2), P(ex + w / 2, cy + w / 2)
            d.ellipse([a0, b0, a1, b1], fill=color)

    def dot(d):
        (a0, b0), (a1, b1) = P(48 - 7, 66 - 7), P(48 + 7, 66 + 7)
        d.ellipse([a0, b0, a1, b1], fill=255)

    return {
        'arc': mask(S, lambda d: arc(d, 48, 64, 26, 12)),
        'dot': mask(S, dot),
    }


def paint_glyph(img, v, S, k, ox, oy):
    m = glyph_masks(S, k, ox, oy)
    over(img, np.array(v['arc'], np.float32), m['arc'])
    over(img, np.array(v['dot'], np.float32), m['dot'])


def paint_bg(img, v, S, rr_mask=None):
    """خلفية متدرّجة رأسية + فينييت أبيض شعاعي (مركز ٤٨,٠ ونصف قطر ٨٦٫٤، يخفت لـ ٠ عند ٦٠٪) — زي الـ SVG؛ rr_mask للقص بمربع مدوّر."""
    Y, X = (np.mgrid[0:S, 0:S].astype(np.float32) + .5) / S * 96
    m = np.ones((S, S), np.float32) if rr_mask is None else rr_mask
    over(img, interp([(0, v['bg0'], 1), (1, v['bg1'], 1)], Y / 96), m)
    r = np.hypot(X - 48, Y) / (.9 * 96)
    over(img, np.ones(3, np.float32), m * np.clip(1 - r / .6, 0, 1) * v['vig'])


def to_image(arr, size, ss):
    a = arr.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
    al = a[..., 3:]
    rgb = np.where(al > 1e-6, a[..., :3] / np.maximum(al, 1e-6), 0)
    out = np.concatenate([rgb, al], -1)
    return Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8), 'RGBA')


def ss_for(size):
    return 4 if size <= 256 else 2


def full_icon(size, v):
    ss = ss_for(size)
    S = size * ss
    img = np.zeros((S, S, 4), np.float32)
    rr = mask(S, lambda d: d.rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 26 / 96, fill=255))
    paint_bg(img, v, S, rr)
    paint_glyph(img, v, S, S / 96, 0, 0)
    return to_image(img, size, ss)


def adaptive_bg(size, v):
    ss = ss_for(size)
    S = size * ss
    img = np.zeros((S, S, 4), np.float32)
    paint_bg(img, v, S)
    return to_image(img, size, ss)


def adaptive_fg(size, v, mono=False):
    ss = ss_for(size)
    S = size * ss
    img = np.zeros((S, S, 4), np.float32)
    k = S / 108 * ADAPT_SCALE
    ox = S / 108 * (54 - ADAPT_SCALE * 48)
    oy = S / 108 * (54 - ADAPT_SCALE * 52.5)
    if mono:
        m = glyph_masks(S, k, ox, oy)
        over(img, np.ones(3, np.float32), np.maximum(m['arc'], m['dot']))
    else:
        paint_glyph(img, v, S, k, ox, oy)
    return to_image(img, size, ss)


# ───────────────────────── الملفات ─────────────────────────
def adaptive_xml(i):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/cashu_ic_bg_{i}" />
    <foreground android:drawable="@drawable/cashu_ic_fg_{i}" />
    <monochrome android:drawable="@drawable/cashu_ic_mono" />
</adaptive-icon>
'''


def hexs(c):
    return '0x%02X%02X%02X' % tuple(round(x * 255) for x in c)


DART_HEAD = '''// ملف مولَّد — لا تعدّله يدويًا. المصدر: tool/source/cashu_10A_colors_ios27_flat.svg ← python3 tool/gen_variant_icons.py
import 'package:flutter/painting.dart';

/// ألوان أيقونة التطبيق (بنفس بارامترات الـ SVG الفلات): خلفية متدرّجة، فينييت علوي خفيف، قوس بلون واحد، نقطة بلون واحد.
class AppIconVariant {
  final String id;
  final String label;
  final Color bg0, bg1;
  final double vig;
  final Color arc, dot;
  const AppIconVariant(this.id, this.label, this.bg0, this.bg1, this.vig, this.arc, this.dot);
}

/// الأيقونة الأساسية (الافتراضية). لازم تتطابق مع android:enabled="true" في المانيفست ومع defaultIcon في MainActivity.kt.
const kPrimaryAppIconId = '%s';

const kAppIcons = <AppIconVariant>[
'''


def dart_data(V):
    rows = []
    for i in IDS:
        v = V[i]
        c = lambda k: f'Color(0xFF{hexs(v[k])[2:]})'
        rows.append(f"  AppIconVariant('{i}', '{LABELS[i]}', {c('bg0')}, {c('bg1')}, {v['vig']:g}, {c('arc')}, {c('dot')}),")
    return (DART_HEAD % PRIMARY) + '\n'.join(rows) + '\n];\n'


def main():
    V = parse()
    # تنظيف مخرجات النسخة السابقة (كل ic_launcher_* وطبقات cashu_ic_* + vector/ألوان قديمة)
    stale = list((RES / 'drawable').glob('cashu_ic_fg_*.xml')) + [RES / 'values' / 'cashu_icon_colors.xml']
    stale += list(RES.glob('mipmap-*/ic_launcher_*.*')) + list((RES / 'drawable-nodpi').glob('cashu_ic_*.png'))
    for old in stale:
        if old.exists():
            old.unlink()
    (RES / 'drawable-nodpi').mkdir(parents=True, exist_ok=True)
    (RES / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
    for i in IDS:
        v = V[i]
        adaptive_bg(ADAPT_PX, v).save(RES / 'drawable-nodpi' / f'cashu_ic_bg_{i}.png', optimize=True)
        adaptive_fg(ADAPT_PX, v).save(RES / 'drawable-nodpi' / f'cashu_ic_fg_{i}.png', optimize=True)
        (RES / 'mipmap-anydpi-v26' / f'ic_launcher_{i}.xml').write_text(adaptive_xml(i), encoding='utf8')
        for dn, px in DENS.items():
            d = RES / f'mipmap-{dn}'
            d.mkdir(parents=True, exist_ok=True)
            full_icon(px, v).save(d / f'ic_launcher_{i}.png', optimize=True)
    adaptive_fg(ADAPT_PX, V[PRIMARY], mono=True).save(RES / 'drawable-nodpi' / 'cashu_ic_mono.png', optimize=True)

    n = V[PRIMARY]
    BRAND.mkdir(parents=True, exist_ok=True)
    full_icon(1024, n).save(BRAND / 'app_icon.png', optimize=True)
    adaptive_bg(1024, n).save(BRAND / 'app_icon_bg.png', optimize=True)
    adaptive_fg(1024, n).save(BRAND / 'app_icon_fg.png', optimize=True)
    adaptive_fg(1024, n, mono=True).save(BRAND / 'app_icon_mono.png', optimize=True)
    full_icon(512, n).save(BRAND / 'app_icon_preview.png', optimize=True)

    (ROOT / 'lib' / 'ui' / 'app_icons_data.dart').write_text(dart_data(V), encoding='utf8')
    print('done')


if __name__ == '__main__':
    main()
