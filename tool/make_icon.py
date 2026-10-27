# يولّد أيقونة التطبيق: محفظة + موجات واي فاي على تدرّج أزرق.
from PIL import Image, ImageDraw, ImageChops
import math, os
S = 2048  # رسم بدقة عالية ثم تصغير
def gradient(size, c1, c2):
    import numpy as np
    y, x = np.mgrid[0:size, 0:size].astype('float32')
    t = ((x + y) / (2.0 * (size - 1)))            # قطري من أعلى-يسار إلى أسفل-يمين
    t = np.clip(t * 1.1 - 0.05, 0, 1)[..., None]
    c1 = np.array(c1, dtype='float32'); c2 = np.array(c2, dtype='float32')
    arr = (c1 * (1 - t) + c2 * t).astype('uint8')
    return Image.fromarray(arr, 'RGB')

def glyph(size):
    """محفظة بيضاء + موجات واي فاي فوقها (دفع/تتبّع لاسلكي) — داخل المنطقة الآمنة 66%."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W = (255, 255, 255, 255)
    cx = size / 2
    # جسم المحفظة
    x0, x1 = size * 0.24, size * 0.76
    y0, y1 = size * 0.44, size * 0.74
    d.rounded_rectangle([x0, y0, x1, y1], radius=size * 0.06, fill=W)
    # فلاب المحفظة (حز بلون شفاف) + زر القفل
    flap = [x1 - size * 0.20, (y0 + y1) / 2 - size * 0.06, x1 + size * 0.02, (y0 + y1) / 2 + size * 0.06]
    d.rounded_rectangle(flap, radius=size * 0.03, fill=(0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle(flap, radius=size * 0.03, outline=None)
    d.ellipse([x1 - size * 0.105, (y0 + y1) / 2 - size * 0.025, x1 - size * 0.055, (y0 + y1) / 2 + size * 0.025], fill=(40, 120, 230, 255))
    # موجات واي فاي فوق المحفظة
    wy = size * 0.40
    for i, r in enumerate((size * 0.05, size * 0.11, size * 0.17)):
        w = int(size * 0.032)
        d.arc([cx - r, wy - r, cx + r, wy + r], start=225, end=315, fill=W, width=w)
    d.ellipse([cx - size * 0.022, wy - size * 0.022, cx + size * 0.022, wy + size * 0.022], fill=W)
    return im

def rounded(im, r):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius=r, fill=255)
    out = im.convert('RGBA'); out.putalpha(m); return out

bg = gradient(S, (64, 156, 255), (10, 52, 190)).convert('RGBA')   # فاتح → أزرق عميق
g = glyph(S)
full = Image.alpha_composite(bg, g)
# ظل خفيف للشكل
sh = Image.new('RGBA', (S, S), (0, 0, 0, 0)); sh.paste((0, 20, 90, 70), mask=g.split()[3]); 
from PIL import ImageFilter
sh = sh.filter(ImageFilter.GaussianBlur(S * 0.012)).transform((S, S), Image.AFFINE, (1, 0, 0, 0, 1, -S * 0.008))
full = Image.alpha_composite(Image.alpha_composite(bg, sh), g)
os.makedirs('assets/brand', exist_ok=True)
full.resize((1024, 1024), Image.LANCZOS).convert('RGB').save('assets/brand/app_icon.png')
g.resize((1024, 1024), Image.LANCZOS).save('assets/brand/app_icon_fg.png')
rounded(full.resize((512, 512), Image.LANCZOS), 112).save('assets/brand/app_icon_preview.png')
print('ok')
