"""Repaints MakeHuman's male_casualsuit04 (CC0) into a black esports jersey
with neon-green trim and a METHOD badge, and turns the jeans into dark
trousers. Keeps the cloth's shading so it still reads as fabric.

python -I make_jersey.py <male_casualsuit04_diffuse.png> <out.png>
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
GREEN = np.array([30, 235, 110], dtype=np.float32)
img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
h, w, _ = img.shape
r, g, b = img[..., 0], img[..., 1], img[..., 2]
lum = img.mean(axis=-1)
top = np.zeros((h, w), dtype=bool)
top[: int(h * 0.405)] = True
# Fabric shading relative to its local average, for a little texture.
detail = (lum - lum[top].mean()) * 0.25

orange = (r > 170) & (g > 70) & (g < 190) & (b < 110)
shirt = top & (b - r > 45) & (b > 100)
out = img.copy()
black = np.stack([16 + detail, 18 + detail, 17 + detail], axis=-1)
out[shirt] = black[shirt]
out[orange] = GREEN * np.clip(lum[orange] / 200.0, 0.75, 1.1)[:, None]
# The darker blue collar ribbing turns green like the trim.
collar = shirt & (r < 25)
out[collar] = GREEN * 0.85
# Trousers: the denim goes near-black, keeping its folds.
jeans = (~top) & (b > r + 10)
dark = np.stack([lum * 0.22, lum * 0.22, lum * 0.24], axis=-1)
out[jeans] = dark[jeans]
# Unused texture space (flat slate) goes black so nothing bleeds into seams.
empty = (np.abs(img - np.array([62, 96, 117])).sum(axis=-1) < 6)
out[empty] = 10
pic = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

# Front panel (the one that carried the logo): badge, wordmark, side flashes.
d = ImageDraw.Draw(pic)
sx, sy = w / 768.0, h / 768.0
cx, cy = 428 * sx, 128 * sy
d.ellipse([cx - 52 * sx, cy - 52 * sy, cx + 52 * sx, cy + 52 * sy], fill=(16, 18, 17))
try:
    font = ImageFont.truetype("arialbd.ttf", int(30 * sx))
    small = ImageFont.truetype("arialbd.ttf", int(14 * sx))
except OSError:
    font = small = ImageFont.load_default()
box = [cx - 62 * sx, cy - 40 * sy, cx + 62 * sx, cy + 44 * sy]
d.rectangle(box, outline=tuple(GREEN.astype(int)), width=int(4 * sx))
d.text((cx, cy - 10 * sy), "M", font=font, fill=tuple(GREEN.astype(int)), anchor="mm")
d.text((cx, cy + 26 * sy), "METHOD", font=small, fill=tuple(GREEN.astype(int)), anchor="mm")
for panel_x in (128, 428):
    px = panel_x * sx
    for side in (-1, 1):
        x0 = px + side * 92 * sx
        poly = [
            (x0, 120 * sy),
            (x0 + side * 14 * sx, 120 * sy),
            (x0 - side * 40 * sx, 285 * sy),
            (x0 - side * 54 * sx, 285 * sy),
        ]
        d.polygon(poly, fill=tuple(GREEN.astype(int)))
# Sleeve cuffs and the wordmark across the back shoulders.
d.text((128 * sx, 60 * sy), "METHOD", font=small, fill=tuple(GREEN.astype(int)), anchor="mm")
pic.save(OUT)
print("jersey", pic.size)
