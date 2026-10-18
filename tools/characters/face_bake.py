"""Projects a character's front photo onto the MPFB head and bakes it into one
skin texture. Landmarks and tone samples come from character.json ("photo").

blender -b <work>/base.blend --python face_bake.py -- <character_dir> <work_dir>
The photo is <work_dir>/face_src.png and never goes in the repository.
"""
import json
import os
import sys
import bpy
import numpy as np
from mathutils import Vector

CHAR_DIR, D = sys.argv[sys.argv.index("--") + 1 :][:2]
CFG = json.load(open(os.path.join(CHAR_DIR, "character.json"), encoding="utf-8"))
NAME = CFG["name"]
PH_CFG = CFG["photo"]
PHOTO = os.path.join(D, "face_src.png")
_probe = bpy.data.images.load(PHOTO)
PW, PH = float(_probe.size[0]), float(_probe.size[1])
P_EYE_R = np.array(PH_CFG["eye_r"], dtype=float)
P_EYE_L = np.array(PH_CFG["eye_l"], dtype=float)
P_MOUTH = np.array(PH_CFG["mouth"], dtype=float)
P_CHIN_Y = float(PH_CFG["chin_y"])
TEX = 2048

body = bpy.data.objects[NAME + ".body"]
mesh = body.data


def shaped_coords(obj):
    """World positions with MPFB's shape keys applied (modifiers off keeps vertex indices)."""
    states = [(m, m.show_viewport) for m in obj.modifiers]
    for m, _ in states:
        m.show_viewport = False
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    tmp = ev.to_mesh()
    out = [obj.matrix_world @ v.co for v in tmp.vertices]
    ev.to_mesh_clear()
    for m, was in states:
        m.show_viewport = was
    return out


CO = shaped_coords(body)


def group_center(name, front=False):
    gi = body.vertex_groups[name].index
    pts = [CO[v.index] for v in mesh.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    if front:
        ymin = min(p.y for p in pts)
        pts = [p for p in pts if p.y < ymin + 0.008]
    return sum(pts, Vector()) / len(pts)


eye_r = group_center("joint-r-eye")
eye_l = group_center("joint-l-eye")
mouth = group_center("lips", front=True)
print("MODEL eyes", eye_r, eye_l, "mouth", mouth)

# Photo pixel -> model (x, z): x from the eyes, z from eyes-to-mouth (anisotropic fit).
p_eyes_mid = (P_EYE_R + P_EYE_L) / 2
m_eyes_mid = (eye_r + eye_l) / 2
sx = (eye_l.x - eye_r.x) / (P_EYE_L[0] - P_EYE_R[0])
sz = (m_eyes_mid.z - mouth.z) / (P_MOUTH[1] - p_eyes_mid[1])


def model_to_photo(x, z):
    px = p_eyes_mid[0] + (x - m_eyes_mid.x) / sx
    py = p_eyes_mid[1] - (z - m_eyes_mid.z) / sz
    return px, py


# A "photo" UV layer: front orthographic projection of the photo.
if "photo" in mesh.uv_layers:
    mesh.uv_layers.remove(mesh.uv_layers["photo"])
main_uv = mesh.uv_layers.active.name
photo_uv = mesh.uv_layers.new(name="photo")
mw = body.matrix_world
for loop in mesh.loops:
    co = CO[loop.vertex_index]
    px, py = model_to_photo(co.x, co.z)
    photo_uv.data[loop.index].uv = (px / PW, 1.0 - py / PH)

# Mask image in photo space: a feathered face oval from the brows to the chin.
mask = np.zeros((int(PH), int(PW)), dtype=np.float32)
yy, xx = np.mgrid[0 : int(PH), 0 : int(PW)]
cx, cy, rx, ry = PH_CFG["mask"]
d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
mask = np.clip((1.0 - d) / 0.22, 0.0, 1.0)
fall = max(6.0, ry * 0.1)
mask[yy > P_CHIN_Y + 2] *= np.clip(1.0 - (yy[yy > P_CHIN_Y + 2] - P_CHIN_Y - 2) / fall, 0.0, 1.0)
# Saved to disk and reloaded: an in-memory generated image comes back blank when baking.
tmp_img = bpy.data.images.new("face_mask_tmp", int(PW), int(PH), alpha=False)
rgba = np.dstack([mask, mask, mask, np.ones_like(mask)])[::-1].astype(np.float32)
tmp_img.pixels.foreach_set(rgba.ravel())
tmp_img.filepath_raw = os.path.join(D, "face_mask.png")
tmp_img.file_format = "PNG"
tmp_img.save()
mask_img = bpy.data.images.load(os.path.join(D, "face_mask.png"))

# Skin tone: match the body texture's average to his cheeks.
photo_img = bpy.data.images.load(PHOTO)
pp = np.array(photo_img.pixels[:], dtype=np.float32).reshape(int(PH), int(PW), 4)[::-1]


def blur(a, r):
    """Box blur (separable, repeated) as a cheap Gaussian."""
    out = a.copy()
    for _ in range(3):
        k = np.ones(2 * r + 1, dtype=np.float32) / (2 * r + 1)
        out = np.apply_along_axis(lambda m: np.convolve(m, k, mode="same"), 0, out)
        out = np.apply_along_axis(lambda m: np.convolve(m, k, mode="same"), 1, out)
    return out
def sample(region):
    y0, y1, x0, x1 = region
    return pp[y0:y1, x0:x1, :3].reshape(-1, 3)


cheeks = np.concatenate([sample(r) for r in PH_CFG["cheeks"]]).mean(axis=0)
# A bright studio light can bleach the face; a neck sample shows the real tone.
target = cheeks
if "neck" in PH_CFG:
    w = float(PH_CFG.get("neck_weight", 0.65))
    target = cheeks * (1.0 - w) + sample(PH_CFG["neck"]).mean(axis=0) * w
target = target * float(PH_CFG.get("tone_scale", 1.0))
# The body's own skin texture: the diffuse image from the skin asset's folder.
skin_dir = CFG["skin"].split("/")[0]
skin_img = None
for img in bpy.data.images:
    path = img.filepath.replace("\\", "/")
    if skin_img is None and "/" + skin_dir + "/" in path and "diffuse" in path.lower():
        skin_img = img
assert skin_img, "skin texture not found for " + skin_dir
sp = np.array(skin_img.pixels[:], dtype=np.float32).reshape(skin_img.size[1], skin_img.size[0], 4)
source = sp[..., :3].reshape(-1, 3)
source = source[source.sum(axis=1) > 0.05].mean(axis=0)
tint = np.clip(target / source, 0.4, 3.0)
# De-light the photo: remove the studio light's broad gradient and keep the
# facial detail, re-lit at the even body tone (target).
lum = pp[..., :3].mean(axis=-1)
low = blur(lum, int(PH_CFG.get("delight_radius", 22))) + 1e-3
flat = pp[..., :3] / low[..., None] * target.mean()
y0, y1, x0, x1 = PH_CFG["tone_band"]
flat = flat * (target / flat[y0:y1, x0:x1].reshape(-1, 3).mean(axis=0))
pp_out = np.dstack([np.clip(flat, 0, 1), pp[..., 3:]])[::-1].astype(np.float32)
photo_img = bpy.data.images.new("photo_flat", int(PW), int(PH), alpha=True)
photo_img.pixels.foreach_set(pp_out.ravel())
photo_img.filepath_raw = os.path.join(D, "face_flat.png")
photo_img.file_format = "PNG"
photo_img.save()
photo_img = bpy.data.images.load(os.path.join(D, "face_flat.png"))
print("TONE photo", target, "skin", source, "tint", tint)

# Bake material: tinted skin (main UV) mixed with the photo (photo UV) by mask x facing.
bake_mat = bpy.data.materials.new("skin_bake")
bake_mat.use_nodes = True
nt = bake_mat.node_tree
nt.nodes.clear()
N = nt.nodes.new
out = N("ShaderNodeOutputMaterial")
emit = N("ShaderNodeEmission")
uv_main = N("ShaderNodeUVMap")
uv_main.uv_map = main_uv
uv_photo = N("ShaderNodeUVMap")
uv_photo.uv_map = "photo"
t_skin = N("ShaderNodeTexImage")
t_skin.image = skin_img
t_photo = N("ShaderNodeTexImage")
t_photo.image = photo_img
t_photo.extension = "CLIP"
t_mask = N("ShaderNodeTexImage")
t_mask.image = mask_img
t_mask.extension = "CLIP"
t_mask.image.colorspace_settings.name = "Non-Color"
tint_node = N("ShaderNodeMix")
tint_node.data_type = "RGBA"
tint_node.blend_type = "MULTIPLY"
tint_node.inputs["Factor"].default_value = 1.0
tint_node.inputs[7].default_value = (float(tint[0]), float(tint[1]), float(tint[2]), 1.0)
geo = N("ShaderNodeNewGeometry")
facing = N("ShaderNodeVectorMath")
facing.operation = "DOT_PRODUCT"
facing.inputs[1].default_value = (0.0, -1.0, 0.0)
ramp = N("ShaderNodeMapRange")
ramp.inputs["From Min"].default_value = 0.35
ramp.inputs["From Max"].default_value = 0.75
fade = N("ShaderNodeMath")
fade.operation = "MULTIPLY"
mix = N("ShaderNodeMix")
mix.data_type = "RGBA"
target_img = bpy.data.images.new(NAME.lower() + "_skin_baked", TEX, TEX, alpha=False)
t_target = N("ShaderNodeTexImage")
t_target.image = target_img
L = nt.links.new
L(uv_main.outputs["UV"], t_skin.inputs["Vector"])
L(uv_photo.outputs["UV"], t_photo.inputs["Vector"])
L(uv_photo.outputs["UV"], t_mask.inputs["Vector"])
L(t_skin.outputs["Color"], tint_node.inputs[6])
L(geo.outputs["Normal"], facing.inputs[0])
L(facing.outputs["Value"], ramp.inputs["Value"])
L(ramp.outputs["Result"], fade.inputs[0])
L(t_mask.outputs["Color"], fade.inputs[1])
L(fade.outputs["Value"], mix.inputs["Factor"])
L(tint_node.outputs[2], mix.inputs[6])
L(t_photo.outputs["Color"], mix.inputs[7])
L(mix.outputs[2], emit.inputs["Color"])
L(emit.outputs["Emission"], out.inputs["Surface"])
nt.nodes.active = t_target
t_target.select = True

original = list(mesh.materials)
mesh.materials.clear()
mesh.materials.append(bake_mat)
mesh.uv_layers.active = mesh.uv_layers[main_uv]
for o in bpy.context.view_layer.objects:
    o.select_set(False)
body.select_set(True)
bpy.context.view_layer.objects.active = body
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True)
target_img.filepath_raw = os.path.join(D, NAME.lower() + "_skin.png")
target_img.file_format = "PNG"
target_img.save()
print("BAKED", target_img.filepath_raw)

# Final skin: the baked texture on a plain principled material (game-ready).
skin = bpy.data.materials.new(NAME + "_Skin")
skin.use_nodes = True
bsdf = skin.node_tree.nodes["Principled BSDF"]
tex = skin.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(target_img.filepath_raw)
skin.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
mesh.materials.clear()
mesh.materials.append(skin)
mesh.uv_layers.remove(mesh.uv_layers["photo"])

# Hair cards stay alpha-blended and a little rough (none under a cap).
hair = bpy.data.objects.get(NAME + "." + CFG["hair"].split("/")[0])
for m in hair.data.materials if hair else []:
    m.surface_render_method = "BLENDED" if hasattr(m, "surface_render_method") else m.surface_render_method
    for node in m.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            node.inputs["Roughness"].default_value = 0.6

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, "face.blend"))
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.exposure = -1.0
cam = scene.camera
top = max(c.z for c in CO)
print("HEIGHT", round(top, 3))
head_mid = (eye_r + eye_l) / 2
for name, loc in [("face_front2", (0, -0.75, head_mid.z - 0.03)), ("face_34", (0.5, -0.6, head_mid.z - 0.02))]:
    cam.location = loc
    scene.camera.data.lens = 85
    cam.rotation_euler = (Vector((0, 0, head_mid.z - 0.04)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(D, name + ".png")
    bpy.ops.render.render(write_still=True)
for name, loc, target, lens in [
    ("body_front", (0, -4.4, 0.95), (0, 0, 0.9), 45),
    ("body_34", (2.9, -3.3, 1.05), (0, 0, 0.9), 45),
]:
    cam.location = loc
    scene.camera.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(D, name + ".png")
    bpy.ops.render.render(write_still=True)
print("DONE")
