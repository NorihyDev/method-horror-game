"""Builds a character's body with MPFB from its character.json.

blender -b --python build_character.py -- <character_dir> <work_dir>
Saves <work_dir>/base.blend and preview renders. See docs/characters.md.
"""
import json
import math
import os
import sys

import bpy
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

CHAR_DIR, WORK = sys.argv[sys.argv.index("--") + 1 :][:2]
CFG = json.load(open(os.path.join(CHAR_DIR, "character.json"), encoding="utf-8"))
os.makedirs(WORK, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
info = {
    "name": CFG["name"],
    "phenotype": CFG["phenotype"],
    "rig": "game_engine",
    "eyes": "high-poly/high-poly.mhclo",
    "eyebrows": CFG.get("eyebrows", "eyebrow006/eyebrow006.mhclo"),
    "eyelashes": "eyelashes01/eyelashes01.mhclo",
    "hair": CFG["hair"],
    "proxy": "",
    "clothes": CFG["clothes"],
    "clothes_material_type": "MAKESKIN",
    "eyes_material_type": "MAKESKIN",
    "skin_mhmat": CFG["skin"],
    "skin_material_type": "ENHANCED_SSS",
    "targets": CFG.get("targets", []),
    "alternative_materials": {},
}
settings = HumanService.get_default_deserialization_settings()
settings["subdiv_levels"] = 0
basemesh = HumanService.deserialize_from_dict(info, settings)
print("BUILT", basemesh.name, [o.name for o in bpy.data.objects])

# Texture swaps: {"<asset name suffix>": "<png in the character dir>"}.
for suffix, png in CFG.get("textures", {}).items():
    img = bpy.data.images.load(os.path.join(CHAR_DIR, png))
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.name.endswith(suffix):
            continue
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and "normal" not in n.image.name and "_ao" not in n.image.name:
                    n.image = img
                    print("TEXTURE", o.name, png)



def add_cap(spec):
    """A snapback cap (crown + flat brim) skinned to the head bone."""
    import bmesh

    body = bpy.data.objects[CFG["name"] + ".body"]
    arm = body.parent
    states = [(m, m.show_viewport) for m in body.modifiers]
    for m, _ in states:
        m.show_viewport = False
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    tmp = ev.to_mesh()
    pts = [body.matrix_world @ v.co for v in tmp.vertices]
    ev.to_mesh_clear()
    for m, was in states:
        m.show_viewport = was
    top = max(p.z for p in pts)
    head = [p for p in pts if p.z > top - 0.13]
    cx = sum(p.x for p in head) / len(head)
    cy = sum(p.y for p in head) / len(head)
    rx = (max(p.x for p in head) - min(p.x for p in head)) * 0.5
    ry = (max(p.y for p in head) - min(p.y for p in head)) * 0.5
    base_z = top - float(spec.get("depth", 0.085))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=14, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.02], context="VERTS")
    for v in bm.verts:
        v.co.x *= rx * 1.2
        v.co.y *= ry * 1.14
        v.co.z = v.co.z * (top - base_z + 0.02) + base_z
        v.co.x += cx
        v.co.y += cy
    brim = bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=1.0, radius2=1.0, depth=0.012)
    # The brim: an oval sticking out over the forehead (its back half hides
    # inside the crown), tipped up a little at the front.
    for v in brim["verts"]:
        v.co.x = v.co.x * rx * 0.95 + cx
        v.co.y = v.co.y * ry * 0.75 + cy - ry * 1.05
        v.co.z = v.co.z + base_z + 0.012 - (v.co.y - (cy - ry * 0.5)) * 0.1
    mesh = bpy.data.meshes.new(CFG["name"] + ".cap")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(CFG["name"] + ".cap", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    group = obj.vertex_groups.new(name="head")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mat = bpy.data.materials.new(CFG["name"] + "_cap")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = list(spec.get("color", [0.02, 0.02, 0.022])) + [1.0]
    bsdf.inputs["Roughness"].default_value = 0.85
    mesh.materials.append(mat)
    print("CAP", round(rx, 3), round(ry, 3), round(top, 3))
    # Remove hair the cap covers so it can't poke through the crown.
    hair = bpy.data.objects.get(CFG["name"] + "." + CFG["hair"].split("/")[0])
    if hair and spec.get("hide_hair", True):
        bpy.data.objects.remove(hair)


def add_glasses(spec):
    """Thin wire-frame glasses (no lenses) skinned to the head bone."""
    import bmesh
    from mathutils import Matrix, Vector

    name = CFG["name"]
    body = bpy.data.objects[name + ".body"]
    arm = body.parent
    states = [(m, m.show_viewport) for m in body.modifiers]
    for m, _ in states:
        m.show_viewport = False
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    tmp = ev.to_mesh()
    pts = [body.matrix_world @ v.co for v in tmp.vertices]
    ev.to_mesh_clear()
    for m, was in states:
        m.show_viewport = was

    def centre(group):
        gi = body.vertex_groups[group].index
        sel = [pts[v.index] for v in body.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
        return sum(sel, Vector()) / len(sel)

    eyes = [centre("joint-r-eye"), centre("joint-l-eye")]
    front = min(e.y for e in eyes) - float(spec.get("offset", 0.024))
    wire = float(spec.get("wire", 0.0016))
    half_w, half_h = float(spec.get("width", 0.024)), float(spec.get("height", 0.018))
    bm = bmesh.new()

    def tube(a, b):
        ret = bmesh.ops.create_cone(bm, cap_ends=False, segments=6, radius1=wire, radius2=wire, depth=(b - a).length)
        rot = (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=ret["verts"])

    inner = []
    for e in eyes:
        c = Vector((e.x, front, e.z))
        ring = [c + Vector((math.cos(t) * half_w, 0, math.sin(t) * half_h)) for t in [i * math.tau / 20 for i in range(20)]]
        for i in range(20):
            tube(ring[i], ring[(i + 1) % 20])
        inner.append(c + Vector((-half_w if e.x > 0 else half_w, 0, half_h * 0.3)))
        side = 1.0 if e.x > 0 else -1.0
        hinge = c + Vector((side * half_w, 0, half_h * 0.4))
        tube(hinge, hinge + Vector((side * 0.012, 0.1, 0.0)))
    tube(inner[0], inner[1])
    mesh = bpy.data.meshes.new(name + ".glasses")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name + ".glasses", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = arm
    obj.vertex_groups.new(name="head").add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    obj.modifiers.new("Armature", "ARMATURE").object = arm
    mat = bpy.data.materials.new(name + "_glasses")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = list(spec.get("color", [0.45, 0.36, 0.22])) + [1.0]
    bsdf.inputs["Metallic"].default_value = 0.8
    bsdf.inputs["Roughness"].default_value = 0.35
    mesh.materials.append(mat)
    print("GLASSES", [tuple(round(x, 3) for x in e) for e in eyes])


if "cap" in CFG:
    add_cap(CFG["cap"])
if "glasses" in CFG:
    add_glasses(CFG["glasses"])

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.82, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
for loc, energy in [((2.5, -3.5, 2.6), 240.0), ((-3.0, -2.0, 2.0), 160.0), ((0, 3.0, 2.5), 200.0)]:
    light = bpy.data.lights.new("Key", "AREA")
    light.energy = energy
    light.size = 3.0
    obj = bpy.data.objects.new("Key", light)
    obj.location = loc
    scene.collection.objects.link(obj)
    obj.rotation_euler = (-obj.location.copy()).to_track_quat("-Z", "Y").to_euler()
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "base.blend"))
print("SAVED")
