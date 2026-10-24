# يولّد أيقونة CashU: حرف C كحلقة بيضاء (عملة) + سهم صغير صاعد (تتبّع مصاريف) على تدرّج أزرق.
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
    """الشكل الأبيض فقط على خلفية شفافة (داخل المنطقة الآمنة 66%)."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = size / 2
    R = size * 0.27        # نصف قطر الحلقة
    w = size * 0.085       # سُمك الحلقة
    box = [cx - R, cy - R, cx + R, cy + R]
    # حرف C: قوس مفتوح من اليمين (من -40° إلى +40° مفتوح)
    d.arc(box, start=40, end=320, fill=(255, 255, 255, 255), width=int(w))
    # أطراف دائرية للقوس
    for ang in (40, 320):
        a = math.radians(ang)
        r_mid = R - w / 2
        x = cx + r_mid * math.cos(a); y = cy + r_mid * math.sin(a)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=(255, 255, 255, 255))
    # سهم صاعد صغير داخل الفتحة (تتبّع/نمو)
    ax = cx + R * 0.62; ay = cy
    s = size * 0.075
    d.polygon([(ax - s, ay + s * 0.9), (ax + s * 0.2, ay - s * 0.9), (ax + s * 1.3, ay + s * 0.9)], fill=(255, 255, 255, 235))
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
