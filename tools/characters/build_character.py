"""Builds a character's body with MPFB from its character.json.

blender -b --python build_character.py -- <character_dir> <work_dir>
Saves <work_dir>/base.blend and preview renders. See docs/characters.md.
"""
import json
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
