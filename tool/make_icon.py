# يولّد أيقونة التطبيق: حرف C على شكل محفظة بداخلها كروت بسيطة، على تدرّج أزرق.
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
    """حرف C على شكل محفظة (جسم المحفظة مفتوح من اليمين) بداخله كروت بسيطة متدرّجة — داخل المنطقة الآمنة 66%."""
    from PIL import ImageChops
    S = size
    W = (255, 255, 255, 255)
    # جسم المحفظة (حرف C): مستطيل مدوّر ناقص فتحة مفتوحة ناحية اليمين
    body = Image.new('L', (S, S), 0)
    ImageDraw.Draw(body).rounded_rectangle([S * 0.20, S * 0.28, S * 0.74, S * 0.72], radius=S * 0.10, fill=255)
    cut = Image.new('L', (S, S), 0)
    ImageDraw.Draw(cut).rounded_rectangle([S * 0.33, S * 0.385, S * 0.90, S * 0.615], radius=S * 0.05, fill=255)
    c_mask = ImageChops.subtract(body, cut)
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    im.paste(Image.new('RGBA', (S, S), W), mask=c_mask)
    d = ImageDraw.Draw(im)
    # ثلاث كروت بسيطة داخل الفتحة (الأمامي أبيض بشريط، اللي وراه أزرق فاتح أغمق تدريجيًا)
    ys = [(0.405, (118, 178, 255, 255)), (0.44, (178, 214, 255, 255)), (0.475, (255, 255, 255, 255))]
    for y, col in ys:
        d.rounded_rectangle([S * 0.40, S * y, S * 0.80, S * (y + 0.095)], radius=S * 0.028, fill=col)
    # شريط الكارت الأمامي
    d.rounded_rectangle([S * 0.44, S * 0.505, S * 0.62, S * 0.52], radius=S * 0.007, fill=(40, 120, 230, 255))
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
