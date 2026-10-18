"""Repaints MakeHuman's male_casualsuit04 (CC0) into a black esports jersey
with neon-green trim and a METHOD badge, and turns the jeans into dark
trousers. Keeps the cloth's shading so it still reads as fabric.

python -I make_jersey.py <male_casualsuit04_diffuse.png> <out.png> [classic|pro]
"classic" (Tsila): round green collar, badge, straight side flashes.
"pro" (Mianja): V-neck, METHOD on both shoulders, grey slashes, sleeve "M",
green cuffs and a larger badge, like the team's match jersey.
"baseball" (Paulino, Nox, Ninja): teal pinstriped button-up with grey
piping, a METHOD wordmark and a Madagascar flag on the sleeve.
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
STYLE = sys.argv[3] if len(sys.argv) > 3 else "classic"
# Optional 4th argument: accent colour as hex (default METHOD green), and
# "+flag" in the style adds a Madagascar flag on the left sleeve.
ACCENT = sys.argv[4].lstrip("#") if len(sys.argv) > 4 else "1eeb6e"
FLAG = STYLE.endswith("+flag")
STYLE = STYLE.replace("+flag", "")
GREEN = np.array([int(ACCENT[i : i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)
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
if STYLE == "baseball":
    TEAL = np.array([38, 168, 186], dtype=np.float32)
    PIPE = np.array([118, 124, 130], dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    # The old front logo becomes plain cloth.
    logo = ((xx - 428 * w / 768) ** 2 + (yy - 128 * h / 768) ** 2) < (54 * w / 768) ** 2
    cloth = (shirt | (logo & top)) & ~empty
    shade = np.clip(lum / max(lum[shirt & ~empty].mean(), 1.0), 0.75, 1.2)
    shade[logo] = 1.0
    out[cloth] = TEAL * shade[cloth][:, None]
    # Pinstripes: thin darker verticals across the shirt panels.
    stripe = (xx % int(w / 768 * 10)) < max(1, int(w / 768))
    out[cloth & stripe] = TEAL * 0.72
    out[orange & ~logo] = PIPE
    out[collar] = PIPE
pic = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

# Front panel (the one that carried the logo): badge, wordmark, side flashes.
d = ImageDraw.Draw(pic)
if STYLE == "baseball":
    sx, sy = w / 768.0, h / 768.0
    try:
        bold = ImageFont.truetype("arialbd.ttf", int(22 * sx))
        small = ImageFont.truetype("arialbd.ttf", int(12 * sx))
    except OSError:
        bold = small = ImageFont.load_default()
    pipe = (118, 124, 130)
    navy = (22, 34, 62)
    # Cover the old logo with plain teal, then the button placket and V.
    d.line([(400 * sx, 34 * sy), (428 * sx, 78 * sy), (456 * sx, 34 * sy)], fill=pipe, width=int(5 * sx))
    d.line([(428 * sx, 78 * sy), (428 * sx, 290 * sy)], fill=pipe, width=int(5 * sx))
    for k in range(5):
        y = (100 + k * 40) * sy
        d.ellipse([422 * sx, y - 5 * sy, 434 * sx, y + 5 * sy], fill=pipe)
    # Wordmark on the wearer's left chest, emblem on the right.
    d.text((470 * sx, 128 * sy), "METHOD", font=bold, fill=navy, anchor="mm")
    d.text((470 * sx, 150 * sy), "HORROR", font=small, fill=(240, 244, 246), anchor="mm")
    d.rectangle([362 * sx, 104 * sy, 400 * sx, 142 * sy], outline=navy, width=int(4 * sx))
    d.text((381 * sx, 123 * sy), "M", font=bold, fill=navy, anchor="mm")
    d.text((128 * sx, 70 * sy), "METHOD", font=bold, fill=navy, anchor="mm")
    # Madagascar flag on one sleeve.
    fx, fy = 630 * sx, 120 * sy
    d.rectangle([fx, fy, fx + 14 * sx, fy + 24 * sy], fill=(245, 245, 245))
    d.rectangle([fx + 14 * sx, fy, fx + 38 * sx, fy + 12 * sy], fill=(200, 30, 40))
    d.rectangle([fx + 14 * sx, fy + 12 * sy, fx + 38 * sx, fy + 24 * sy], fill=(0, 125, 60))
    pic.save(OUT)
    print("jersey", pic.size, STYLE)
    sys.exit(0)
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
if STYLE == "pro":
    G = tuple(GREEN.astype(int))
    GREY = (64, 66, 68)
    # Grey slashes inside the side flashes, front and back.
    for panel_x in (128, 428):
        px = panel_x * sx
        for side in (-1, 1):
            for k in range(3):
                x0 = px + side * (62 - k * 13) * sx
                y0 = (150 + k * 22) * sy
                poly = [(x0, y0), (x0 + side * 7 * sx, y0), (x0 - side * 18 * sx, y0 + 60 * sy), (x0 - side * 25 * sx, y0 + 60 * sy)]
                d.polygon(poly, fill=GREY)
    # V-neck: a green V under the collar, black inside.
    vx, vy = 428 * sx, 30 * sy
    d.polygon([(vx - 26 * sx, vy), (vx + 26 * sx, vy), (vx, vy + 42 * sy)], fill=G)
    d.polygon([(vx - 16 * sx, vy), (vx + 16 * sx, vy), (vx, vy + 27 * sy)], fill=(16, 18, 17))
    # METHOD along both front shoulders, with piping under it.
    for ox in (-66, 66):
        d.text(((428 + ox) * sx, 62 * sy), "METHOD", font=small, fill=G, anchor="mm")
        d.line([((428 + ox - 30) * sx, 72 * sy), ((428 + ox + 30) * sx, 72 * sy)], fill=G, width=int(3 * sx))
    # Bigger badge plate.
    d.rectangle([cx - 70 * sx, cy - 46 * sy, cx + 70 * sx, cy + 52 * sy], outline=G, width=int(6 * sx))
    # Sleeves: the M mark and a green cuff band.
    big = font
    for sy0 in (130, 245):
        d.text((640 * sx, sy0 * sy), "M", font=big, fill=G, anchor="mm")
if FLAG:
    fx, fy = 630 * sx, 160 * sy
    d.rectangle([fx, fy, fx + 14 * sx, fy + 24 * sy], fill=(245, 245, 245))
    d.rectangle([fx + 14 * sx, fy, fx + 38 * sx, fy + 12 * sy], fill=(200, 30, 40))
    d.rectangle([fx + 14 * sx, fy + 12 * sy, fx + 38 * sx, fy + 24 * sy], fill=(0, 125, 60))
pic.save(OUT)
print("jersey", pic.size)
