"""Rewrites props.json from the GLBs in a folder (sizes in glTF Y-up metres).

blender -b --python measure_props.py -- <props_dir>
"""
import json
import os
import sys

import bpy

DIR = sys.argv[sys.argv.index("--") + 1]
info = {}
for name in sorted(os.listdir(DIR)):
    if not name.endswith(".glb"):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, name))
    pts = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    # Blender Z-up -> glTF Y-up: x, z (up), y.
    info[name[:-4]] = {"size": [round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)], "tris": tris}
json.dump(info, open(os.path.join(DIR, "props.json"), "w"), indent=1)
print("MEASURED", len(info))
