#!/usr/bin/env python3
"""يولّد أيقونات التطبيق البديلة من تصميم cashu_10A_colors.svg (قوس + نقطة على مربع مدوّر).

المخرجات:
  • android_overlay/res/…  : لكل أيقونة بديلة (٩) — adaptive XML + vector + PNG احتياطي لـ API < 26 + ألوان.
  • assets/brand/app_icon*.png : الأيقونة الأساسية (Navy) لـ flutter_launcher_icons.
شغّله مرة واحدة بعد تعديل الألوان (الناتج متسجّل في الريبو، فمش مطلوب في الـ CI).
الألوان لازم تتطابق مع lib/ui/app_icons.dart.
"""
from PIL import Image, ImageDraw
import pathlib

# id: (bg, arc, dot)
VARIANTS = {
    'navy':    ('#0F1B3D', '#FFFFFF', '#2EE6A6'),
    'black':   ('#0A0A0A', '#FFFFFF', '#2EE6A6'),
    'blue':    ('#2F6BE0', '#FFFFFF', '#2EE6A6'),
    'mint':    ('#2EE6A6', '#0F1B3D', '#FFFFFF'),
    'green':   ('#0B3D2E', '#FFFFFF', '#2EE6A6'),
    'gold':    ('#0F1B3D', '#FFFFFF', '#FFC83D'),
    'mintarc': ('#0F1B3D', '#2EE6A6', '#FFFFFF'),
    'light':   ('#E8EFFF', '#0F1B3D', '#2EE6A6'),
    'royal':   ('#1E3A8A', '#FFFFFF', '#2EE6A6'),
    'violet':  ('#6C4CF1', '#FFFFFF', '#2EE6A6'),
}
DENS = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / 'android_overlay' / 'res'
SS = 4  # supersampling


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def draw_glyph(img, arc, dot, f):
    """يرسم القوس والنقطة؛ f(x, y) يحوّل إحداثيات SVG (٩٦×٩٦) إلى بكسل."""
    d = ImageDraw.Draw(img)
    (x0, y0), (x1, y1) = f(48 - 32, 64 - 32), f(48 + 32, 64 + 32)
    w = round(f(12, 0)[0] - f(0, 0)[0])
    d.arc([x0, y0, x1, y1], 180, 360, fill=rgb(arc), width=w)
    (a0, b0), (a1, b1) = f(48 - 7, 66 - 7), f(48 + 7, 66 + 7)
    d.ellipse([a0, b0, a1, b1], fill=rgb(dot))


def full_icon(size, bg, arc, dot):
    """الأيقونة الكاملة (مربع مدوّر rx=26/96) بنفس تصميم الـ SVG."""
    S = size * SS
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 26 / 96, fill=rgb(bg))
    k = S / 96
    draw_glyph(img, arc, dot, lambda x, y: (x * k, y * k))
    return img.resize((size, size), Image.LANCZOS)


def fg_icon(size, arc, dot):
    """الطبقة الأمامية للأيقونة التكيّفية (لوحة ١٠٨، منطقة آمنة ٦٦) — نفس تحويل الـ vector drawable."""
    S = size * SS
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    k = S / 108
    sc = 0.90
    draw_glyph(img, arc, dot, lambda x, y: ((54 + sc * (x - 48)) * k, (54 + sc * (y - 52.5)) * k))
    return img.resize((size, size), Image.LANCZOS)


def vector_xml(arc, dot):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:pivotX="48"
        android:pivotY="52.5"
        android:scaleX="0.90"
        android:scaleY="0.90"
        android:translateX="6"
        android:translateY="1.5">
        <path
            android:fillColor="#00000000"
            android:pathData="M22,64 A26,26 0 0 1 74,64"
            android:strokeColor="{arc}"
            android:strokeWidth="12" />
        <path
            android:fillColor="{dot}"
            android:pathData="M41,66 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0" />
    </group>
</vector>
'''


def adaptive_xml(i):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/cashu_ic_bg_{i}" />
    <foreground android:drawable="@drawable/cashu_ic_fg_{i}" />
</adaptive-icon>
'''


def main():
    colors = ['<?xml version="1.0" encoding="utf-8"?>', '<resources>']
    for i, (bg, arc, dot) in VARIANTS.items():
        if i == 'navy':
            continue  # الأساسية بتتولّد بـ flutter_launcher_icons (@mipmap/ic_launcher)
        colors.append(f'    <color name="cashu_ic_bg_{i}">{bg}</color>')
        (RES / 'drawable').mkdir(parents=True, exist_ok=True)
        (RES / 'drawable' / f'cashu_ic_fg_{i}.xml').write_text(vector_xml(arc, dot), encoding='utf8')
        (RES / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
        (RES / 'mipmap-anydpi-v26' / f'ic_launcher_{i}.xml').write_text(adaptive_xml(i), encoding='utf8')
        for dn, px in DENS.items():
            d = RES / f'mipmap-{dn}'
            d.mkdir(parents=True, exist_ok=True)
            full_icon(px, bg, arc, dot).save(d / f'ic_launcher_{i}.png')
    colors.append('</resources>')
    (RES / 'values').mkdir(parents=True, exist_ok=True)
    (RES / 'values' / 'cashu_icon_colors.xml').write_text('\n'.join(colors) + '\n', encoding='utf8')

    bg, arc, dot = VARIANTS['navy']
    brand = ROOT / 'assets' / 'brand'
    full_icon(1024, bg, arc, dot).save(brand / 'app_icon.png')
    fg_icon(1024, arc, dot).save(brand / 'app_icon_fg.png')
    full_icon(512, bg, arc, dot).save(brand / 'app_icon_preview.png')
    print('done')


if __name__ == '__main__':
    main()
