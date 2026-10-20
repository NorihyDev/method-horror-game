"""Repaints MakeHuman's female_casualsuit01 (CC0) into a plain off-white
T-shirt with a small grey METHOD wordmark and dark-wash jeans. Used for
Miky.

python -I make_tee.py <female_casualsuit01_diffuse.png> <out.png> [cloth hex] [jeans tint hex]
"""
import sys

import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
CLOTH = sys.argv[3].lstrip("#") if len(sys.argv) > 3 else "eeece6"
JEANS = sys.argv[4].lstrip("#") if len(sys.argv) > 4 else "39404d"
ROTATE = -90
cloth_rgb = np.array([int(CLOTH[i : i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)
jeans_rgb = np.array([int(JEANS[i : i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)

pic = Image.open(SRC).convert("RGB")
img = np.asarray(pic).astype(np.float32)
h, w, _ = img.shape
r, g, b = img[..., 0], img[..., 1], img[..., 2]
lum = img.mean(axis=-1)
bg = img[8, 8]
cloth = np.abs(img - bg).sum(axis=-1) > 30
# Pieces: every connected island of cloth. The shirt's islands (two body
# panels, two sleeves) carry the orange trim; the jeans' do not.
labels, count = ndimage.label(cloth)
orange = (r > 170) & (g > 70) & (g < 190) & (b < 110)
shirt_ids = [i for i in range(1, count + 1) if (orange & (labels == i)).any()]
# Worn-out flecks and the old logo's grey ring are close to the background
# colour: fill those holes so they turn white with the rest.
shirt = ndimage.binary_fill_holes(ndimage.binary_closing(np.isin(labels, shirt_ids), iterations=2))
jeans = cloth & ~shirt
# Clear blue cloth only, a few pixels in from any logo, trim or seam edge
# (their blended edge pixels would print as light outlines).
blue = ndimage.binary_erosion(shirt & (b > r + 30) & ~orange & (lum < 140), iterations=4)


def blur_of(values, mask, radius):
    # Average over the mask only, so the logo and trims do not bleed in.
    num = ndimage.gaussian_filter(values * mask, radius)
    den = ndimage.gaussian_filter(mask.astype(np.float32), radius)
    return num / np.maximum(den, 1e-3)


detail = np.where(blue, np.clip(lum - blur_of(lum, blue, 5), -5, 2), 0.0)
# Fill the logo and trim gaps with the weave's local average, then shade.
out = img.copy()
# Flat colour: the outfit's normal map already gives the folds and weave
# under light (copying the old texture's shading printed its wear spots and
# the old logo's outline onto the white).
base = np.broadcast_to(cloth_rgb, img.shape).copy()
out[shirt] = base[shirt]
# Ribbed collar a touch greyer.
collar = shirt & (b > r + 30) & (lum < 72)
out[collar] = (cloth_rgb * 0.93)[None, :]
# Jeans: keep the denim's light and dark, in a dark wash.
k = (lum / 150.0)[..., None]
out[jeans] = np.clip(jeans_rgb[None, :] * k[jeans] * 1.1, 0, 255)
res = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
# Small wordmark on the front panel, where the old logo was.
# The panels lie on their side in the UV layout (neck to the right), so the
# word is drawn on its own and turned to stand upright on the chest.
sx, sy = w / 768.0, h / 768.0
try:
    font = ImageFont.truetype("arialbd.ttf", int(22 * sx))
except OSError:
    font = ImageFont.load_default()
probe = ImageDraw.Draw(res)
tw = int(probe.textlength("METHOD", font=font)) + 8
th = int(30 * sy)
word = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
ImageDraw.Draw(word).text((4, 2), "METHOD", fill=(92, 92, 96, 255), font=font)
word = word.rotate(ROTATE, expand=True)
cx, cy = 612 * sx, 168 * sy
res.paste(word, (int(cx - word.width / 2), int(cy - word.height / 2)), word)
res.save(OUT)
print("tee", res.size)
