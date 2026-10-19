"""Converts downloaded Poly Haven models (CC0, glTF 1k) into game-ready GLBs.

blender -b --python convert_props.py -- <source_dir> <out_dir> <id> [<id> ...]

For each model: import, join meshes, bring the base to y=0 and centre it,
reduce to a triangle budget, scale textures to 512 px (1024 for big pieces),
export GLB, and record its size in <out_dir>/props.json (merged) so the game
can fit it to the footprint of the furniture it replaces.
"""
import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1 :][:2]
IDS = sys.argv[sys.argv.index("--") + 3 :]
BUDGET = {"covered_car": 9000, "old_bed_frame": 7000, "GothicCabinet_01": 6000}
BIG = {"covered_car", "old_bed_frame", "vintage_day_bed", "GothicCabinet_01", "wooden_bookshelf_worn", "Sofa_01", "sofa_03"}
os.makedirs(OUT, exist_ok=True)
info_path = os.path.join(OUT, "props.json")
info = json.load(open(info_path)) if os.path.exists(info_path) else {}

for pid in IDS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = os.path.join(SRC, pid)
    gltf = [f for f in os.listdir(folder) if f.endswith(".gltf")][0]
    bpy.ops.import_scene.gltf(filepath=os.path.join(folder, gltf))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for o in list(bpy.data.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    obj.parent = None
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    obj.data.transform(Matrix.Translation(-centre))
    obj.matrix_world = Matrix.Identity(4)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    budget = BUDGET.get(pid, 4000)
    if tris > budget:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = budget / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    size_px = 1024 if pid in BIG else 512
    for img in bpy.data.images:
        if img.has_data and img.size[0] > size_px:
            img.scale(size_px, size_px)
    obj.name = pid
    out = os.path.join(OUT, pid + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="WEBP", export_image_quality=85)
    size = hi - lo
    # Blender Z-up -> glTF Y-up: x stays, Blender y is glTF -z, z is up.
    info[pid] = {"size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
                 "tris": sum(len(p.vertices) - 2 for p in obj.data.polygons)}
    print("PROP", pid, info[pid], os.path.getsize(out))
json.dump(info, open(info_path, "w"), indent=1)
