"""Gives a character the real person's head, built by KeenTools FaceBuilder
(installed in Blender) from one front photo.

blender -b <work>/base.blend --python fb_head.py -- <character_dir> <work_dir>

1. FaceBuilder detects the face in <work>/face_src.png, auto-pins it, solves
   the head shape and camera, and bakes the photo onto its own head UVs.
   Texels the photo never saw are filled from their surroundings.
2. That head is aligned to the MPFB body (similarity from the eyes, mouth
   and nose tip) and joins it at the neck, below the jersey collar. The
   MPFB head, eyeballs, brows and lashes are hidden or removed.
3. Hair, cap and glasses are refitted from the MPFB skull to the new one.
4. The head is skinned to the neck and head bones, so every clip still
   works.
Saves <work>/base.blend in place. Run face_bake.py afterwards with
"photo": {"strength": 0} so it only tints the body to match.
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from keentools.addon_config import fb_settings
from keentools.facebuilder.fbloader import FBLoader
from keentools.utils.coords import update_head_mesh_non_neutral
from keentools.utils.focal_length import configure_focal_mode_and_fixes
from keentools.utils.images import load_rgba

CHAR_DIR, WORK = sys.argv[sys.argv.index("--") + 1 :][:2]
CFG = json.load(open(os.path.join(CHAR_DIR, "character.json"), encoding="utf-8"))
NAME = CFG["name"]
PH = CFG["photo"]
FBC = CFG.get("facebuilder", {})
body = bpy.data.objects[NAME + ".body"]
arm = body.parent


def shaped(obj):
    states = [(m, m.show_viewport) for m in obj.modifiers]
    for m, _ in states:
        m.show_viewport = False
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    tmp = ev.to_mesh()
    out = np.array([tuple(obj.matrix_world @ v.co) for v in tmp.vertices])
    nrm = np.array([tuple((obj.matrix_world.to_3x3() @ v.normal).normalized()) for v in tmp.vertices])
    ev.to_mesh_clear()
    for m, was in states:
        m.show_viewport = was
    return out, nrm


def group_centre(pts, group, front=False):
    gi = body.vertex_groups[group].index
    idx = [v.index for v in body.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    sel = pts[idx]
    if front:
        sel = sel[sel[:, 1] < sel[:, 1].min() + 0.008]
    return sel.mean(axis=0)


def umeyama(a, b):
    """Similarity (s, R, t) with b ~ s R a + t."""
    ma, mb = a.mean(0), b.mean(0)
    ac, bc = a - ma, b - mb
    u, d, vt = np.linalg.svd(bc.T @ ac / len(a))
    sgn = np.eye(3)
    if np.linalg.det(u) * np.linalg.det(vt) < 0:
        sgn[2, 2] = -1
    r = u @ sgn @ vt
    s = np.trace(np.diag(d) @ sgn) / ac.var(0).sum()
    return s, r, mb - s * r @ ma


def push_pull_fill(rgba):
    """Fills texels with alpha 0 from their neighbours (coarse to fine)."""
    levels = []
    img, m = rgba[..., :3].copy(), (rgba[..., 3] > 0.5).astype(np.float32)
    while min(img.shape[:2]) > 1:
        levels.append((img, m))
        h, w = img.shape[0] // 2, img.shape[1] // 2
        wsum = m[: h * 2, : w * 2].reshape(h, 2, w, 2).sum(axis=(1, 3))
        csum = (img[: h * 2, : w * 2] * m[: h * 2, : w * 2, None]).reshape(h, 2, w, 2, 3).sum(axis=(1, 3))
        img = np.where(wsum[..., None] > 0, csum / np.maximum(wsum[..., None], 1e-6), 0.0)
        m = (wsum > 0).astype(np.float32)
    for fine, fm in reversed(levels):
        up = np.repeat(np.repeat(img, 2, axis=0), 2, axis=1)
        up = np.pad(up, ((0, fine.shape[0] - up.shape[0]), (0, fine.shape[1] - up.shape[1]), (0, 0)), mode="edge")
        img = np.where(fm[..., None] > 0, fine, up)
    return img


# --- 1. FaceBuilder: fit, camera, texture -----------------------------------------
bpy.ops.keentools_fb.add_head()
settings = fb_settings()
headnum = len(settings.heads) - 1
FBLoader.add_new_camera_with_image(headnum, os.path.join(WORK, "face_src.png"))
head = settings.get_head(headnum)
cam = head.get_camera(0)
fb = FBLoader.get_builder()
kid = cam.get_keyframe()
faces = list(fb.detect_faces(load_rgba(cam), fb.pixel_aspect_ratio(kid)))
assert faces, "FaceBuilder found no face"
configure_focal_mode_and_fixes(fb, head)
assert fb.detect_face_pose(kid, faces[int(FBC.get("face_index", 0))]), "FaceBuilder could not fit the face"
fb.remove_pins(kid)
fb.add_preset_pins_and_solve(kid)
update_head_mesh_non_neutral(fb, head)
FBLoader.update_camera_pins_count(headnum, 0)
FBLoader.update_all_camera_positions(headnum)
FBLoader.update_all_camera_focals(headnum)
FBLoader.update_head_camobj_focals(headnum)
FBLoader.save_fb_serial_and_image_pathes(headnum)
tw = th = int(FBC.get("texture", 2048))

fb_obj = head.headobj
fb_cam = cam.camobj
fb_pts = np.array([tuple(fb_obj.matrix_world @ v.co) for v in fb_obj.data.vertices])
fb_tris = [tuple(p.vertices) for p in fb_obj.data.polygons]

# --- 2. Align to the body ---------------------------------------------------------
pts, nrm = shaped(body)
eye_r = group_centre(pts, "joint-r-eye")
eye_l = group_centre(pts, "joint-l-eye")
lips = group_centre(pts, "lips", front=True)
eyes = (eye_r + eye_l) / 2
em = float(eyes[2] - lips[2])
iod = float(np.linalg.norm(eye_l - eye_r))
scene = bpy.context.scene
iw, ih = int(cam.cam_image.size[0]), int(cam.cam_image.size[1])
scene.render.resolution_x, scene.render.resolution_y = iw, ih
scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
frame = [fb_cam.matrix_world @ c for c in fb_cam.data.view_frame(scene=scene)]
origin = fb_cam.matrix_world.translation
bvh_fb = BVHTree.FromPolygons([Vector(p) for p in fb_pts], fb_tris)


def fb_point(x, y):
    tr, br, bl, tl = frame
    target = tl + (tr - tl) * (x / iw) + (bl - tl) * (y / ih)
    hit = bvh_fb.ray_cast(origin, (target - origin).normalized())
    assert hit[0] is not None, "landmark ray missed the FaceBuilder head"
    return np.array(tuple(hit[0]))


face = (np.abs(pts[:, 0] - eyes[0]) < 1.2 * iod) & (pts[:, 2] > lips[2]) & (pts[:, 2] < eyes[2]) & (nrm[:, 1] < -0.3)
nose_m = pts[face][np.argmin(pts[face][:, 1])]
f_er, f_el, f_mo = fb_point(*PH["eye_r"]), fb_point(*PH["eye_l"]), fb_point(*PH["mouth"])
band = fb_pts[(fb_pts[:, 2] < (f_er[2] + f_el[2]) / 2) & (fb_pts[:, 2] > f_mo[2])]
nose_f = band[np.argmin(band[:, 1])]
s, r, t = umeyama(
    np.array([eye_r + [0, -0.011, 0], eye_l + [0, -0.011, 0], lips, nose_m]), np.array([f_er, f_el, f_mo, nose_f])
)
s *= float(FBC.get("scale", 1.0)) ** -1
head_m = (1.0 / s) * (r.T @ (fb_pts - t).T).T
print("FB aligned: scale %.3f" % s)

# --- Texture: the photo on the front of the face, clean skin everywhere else -------------
def rasterize(size, attrs):
    """Interpolates per-vertex attributes (N x k) over the head's UV layout."""
    out = np.zeros((size, size, attrs.shape[1]), dtype=np.float32)
    cover = np.zeros((size, size), dtype=bool)
    uvd = fb_obj.data.uv_layers.active.data
    for poly in fb_obj.data.polygons:
        li = list(poly.loop_indices)
        vi = list(poly.vertices)
        for k in range(1, len(li) - 1):
            tri = [0, k, k + 1]
            uv3 = np.array([tuple(uvd[li[q]].uv) for q in tri]) * size
            a3 = attrs[[vi[q] for q in tri]]
            x0, y0 = np.floor(uv3.min(axis=0)).astype(int)
            x1, y1 = np.ceil(uv3.max(axis=0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a, b_, c = uv3
            den = (b_[1] - c[1]) * (a[0] - c[0]) + (c[0] - b_[0]) * (a[1] - c[1])
            if abs(den) < 1e-12:
                continue
            l1 = ((b_[1] - c[1]) * (gx - c[0]) + (c[0] - b_[0]) * (gy - c[1])) / den
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            l3 = 1 - l1 - l2
            inside = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
            val = l1[..., None] * a3[0] + l2[..., None] * a3[1] + l3[..., None] * a3[2]
            sub = out[y0 : y1 + 1, x0 : x1 + 1]
            sub[inside] = val[inside]
            cover[y0 : y1 + 1, x0 : x1 + 1] |= inside
    return out, cover


def resample(a, n, size):
    """Box-down to n x n, then bilinear back up to size (a soft blur)."""
    h, w = a.shape[:2]
    small = a.reshape(n, h // n, n, w // n, -1).mean(axis=(1, 3))
    ys = (np.arange(size[0]) + 0.5) * n / size[0] - 0.5
    xs = (np.arange(size[1]) + 0.5) * n / size[1] - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, n - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, n - 1)
    y1, x1 = np.clip(y0 + 1, 0, n - 1), np.clip(x0 + 1, 0, n - 1)
    fy, fx = np.clip(ys - y0, 0, 1)[:, None, None], np.clip(xs - x0, 0, 1)[None, :, None]
    top = small[y0][:, x0] * (1 - fx) + small[y0][:, x1] * fx
    bot = small[y1][:, x0] * (1 - fx) + small[y1][:, x1] * fx
    return top * (1 - fy) + bot * fy


from bpy_extras.object_utils import world_to_camera_view

f_eye_z = float(np.mean([head_m[np.argmin(np.linalg.norm(fb_pts - f_er, axis=1))][2],
                         head_m[np.argmin(np.linalg.norm(fb_pts - f_el, axis=1))][2]]))

photo = bpy.data.images.load(os.path.join(WORK, "face_src.png"))
pw_, ph_ = photo.size
pp = np.array(photo.pixels[:], dtype=np.float32).reshape(ph_, pw_, 4)[..., :3]  # rows bottom-up
cam_pos = np.array(tuple(fb_cam.matrix_world.translation))
fb_mesh = fb_obj.data
vn = np.array([tuple((fb_obj.matrix_world.to_3x3() @ v.normal).normalized()) for v in fb_mesh.vertices])
uvp = np.array([tuple(world_to_camera_view(scene, fb_cam, Vector(p)))[:2] for p in fb_pts])
facing = np.einsum("ij,ij->i", vn, (cam_pos - fb_pts) / np.linalg.norm(cam_pos - fb_pts, axis=1)[:, None])
z_body = head_m[:, 2]
attrs = np.column_stack([uvp, facing, z_body]).astype(np.float32)
R = tw
ras, cover = rasterize(R, attrs)
pu, pv, fac, zb = ras[..., 0], ras[..., 1], ras[..., 2], ras[..., 3]

# Photo-space face mask from the landmarks: brows to chin, cheek to cheek.
ex = (PH["eye_r"][0] + PH["eye_l"][0]) / 2.0
ey = (PH["eye_r"][1] + PH["eye_l"][1]) / 2.0
iod_px = PH["eye_l"][0] - PH["eye_r"][0]
em_px = PH["mouth"][1] - ey
top_y = ey - float(FBC.get("forehead", 1.0)) * em_px
bot_y = PH["chin_y"] + 0.15 * em_px
cy_px, ry_px = (top_y + bot_y) / 2.0, (bot_y - top_y) / 2.0
rx_px = float(FBC.get("width", 1.15)) * iod_px
X = pu * pw_
Y = (1.0 - pv) * ph_  # photo pixel row, top-down
dd = np.sqrt(((X - ex) / rx_px) ** 2 + ((Y - cy_px) / ry_px) ** 2)
mask = np.clip((1.0 - dd) / 0.18, 0.0, 1.0)
mask *= np.clip((fac - 0.15) / 0.3, 0.0, 1.0)


def sample(u, v):
    xs = np.clip(u * pw_ - 0.5, 0, pw_ - 1.001)
    ys = np.clip(v * ph_ - 0.5, 0, ph_ - 1.001)
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = (xs - x0)[..., None], (ys - y0)[..., None]
    return (
        pp[y0, x0] * (1 - fx) * (1 - fy)
        + pp[y0, x0 + 1] * fx * (1 - fy)
        + pp[y0 + 1, x0] * (1 - fx) * fy
        + pp[y0 + 1, x0 + 1] * fx * fy
    )


col = sample(pu, pv)
# Background: the photo's left and right edges at face height (the corners can
# hold the grey fill added when the photo was levelled).
_k = max(4, pw_ // 40)
_rows = slice(int(ph_ - (ey + em_px)), int(ph_ - (ey - em_px)))
_edge = np.concatenate([pp[_rows, :_k].reshape(-1, 3), pp[_rows, -_k:].reshape(-1, 3)])
_edge = _edge[np.abs(_edge - 0.5).sum(axis=-1) > 0.02]
_bg = np.median(_edge, axis=0) if len(_edge) else np.array([0.5, 0.5, 0.5])
# Also nothing from right next to the background: the photo's edge pixels
# are half background, half skin.
# Background = background-coloured pixels connected to the photo's border
# (dark eyes or hair inside the face are never background, whatever colour).
_like = np.abs(pp - _bg).sum(axis=-1) < 0.15
_like |= np.abs(pp - 0.5).sum(axis=-1) < 0.02  # grey fill from levelling
_bgc = np.zeros_like(_like)
_bgc[0, :], _bgc[-1, :], _bgc[:, 0], _bgc[:, -1] = _like[0, :], _like[-1, :], _like[:, 0], _like[:, -1]
for _ in range(2000):
    _grow = _bgc.copy()
    _grow[1:] |= _bgc[:-1]
    _grow[:-1] |= _bgc[1:]
    _grow[:, 1:] |= _bgc[:, :-1]
    _grow[:, :-1] |= _bgc[:, 1:]
    _grow &= _like
    if (_grow == _bgc).all():
        break
    _bgc = _grow
# A soft margin around it (edge pixels are half background).
_m = int(FBC.get("bg_margin", 6))
_soft = _bgc.astype(np.float32)
for _ in range(_m):
    _n = _soft.copy()
    _n[1:] = np.maximum(_n[1:], _soft[:-1])
    _n[:-1] = np.maximum(_n[:-1], _soft[1:])
    _n[:, 1:] = np.maximum(_n[:, 1:], _soft[:, :-1])
    _n[:, :-1] = np.maximum(_n[:, :-1], _soft[:, 1:])
    _soft = _soft * 0.0 + np.maximum(_soft, _n * 0.82)
_xs = np.clip((pu * pw_).astype(int), 0, pw_ - 1)
_ys = np.clip((pv * ph_).astype(int), 0, ph_ - 1)
mask *= 1.0 - _soft[_ys, _xs]
# Skin and hair colours from the photo itself.
def box(cx, cy, hw, hh):
    rows = slice(int(ph_ - (cy + hh)), int(ph_ - (cy - hh)))
    cols = slice(int(cx - hw), int(cx + hw))
    return pp[rows, cols].reshape(-1, 3)


cheeks = np.concatenate(
    [box(PH["eye_r"][0], ey + 0.55 * em_px, 0.12 * iod_px, 0.1 * em_px),
     box(PH["eye_l"][0], ey + 0.55 * em_px, 0.12 * iod_px, 0.1 * em_px)]
)
skin = np.median(cheeks, axis=0)
# Better: the colour right at the edge of the face patch, so there is no seam.
_ring = cover & (mask > 0.15) & (mask < 0.6)
if _ring.sum() > 200:
    skin = np.median(col[_ring], axis=0)
skin = skin * float(FBC.get("skin_scale", 1.0))
json.dump({"skin": [float(x) for x in skin]}, open(os.path.join(WORK, "skin_tone.json"), "w"))
# Above the brows, anything much darker than skin is hair: keep it off the face.
lum = col.mean(axis=-1)
above = Y < ey - float(CFG.get("hair_shell", {}).get("above_brows", 0.6)) * em_px
hairy = above & (lum < skin.mean() * float(FBC.get("hair_dark", 0.62)))
hair_soft = resample(hairy.astype(np.float32)[..., None], 128, (R, R))[..., 0]
mask *= np.where(above, np.clip(1.0 - hair_soft * 1.6, 0.0, 1.0), 1.0)
hair = np.array(CFG.get("hair_shell", {}).get("rgb", [0.05, 0.043, 0.04]), dtype=np.float32)
# Fill: skin, darkening toward the hair colour on the scalp.
# --- Hair: which head vertices carry hair (front from the photo, rest by rule) ---
HS = CFG.get("hair_shell", {})
ex_n = ex / pw_
vX = uvp[:, 0] * pw_
vY = (1.0 - uvp[:, 1]) * ph_
vcol = sample(uvp[:, 0], uvp[:, 1])
vlum = vcol.mean(axis=-1)
skin_guess = np.median(cheeks, axis=0)
photo_hair = ((vY < ey - float(HS.get("above_brows", 0.6)) * em_px) & (vlum < skin_guess.mean() * float(HS.get("dark", 0.62)))
              & (np.abs(vcol - _bg).sum(axis=-1) > 0.08)).astype(np.float32)
top_pts = head_m[head_m[:, 2] > f_eye_z]
cxh, cyh = float(np.median(top_pts[:, 0])), float(top_pts[:, 1].min() + top_pts[:, 1].max()) / 2.0
zz, yy, xx = head_m[:, 2], head_m[:, 1], head_m[:, 0]
rule = (
    (zz > f_eye_z + float(HS.get("crown", 0.03)))
    | ((yy > cyh) & (zz > f_eye_z - 0.015))
    | ((yy > cyh + 0.035) & (zz > f_eye_z - float(HS.get("nape", 0.06))))
).astype(np.float32)
ear = (np.abs(xx - cxh) > 0.06) & (zz < f_eye_z + 0.015) & (zz > f_eye_z - 0.06) & (np.abs(yy - cyh) < 0.035)
rule[ear] = 0.0
seen_w = np.clip((facing - 0.3) / 0.25, 0.0, 1.0)
hair_w = photo_hair * seen_w + rule * (1.0 - seen_w)
if "cap" in CFG:
    # A cap: everything above a plane from mid-forehead (front) to above the nape (back).
    yf, yb = float(top_pts[:, 1].min()), float(top_pts[:, 1].max())
    zf = f_eye_z + float(CFG["cap"].get("front", 0.035))
    zbk = f_eye_z + float(CFG["cap"].get("back", -0.005))
    plane = zf + (yy - yf) / max(yb - yf, 1e-6) * (zbk - zf)
    hair_w = (zz > plane).astype(np.float32)
# Smooth over the mesh a few times.
adj = [[] for _ in range(len(fb_pts))]
for e in fb_obj.data.edges:
    a_, b_ = e.vertices
    adj[a_].append(b_)
    adj[b_].append(a_)
for _ in range(int(HS.get("smooth", 8))):
    hair_w = np.array([0.5 * hair_w[i] + 0.5 * hair_w[nb].mean() if nb else hair_w[i] for i, nb in enumerate(adj)])
hras, _ = rasterize(R, hair_w[:, None].astype(np.float32))
scalp = np.clip((hras[..., 0] - 0.35) / 0.3, 0.0, 1.0)[..., None]
fill = skin * (1 - scalp) + hair * scalp
mask = mask * (1.0 - scalp[..., 0])
# Colours just inside the face, pushed outward and blurred: the head around
# the face takes the face's own (lit) skin, fading to the even tone further out.
_l = col.mean(axis=-1)
inner = (mask > 0.85) & cover & (np.abs(_l - skin.mean()) < 0.1)
near = push_pull_fill(np.dstack([col, inner.astype(np.float32)]))
near = resample(near, 64, (R, R))
reach = np.clip(resample(mask[..., None], 32, (R, R))[..., 0] * 3.0, 0.0, 1.0)[..., None]
fill = (near * reach + skin * (1 - reach)) * (1 - scalp) + hair * scalp
soft_mask = np.clip(mask * 1.1, 0.0, 1.0)
out = col * soft_mask[..., None] + fill * (1.0 - soft_mask[..., None])
out[~cover] = skin
filled = out
tex_out = bpy.data.images.new(NAME.lower() + "_head", tw, th, alpha=False)
tex_out.pixels.foreach_set(np.dstack([filled, np.ones((th, tw))]).astype(np.float32).ravel())
tex_out.filepath_raw = os.path.join(WORK, NAME.lower() + "_head.png")
tex_out.file_format = "PNG"
tex_out.save()
print("FB texture", tw, "skin", np.round(skin, 3), "face texels %.0f%%" % (100 * float((mask > 0.5).mean())))

# --- Join at the neck ----------------------------------------------------------------
cut = lips[2] - float(FBC.get("cut", 1.75)) * em
keep_below = cut - float(FBC.get("overlap", 0.07))
mesh = bpy.data.meshes.new(NAME + ".fbhead")
verts = [tuple(p) for p in head_m]
faces_keep = [p for p in fb_tris if min(head_m[i][2] for i in p) > keep_below]
used = sorted({i for p in faces_keep for i in p})
remap = {o: n for n, o in enumerate(used)}
mesh.from_pydata([verts[i] for i in used], [], [tuple(remap[i] for i in p) for p in faces_keep])
uv = mesh.uv_layers.new(name="UVMap")
src_uv = fb_obj.data.uv_layers.active.data
src_loops = {}
for poly in fb_obj.data.polygons:
    src_loops[tuple(poly.vertices)] = [src_uv[li].uv.copy() for li in poly.loop_indices]
for poly in mesh.polygons:
    key = tuple(used[i] for i in poly.vertices)
    for li, val in zip(poly.loop_indices, src_loops[key]):
        uv.data[li].uv = val
for poly in mesh.polygons:
    poly.use_smooth = True
# Body surface (shape keys on, modifiers off) to press the neck onto.
_bm_faces = [tuple(pl.vertices) for pl in body.data.polygons]
bvh_body = BVHTree.FromPolygons([Vector(q) for q in pts], _bm_faces)
from mathutils.kdtree import KDTree

kd_body = KDTree(len(pts))
for _i, _q in enumerate(pts):
    kd_body.insert(Vector(_q), _i)
kd_body.balance()
# Below the jaw the neck takes the body's own neck shape wherever it would
# stick out of it (that shape is what the jersey collar is made to fit).
# Body vertices the clothes cover (MPFB deletes them under the clothes).
_cov_groups = {g.index for g in body.vertex_groups if g.name.startswith("Delete.")}
covered = np.zeros(len(pts), dtype=bool)
for bv in body.data.vertices:
    if any(g.group in _cov_groups and g.weight > 0.5 for g in bv.groups):
        covered[bv.index] = True
jaw_z = lips[2] - float(FBC.get("jaw", 0.8)) * em
full_z = jaw_z - float(FBC.get("neck_blend", 0.035))
snapped = 0
tucked = []
for v in mesh.vertices:
    z = v.co.z
    if z >= jaw_z:
        continue
    hit = bvh_body.find_nearest(v.co)
    if hit[0] is None:
        continue
    outside = (v.co - hit[0]).dot(hit[1]) > -0.002
    w = float(np.clip((jaw_z - z) / max(jaw_z - full_z, 1e-4), 0.0, 1.0))
    w = w * w * (3 - 2 * w)
    _c, bi, _d = kd_body.find(v.co)
    if covered[bi]:
        # Under the clothes: tuck it just inside the skin, out of sight.
        tucked.append(v.index)
        continue
    if not outside and z > cut:
        continue
    target = hit[0] + hit[1].normalized() * 0.0015
    v.co = v.co.lerp(target, w)
    snapped += 1
# Also anything the top garment covers: a ray from the neck's axis out
# through the vertex meets the garment before (or just past) the vertex.
_top = None
for _o in bpy.data.objects:
    if _o.type == "MESH" and _o.name.startswith(NAME + ".") and _o.name.split(".", 1)[1] == CFG["clothes"][0].split("/")[0]:
        _top = _o
if _top is not None:
    _tm = _top.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    _bvh_top = BVHTree.FromPolygons([_top.matrix_world @ v.co for v in _tm.vertices], [tuple(p_.vertices) for p_ in _tm.polygons])
    _neck = pts[(np.abs(pts[:, 2] - cut) < 0.02) & (np.abs(pts[:, 0] - eyes[0]) < 0.08)]
    _ax = Vector((float(_neck[:, 0].mean()), float(_neck[:, 1].mean()), 0.0)) if len(_neck) else Vector((eyes[0], eyes[1] + 0.02, 0))
    _set = set(tucked)
    for v in mesh.vertices:
        if v.co.z > jaw_z or v.index in _set:
            continue
        o_ = Vector((_ax.x, _ax.y, v.co.z))
        d_ = v.co - o_
        if d_.length < 1e-4:
            continue
        hit = _bvh_top.ray_cast(o_, d_.normalized(), d_.length - 0.004)
        if hit[0] is not None:
            tucked.append(v.index)
            _set.add(v.index)
import bmesh as _bmesh

_bm = _bmesh.new()
_bm.from_mesh(mesh)
_bm.verts.ensure_lookup_table()
_bmesh.ops.delete(_bm, geom=[_bm.verts[i] for i in tucked], context="VERTS")
_bm.to_mesh(mesh)
_bm.free()
print("neck verts pressed onto the body:", snapped, "removed under the clothes:", len(tucked))
head_obj = bpy.data.objects.new(NAME + ".fbhead", mesh)
scene.collection.objects.link(head_obj)

# Hide the MPFB head and neck (mask modifier, applied at export).
hide = body.vertex_groups.new(name="fb_hidden")
hide_ids = [i for i, p in enumerate(pts) if p[2] > cut and abs(p[0] - eyes[0]) < 0.14 and p[1] > eyes[1] - 0.2]
hide.add(hide_ids, 1.0, "REPLACE")
mask = body.modifiers.new("Hide old head", "MASK")
mask.vertex_group = "fb_hidden"
mask.invert_vertex_group = True
for suffix in ("high-poly", "eyebrow", "eyelashes"):
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith(NAME + ".") and suffix in o.name:
            bpy.data.objects.remove(o)

# --- Hair shell / cap on the real skull ------------------------------------------------
def curly_texture(path, rgb, size=512, seed=7):
    rng = np.random.default_rng(seed)
    n = rng.random((size, size)).astype(np.float32)

    def blur(a, r):
        k = np.ones(2 * r + 1, dtype=np.float32) / (2 * r + 1)
        for ax in (0, 1):
            a = np.apply_along_axis(lambda m: np.convolve(np.concatenate([m[-r:], m, m[:r]]), k, "valid"), ax, a)
        return a

    fine, coarse = blur(n, 2), blur(n, 7)
    fine = (fine - fine.mean()) / (fine.std() + 1e-6)
    coarse = (coarse - coarse.mean()) / (coarse.std() + 1e-6)
    curls = 0.5 + 0.5 * np.sin(fine * 3.0 + coarse * 1.5)
    shade = 0.45 + 1.4 * curls ** 2.0 + 0.15 * coarse
    img = np.clip(np.asarray(rgb, np.float32)[None, None, :] * shade[..., None], 0.0, 1.0)
    im = bpy.data.images.new(os.path.basename(path)[:-4], size, size, alpha=False)
    im.pixels.foreach_set(np.dstack([img, np.ones((size, size))]).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return bpy.data.images.load(path)


is_cap = "cap" in CFG
spec = CFG["cap"] if is_cap else CFG.get("hair_shell", {})
thick = float(spec.get("thickness", 0.008 if is_cap else 0.015))
nb = (r.T @ vn.T).T
nb /= np.linalg.norm(nb, axis=1)[:, None]
keep_faces = [p_.vertices[:] for p_ in fb_obj.data.polygons if hair_w[list(p_.vertices)].mean() > 0.5]
used_s = sorted({i for f_ in keep_faces for i in f_})
remap_s = {o: n for n, o in enumerate(used_s)}
taper = np.clip((hair_w - 0.5) / 0.3, 0.0, 1.0)
shell_v = [tuple(head_m[i] + nb[i] * (0.0025 + thick * (1.0 if is_cap else taper[i]))) for i in used_s]
shell = bpy.data.meshes.new(NAME + (".cap" if is_cap else ".hairshell"))
shell.from_pydata(shell_v, [], [tuple(remap_s[i] for i in f_) for f_ in keep_faces])
suv = shell.uv_layers.new(name="UVMap")
for poly in shell.polygons:
    key = tuple(used_s[i] for i in poly.vertices)
    for li, val in zip(poly.loop_indices, src_loops[key]):
        suv.data[li].uv = (val[0] * (1 if is_cap else 7), val[1] * (1 if is_cap else 7))
for poly in shell.polygons:
    poly.use_smooth = True
if is_cap:
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(shell)
    # Flat brim out over the forehead, tipped down a little.
    base = head_m[used_s][np.abs(head_m[used_s][:, 2] - plane[used_s]) < 0.012]
    front = base[np.argmin(base[:, 1])] + nb[used_s][0] * 0
    half_w = float(np.ptp(base[:, 0])) * 0.5
    cx_b = float(np.median(base[:, 0]))
    y0 = float(front[1]) + 0.03
    z0 = float(front[2]) - 0.002
    reach = float(spec.get("brim", 0.075)) + 0.03
    ring = []
    for k in range(25):
        a_ = np.pi * k / 24.0
        x = cx_b - np.cos(a_) * half_w * 1.04
        y = y0 - np.sin(a_) * reach
        # Gently curved across (sides lower) and pitched up at the front.
        side = (np.cos(a_)) ** 2
        ring.append(bm.verts.new((x, y, z0 + (y0 - y) * 0.08 - side * 0.012)))
    top_face = bm.faces.new(ring)
    ext = bmesh.ops.extrude_face_region(bm, geom=[top_face])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.z -= 0.006
    # Button on the crown.
    crown_top = head_m[used_s][np.argmax(head_m[used_s][:, 2])]
    btn = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.007)
    for v in btn["verts"]:
        v.co += Vector(tuple(crown_top + np.array([0, 0, thick + 0.003])))
    bm.to_mesh(shell)
    bm.free()
shell_obj = bpy.data.objects.new(shell.name, shell)
scene.collection.objects.link(shell_obj)
smat = bpy.data.materials.new(shell.name.replace(".", "_"))
smat.use_nodes = True
sbsdf = smat.node_tree.nodes["Principled BSDF"]
if is_cap:
    sbsdf.inputs["Base Color"].default_value = list(spec.get("color", [0.018, 0.018, 0.02])) + [1.0]
    sbsdf.inputs["Roughness"].default_value = 0.9
else:
    tnode = smat.node_tree.nodes.new("ShaderNodeTexImage")
    tnode.image = curly_texture(os.path.join(WORK, NAME.lower() + "_hairshell.png"), hair * 1.3)
    smat.node_tree.links.new(tnode.outputs["Color"], sbsdf.inputs["Base Color"])
    sbsdf.inputs["Roughness"].default_value = 0.75
shell.materials.append(smat)
print("SHELL", shell.name, len(shell.vertices), "verts")
tufts_obj = None
if not is_cap and int(spec.get("tufts", 1200)) > 0:
    import bmesh

    def tuft_texture(path, rgb, size=1024, seed=3):
        """A 2x2 atlas of hair tufts: coiled strands with darker roots, lighter
        tips and a soft highlight, each cell a different shade."""
        rng = np.random.default_rng(seed)
        img = np.zeros((size, size, 4), np.float32)
        cell = size // 2
        straight = bool(spec.get("straight", False))
        for cy_i in range(2):
            for cx_i in range(2):
                tone = np.asarray(rgb) * (0.75 + 0.18 * (cy_i * 2 + cx_i))
                ox, oy = cx_i * cell, cy_i * cell
                for _ in range(int(spec.get("strands", 34))):
                    x0 = rng.uniform(0.15, 0.85) * cell
                    amp = (0.0 if straight else rng.uniform(0.018, 0.04)) * cell
                    freq = rng.uniform(5.0, 9.0)
                    lean = rng.uniform(-0.25, 0.25)
                    length = rng.uniform(0.55, 0.92)
                    width = rng.uniform(0.006, 0.011) * cell
                    phase = rng.uniform(0, 6.283)
                    for k in range(160):
                        t = k / 159.0
                        if t > length:
                            break
                        y = (1.0 - t) * cell * 0.98
                        x = x0 + lean * t * cell + amp * np.sin(freq * 6.283 * t + phase)
                        # Coils: the strand's width and brightness pulse along it.
                        coil = 0.5 + 0.5 * np.sin(freq * 6.283 * t + phase + 1.3)
                        w_ = width * (1.0 - 0.45 * t)
                        x_i, y_i = int(ox + x), int(oy + y)
                        r_ = int(w_ + 1.5)
                        ys_ = slice(max(y_i - r_, oy), min(y_i + r_ + 1, oy + cell))
                        xs_ = slice(max(x_i - r_, ox), min(x_i + r_ + 1, ox + cell))
                        if ys_.start >= ys_.stop or xs_.start >= xs_.stop:
                            continue
                        gy, gx = np.mgrid[ys_, xs_]
                        d_ = np.sqrt((gx - (ox + x)) ** 2 + (gy - (oy + y)) ** 2)
                        a_ = np.clip(1.0 - d_ / max(w_, 0.5), 0.0, 1.0) * (1.0 - 0.6 * t ** 3)
                        shade_ = (0.55 + 0.6 * t) * (0.8 + 0.4 * coil)
                        sub = img[ys_, xs_]
                        newer = a_ > sub[..., 3] * 0.6
                        sub[..., :3] = np.where(newer[..., None], tone * shade_, sub[..., :3])
                        sub[..., 3] = np.maximum(sub[..., 3], a_)
        img[..., :3][img[..., 3] < 0.01] = np.asarray(rgb) * 0.6
        im_ = bpy.data.images.new(os.path.basename(path)[:-4], size, size, alpha=True)
        im_.pixels.foreach_set(img[::-1].ravel())
        im_.filepath_raw = path
        im_.file_format = "PNG"
        im_.save()
        return bpy.data.images.load(path)

    rng = np.random.default_rng(11)
    sv = np.array([tuple(v.co) for v in shell.vertices])
    sn = np.array([tuple(v.normal) for v in shell.vertices])
    full = np.array([taper[used_s[k]] for k in range(len(sv))])
    pick = rng.choice(len(sv), size=min(int(spec.get("tufts", 1200)), len(sv) * 3), p=(full + 0.05) / (full + 0.05).sum())
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    size_ = float(spec.get("tuft_size", 0.022))
    for k in pick:
        n_ = Vector(tuple(sn[k])).normalized()
        base_ = Vector(tuple(sv[k])) + n_ * rng.uniform(-0.004, 0.002)
        t1 = n_.orthogonal().normalized()
        t1.rotate(__import__("mathutils").Quaternion(n_, rng.uniform(0, 6.283)))
        t2 = n_.cross(t1).normalized()
        # Two layers: short dense tufts close to the scalp, longer ones above;
        # at the hairline (low "full") tufts are smaller and sparser.
        for layer in (0, 1):
            if layer == 1 and rng.random() > full[k]:
                continue
            sz = size_ * rng.uniform(0.7, 1.25) * (0.5 + 0.5 * full[k]) * (0.75 if layer == 0 else 1.1)
            lift_ = n_ * (0.003 * layer)
            # Hair grows outward but combs back and down a little.
            comb = Vector((0.0, 0.35, -0.25)) * float(spec.get("comb", 1.0))
            up = (n_ + comb * 0.6).normalized()
            cu, cv = rng.integers(0, 2) * 0.5, rng.integers(0, 2) * 0.5
            for side in (t1, t2):
                q = [base_ + lift_ - side * sz * 0.5, base_ + lift_ + side * sz * 0.5,
                     base_ + lift_ + side * sz * 0.5 + up * sz, base_ + lift_ - side * sz * 0.5 + up * sz]
                f_ = bm.faces.new([bm.verts.new(c) for c in q])
                for loop, uvv in zip(f_.loops, [(0, 0), (0.5, 0), (0.5, 0.5), (0, 0.5)]):
                    loop[uvl].uv = (uvv[0] + cu, uvv[1] + cv)
    tmesh = bpy.data.meshes.new(NAME + ".hairtufts")
    bm.to_mesh(tmesh)
    bm.free()
    tufts_obj = bpy.data.objects.new(tmesh.name, tmesh)
    scene.collection.objects.link(tufts_obj)
    tmat = bpy.data.materials.new(NAME + "_hairtufts")
    tmat.use_nodes = True
    tn = tmat.node_tree.nodes.new("ShaderNodeTexImage")
    tn.image = tuft_texture(os.path.join(WORK, NAME.lower() + "_tufts.png"), hair * 1.4)
    tb = tmat.node_tree.nodes["Principled BSDF"]
    tmat.node_tree.links.new(tn.outputs["Color"], tb.inputs["Base Color"])
    tmat.node_tree.links.new(tn.outputs["Alpha"], tb.inputs["Alpha"])
    tb.inputs["Roughness"].default_value = 0.7
    tmat.surface_render_method = "DITHERED"
    tmesh.materials.append(tmat)
    print("TUFTS", len(tmesh.polygons), "cards")
# The MPFB hair cards and cap go (unless asked to keep the cards on top).
for o in list(bpy.data.objects):
    if o.type != "MESH" or not o.name.startswith(NAME + "."):
        continue
    key = o.name.split(".", 1)[1]
    if key == CFG["hair"].split("/")[0] and not spec.get("keep_cards", False):
        bpy.data.objects.remove(o)
    elif key == "cap" and o is not shell_obj:
        bpy.data.objects.remove(o)

# --- 3. Refit hair, cap and glasses to the new skull ------------------------------------
def skull(p, eye_z):
    top = p[p[:, 2] > eye_z]
    return top.min(axis=0), top.max(axis=0)


m_lo, m_hi = skull(pts[np.abs(pts[:, 0] - eyes[0]) < 0.14], eyes[2])
f_eyes_z = float((((f_er + f_el) / 2 - t) @ r)[2] / s)
f_lo, f_hi = skull(head_m, f_eyes_z)
m_c, f_c = (m_lo + m_hi) / 2, (f_lo + f_hi) / 2
m_c[2], f_c[2] = eyes[2], f_eyes_z
ratio = (f_hi - f_lo) / np.maximum(m_hi - m_lo, 1e-6)
ratio[2] = (f_hi[2] - f_eyes_z) / max(m_hi[2] - eyes[2], 1e-6)
print("skull ratio", np.round(ratio, 3))
for o in bpy.data.objects:
    if o.type != "MESH" or not o.name.startswith(NAME + ".") or o in (body, head_obj, shell_obj, tufts_obj):
        continue
    key = o.name.split(".", 1)[1]
    if key not in (CFG["hair"].split("/")[0], "cap", "glasses"):
        continue
    inv = o.matrix_world.inverted()
    for v in o.data.vertices:
        p = np.array(tuple(o.matrix_world @ v.co))
        v.co = inv @ Vector(tuple(f_c + (p - m_c) * ratio))
    print("refit", o.name)

# --- 4. Skin to the neck and head bones -------------------------------------------------
bones = arm.data.bones
head_z = (arm.matrix_world @ bones["head"].head_local).z
neck_z = (arm.matrix_world @ bones["neck_01"].head_local).z
groups = {}


def group(name):
    if name not in groups:
        groups[name] = head_obj.vertex_groups.new(name=name)
    return groups[name]


body_groups = {g.index: g.name for g in body.vertex_groups if g.name in bones}
for v in mesh.vertices:
    z = v.co.z
    a = float(np.clip((z - (cut + 0.02)) / 0.04, 0.0, 1.0))
    if a > 0.0:
        group("head").add([v.index], a, "ADD")
    if a < 1.0:
        # The same bones, with the same weights, as the body at this spot.
        _co, bi, _d = kd_body.find(v.co)
        ws = [(body_groups[g.group], g.weight) for g in body.data.vertices[bi].groups if g.group in body_groups]
        total = sum(w for _n, w in ws) or 1.0
        for name, w in ws:
            group(name).add([v.index], (1.0 - a) * w / total, "ADD")
head_obj.parent = arm
head_obj.modifiers.new("Armature", "ARMATURE").object = arm
shell_obj.vertex_groups.new(name="head").add(list(range(len(shell.vertices))), 1.0, "REPLACE")
shell_obj.parent = arm
shell_obj.modifiers.new("Armature", "ARMATURE").object = arm
if tufts_obj:
    tufts_obj.vertex_groups.new(name="head").add(list(range(len(tufts_obj.data.vertices))), 1.0, "REPLACE")
    tufts_obj.parent = arm
    tufts_obj.modifiers.new("Armature", "ARMATURE").object = arm
mat = bpy.data.materials.new(NAME + "_fbhead")
mat.use_nodes = True
node = mat.node_tree.nodes.new("ShaderNodeTexImage")
node.image = bpy.data.images.load(tex_out.filepath_raw)
bsdf = mat.node_tree.nodes["Principled BSDF"]
mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
mesh.materials.append(mat)

for o in (fb_obj, fb_cam):
    bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "base.blend"))
print("FB HEAD", len(mesh.vertices), "verts; hid", len(hide_ids), "body verts")
