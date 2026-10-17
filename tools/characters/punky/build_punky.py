"""Builds Punky with MPFB in Blender (run with blender -b --python build_punky.py -- <out_dir>)."""
import sys
import os
import bpy
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

OUT = sys.argv[sys.argv.index("--") + 1]

bpy.ops.wm.read_factory_settings(use_empty=True)
info = {
    "name": "Punky",
    "phenotype": {
        "gender": 1.0,
        "age": 0.36,
        "muscle": 0.45,
        "weight": 0.38,
        "proportions": 0.6,
        "height": 0.6,
        "cupsize": 0.5,
        "firmness": 0.5,
        "race": {"asian": 0.45, "caucasian": 0.12, "african": 0.43},
    },
    "rig": "game_engine",
    "eyes": "high-poly/high-poly.mhclo",
    "eyebrows": "eyebrow006/eyebrow006.mhclo",
    "eyelashes": "eyelashes01/eyelashes01.mhclo",
    "hair": "culturalibre_hair_06/culturalibre_hair_06.mhclo",
    "proxy": "",
    "clothes": ["male_casualsuit05/male_casualsuit05.mhclo", "shoes03/shoes03.mhclo"],
    "clothes_material_type": "MAKESKIN",
    "eyes_material_type": "MAKESKIN",
    "skin_mhmat": "young_african_male/young_african_male.mhmat",
    "skin_material_type": "ENHANCED_SSS",
    "targets": [
        {"target": "head-oval", "value": 0.5},
        {"target": "head-scale-horiz-decr", "value": 0.22},
        {"target": "head-fat-decr", "value": 0.3},
        {"target": "chin-height-incr", "value": 0.35},
        {"target": "chin-width-decr", "value": 0.25},
        {"target": "nose-scale-horiz-incr", "value": 0.25},
        {"target": "nose-flaring-incr", "value": 0.35},
        {"target": "nose-point-width-incr", "value": 0.3},
        {"target": "mouth-lowerlip-volume-incr", "value": 0.35},
        {"target": "mouth-scale-horiz-decr", "value": 0.1},
    ],
    "alternative_materials": {},
}
settings = HumanService.get_default_deserialization_settings()
settings["subdiv_levels"] = 0
basemesh = HumanService.deserialize_from_dict(info, settings)
print("BUILT", basemesh.name, [o.name for o in bpy.data.objects])
# Brown eyes like his.
U = os.path.join(os.environ["APPDATA"], "Blender Foundation", "Blender", "5.2", "extensions", ".user", "blender_org", "mpfb", "data")
brown = bpy.data.images.load(os.path.join(OUT, "punky_eye.png"))
for o in bpy.data.objects:
    if o.name.endswith("high-poly"):
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and "eye" in n.image.name.lower():
                    n.image = brown
                    print("EYES", m.name)
    if o.name.endswith("culturalibre_hair_06"):
        dark_hair = bpy.data.images.load(os.path.join(OUT, "punky_hair.png"))
        for m in o.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    n.image = dark_hair
                    print("HAIR", m.name)

# Studio preview: front and three-quarter renders.
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
    direction = obj.location.copy()
    obj.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def shot(name, loc, target, lens):
    from mathutils import Vector
    cam.location = loc
    cam_data.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


top = max((o.matrix_world @ v.co).z for o in [basemesh] for v in o.data.vertices)
print("HEIGHT", round(top, 3))
shot("full_front", (0, -4.2, 0.95), (0, 0, 0.88), 45)
shot("full_34", (2.8, -3.2, 1.0), (0, 0, 0.88), 45)
shot("face_front", (0, -0.9, top - 0.1), (0, 0, top - 0.12), 85)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "punky_base.blend"))
print("SAVED")
