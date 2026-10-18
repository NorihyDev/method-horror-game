"""Levels a face photo for projection: rotates it so the eyes are level,
flattens transparency onto grey, and prints the landmarks in the levelled
image, ready for character.json ("photo").

python -I prepare_photo.py <photo> <work_dir> eye_r_x eye_r_y eye_l_x eye_l_y mouth_x mouth_y chin_x chin_y
(eye_r = the person's right eye, on the left of the picture). Writes
<work_dir>/face_src.png, which stays out of the repository.
"""
import json
import math
import os
import sys

from PIL import Image

src, work = sys.argv[1], sys.argv[2]
v = [float(x) for x in sys.argv[3:11]]
er, el, mouth, chin = (v[0], v[1]), (v[2], v[3]), (v[4], v[5]), (v[6], v[7])
im = Image.open(src).convert("RGBA")
flat = Image.new("RGBA", im.size, (128, 128, 128, 255))
flat.alpha_composite(im)
mid = ((er[0] + el[0]) / 2, (er[1] + el[1]) / 2)
angle = math.degrees(math.atan2(el[1] - er[1], el[0] - er[0]))
level = flat.convert("RGB").rotate(angle, center=mid, resample=Image.BICUBIC, fillcolor=(128, 128, 128))


def turn(p):
    a = math.radians(-angle)
    x, y = p[0] - mid[0], p[1] - mid[1]
    return [round(mid[0] + x * math.cos(a) - y * math.sin(a), 1), round(mid[1] + x * math.sin(a) + y * math.cos(a), 1)]


os.makedirs(work, exist_ok=True)
level.save(os.path.join(work, "face_src.png"))
pts = {"eye_r": turn(er), "eye_l": turn(el), "mouth": turn(mouth), "chin_y": turn(chin)[1]}
print(json.dumps(pts))
print("rotated %.1f degrees" % angle)
