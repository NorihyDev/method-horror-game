"""Animates a character procedurally and exports a game-ready GLB.

blender -b <work>/face.blend --python animate_export.py -- <character_dir> <work_dir> <out.glb>
Poses are written as armature-space bone directions (he faces -Y, +Z up),
solved parent-first; legs use two-bone IK so planted feet stay on the floor.
"""
import json
import math
import os
import sys
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :]
CHAR_DIR, D, OUT = ARGS[0], ARGS[1], ARGS[2]
CFG = json.load(open(os.path.join(CHAR_DIR, "character.json"), encoding="utf-8"))
NAME = CFG["name"]
HAIR = CFG["hair"].split("/")[0]
CLOTHES = [c.split("/")[0] for c in CFG["clothes"]]
FPS = 30
scene = bpy.context.scene
scene.render.fps = FPS
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
bones = arm.data.bones
pbs = arm.pose.bones
REST = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in bones}
_nv = REST["neck_01"][1] - REST["neck_01"][0]
NECK_REST = math.atan2(-_nv.y, _nv.z)
L_THIGH = (REST["thigh_l"][1] - REST["thigh_l"][0]).length
L_CALF = (REST["calf_l"][1] - REST["calf_l"][0]).length
ANKLE_Z = REST["foot_l"][0].z
HIP_Z = REST["thigh_l"][0].z
ORDER = [
    "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head",
    "upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r",
    "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r",
]


def unit(x, y, z):
    return Vector((x, y, z)).normalized()


def fwd(angle, x=0.0):
    """Direction tilted `angle` radians forward from straight down."""
    return unit(x, -math.sin(angle), -math.cos(angle))


def up_fwd(angle, x=0.0):
    """Direction tilted `angle` radians forward from straight up."""
    return unit(x, -math.sin(angle), math.cos(angle))


def leg_ik(side, foot_y, foot_z, hip_drop):
    """Thigh and calf directions putting the ankle at (forward foot_y, height foot_z)."""
    sx = 1.0 if side == "l" else -1.0
    hip = Vector((0.0, 0.0, HIP_Z - hip_drop))
    target = Vector((0.0, -foot_y, foot_z))
    v = target - hip
    dist = min(v.length, L_THIGH + L_CALF - 0.002)
    base = math.atan2(foot_y, -(foot_z - hip.z))
    cos_a = (L_THIGH**2 + dist**2 - L_CALF**2) / (2 * L_THIGH * dist)
    alpha = math.acos(max(-1.0, min(1.0, cos_a)))
    thigh = fwd(base + alpha)
    knee = hip + thigh * L_THIGH
    ankle = hip + v.normalized() * dist
    calf = (ankle - knee).normalized()
    thigh.x, calf.x = 0.09 * sx, 0.11 * sx
    return thigh.normalized(), calf.normalized()


def apply_pose(pose, pelvis_drop=0.0):
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for name in ORDER:
        pb = pbs[name]
        if name == "pelvis" and (pelvis_drop or pose.get("_sway")):
            m = pb.matrix.copy()
            m.translation.z -= pelvis_drop
            m.translation.x += pose.get("_sway", 0.0)
            pb.matrix = m
            bpy.context.view_layer.update()
        if name not in pose:
            twist = pose.get("_twist", {}).get(name, 0.0)
            if twist:
                m = pb.matrix.copy()
                rot = Matrix.Rotation(twist, 4, m.col[1].xyz.normalized()) @ Matrix(m.to_3x3()).to_4x4()
                rot.translation = m.translation
                pb.matrix = rot
                bpy.context.view_layer.update()
            continue
        m = pb.matrix.copy()
        cur = m.col[1].xyz.normalized()
        q = cur.rotation_difference(pose[name])
        rot = q.to_matrix().to_4x4() @ Matrix(m.to_3x3()).to_4x4()
        twist = pose.get("_twist", {}).get(name, 0.0)
        if twist:
            axis = rot.col[1].xyz.normalized()
            rot = Matrix.Rotation(twist, 4, axis) @ rot
        rot.translation = m.translation
        pb.matrix = rot
        bpy.context.view_layer.update()


def key_all(frame):
    for name in ORDER:
        pbs[name].keyframe_insert("rotation_quaternion", frame=frame, group=name)
    pbs["pelvis"].keyframe_insert("location", frame=frame, group="pelvis")


def arms(swing_l, bend_l, swing_r, bend_r, out=0.17):
    return {
        "upperarm_l": fwd(swing_l, out),
        "lowerarm_l": fwd(swing_l + bend_l, out * 0.5),
        "hand_l": fwd(swing_l + bend_l, out * 0.4),
        "upperarm_r": fwd(swing_r, -out),
        "lowerarm_r": fwd(swing_r + bend_r, -out * 0.5),
        "hand_r": fwd(swing_r + bend_r, -out * 0.4),
    }


def torch_arm(bob=0.0):
    """Right hand holds the flashlight out in front, at chest height."""
    return {
        "upperarm_r": unit(-0.25, -0.55, -0.8),
        "lowerarm_r": unit(-0.05, -1.0, 0.08 + bob),
        "hand_r": unit(-0.02, -1.0, 0.05 + bob),
    }


def spine(lean, twist_x=0.0, head_pitch=0.0):
    return {
        "spine_01": up_fwd(lean * 0.4),
        "spine_02": up_fwd(lean * 0.7),
        "spine_03": up_fwd(lean, twist_x),
        # The rig's neck leans ~0.37 rad forward at rest; keep that, and pitch
        # the head so the eyes stay level whatever the body lean.
        "neck_01": up_fwd(NECK_REST + lean * 0.4),
        "head": up_fwd(0.06 + head_pitch * 0.3),
    }


def foot_dir(pitch):
    return unit(0.0, -math.cos(pitch), -math.sin(pitch) - 0.08)


def gait(p, stride, stance, lift, hip, lean, arm_swing, elbow, bob, torch=True, twist=0.12, sway=0.018):
    """One frame of a walk/jog/run cycle at phase p in [0, 1).

    Left foot lands at p = 0, right at p = 0.5. Heel strikes first and the
    foot rolls to the toe; the pelvis turns with the swinging leg and sways
    over the standing one, the chest turns against it, the head stays level,
    and the free arm swings opposite its leg.
    """
    pose = spine(lean, 0.0, -lean * 0.8)
    for side, offset in (("l", 0.0), ("r", 0.5)):
        q = (p + offset) % 1.0
        if q < stance:
            t = q / stance
            y = stride * (1 - 2 * t)
            z = ANKLE_Z
            # Heel first (toe up), flat through mid-stance, then onto the toes.
            if t < 0.15:
                pitch = -0.25 * (1 - t / 0.15)
            elif t < 0.7:
                pitch = 0.05
            else:
                pitch = 0.05 + (t - 0.7) / 0.3 * 0.6
                z = ANKLE_Z + (t - 0.7) / 0.3 * 0.05
        else:
            t = (q - stance) / (1 - stance)
            y = -stride + 2 * stride * (0.5 - 0.5 * math.cos(math.pi * t))
            z = ANKLE_Z + 0.05 * (1 - t) + lift * math.sin(math.pi * t)
            pitch = 0.65 * (1 - t) ** 2 - 0.2 * t
        thigh, calf = leg_ik(side, y, z, hip)
        pose["thigh_" + side] = thigh
        pose["calf_" + side] = calf
        pose["foot_" + side] = foot_dir(pitch)
    s = math.sin(2 * math.pi * p)
    c = math.cos(2 * math.pi * p)
    # Left leg swings forward around p = 0.75, so the left arm leads at p = 0.25.
    pose.update(arms(arm_swing * s, elbow + 0.15 * max(s, 0), -arm_swing * s, elbow + 0.15 * max(-s, 0)))
    if torch:
        pose.update(torch_arm(0.04 * math.sin(4 * math.pi * p)))
    pose["_twist"] = {"pelvis": twist * -c, "spine_03": twist * 1.4 * c, "head": twist * -0.4 * c}
    pose["_sway"] = sway * c
    drop = hip + bob * (0.5 + 0.5 * math.cos(4 * math.pi * p))
    return pose, drop


def make(name, frames, fn):
    # Solve every frame with no action assigned (an assigned action would be
    # re-evaluated on each view-layer update and fight the solver), then key.
    arm.animation_data_create()
    arm.animation_data.action = None
    solved = []
    for f in range(frames + 1):
        pose, drop = fn((f % frames) / frames)
        apply_pose(pose, drop)
        solved.append({n: (pbs[n].rotation_quaternion.copy(), pbs[n].location.copy()) for n in ORDER})
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f, frame in enumerate(solved):
        for n, (rot, loc) in frame.items():
            pbs[n].rotation_quaternion = rot
            pbs[n].location = loc
        key_all(f)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, act)
    track.mute = True  # Unmuted for export; live tracks would leak into the next solve.
    arm.animation_data.action = None
    print("ANIM", name, frames)


def idle(p):
    b = math.sin(2 * math.pi * p)
    pose = spine(0.03 + 0.015 * b)
    for side, y in (("l", 0.03), ("r", -0.03)):
        thigh, calf = leg_ik(side, y, ANKLE_Z, 0.02)
        pose["thigh_" + side], pose["calf_" + side], pose["foot_" + side] = thigh, calf, foot_dir(0.05)
    pose.update(arms(0.05 + 0.02 * b, 0.25, 0.0, 0.0))
    pose.update(torch_arm(0.01 * b))
    return pose, 0.02 + 0.005 * b


def crouch_idle(p):
    b = math.sin(2 * math.pi * p)
    pose = spine(0.45 + 0.02 * b, 0.0, -0.3)
    for side, y in (("l", 0.12), ("r", -0.12)):
        thigh, calf = leg_ik(side, y, ANKLE_Z, 0.42)
        pose["thigh_" + side], pose["calf_" + side], pose["foot_" + side] = thigh, calf, foot_dir(0.0)
    pose.update(arms(0.5, 0.6, 0.0, 0.0))
    pose.update(torch_arm(0.01 * b))
    return pose, 0.42 + 0.005 * b


def downed(p):
    """Lying face down (the game tips the body forward) and dragging forward."""
    s = math.sin(2 * math.pi * p)
    pose = {
        "spine_01": up_fwd(0.0),
        "spine_02": up_fwd(0.0),
        "spine_03": up_fwd(0.0),
        "neck_01": unit(0, 0.35, 0.94),
        "head": unit(0, 0.75, 0.66),
        "upperarm_l": unit(0.35, -0.35 - 0.15 * s, 0.85 * (0.75 + 0.25 * s)),
        "lowerarm_l": unit(0.2, -0.6, 0.6 + 0.3 * s),
        "hand_l": unit(0.15, -0.8, 0.4),
        "upperarm_r": unit(-0.35, -0.35 + 0.15 * s, 0.85 * (0.75 - 0.25 * s)),
        "lowerarm_r": unit(-0.2, -0.6, 0.6 - 0.3 * s),
        "hand_r": unit(-0.15, -0.8, 0.4),
        "thigh_l": fwd(-0.05 + 0.15 * max(s, 0), 0.12),
        "calf_l": fwd(-0.05 - 0.5 * max(s, 0), 0.12),
        "thigh_r": fwd(-0.05 + 0.15 * max(-s, 0), -0.12),
        "calf_r": fwd(-0.05 - 0.5 * max(-s, 0), -0.12),
        "foot_l": unit(0.05, 0.3, -1.0),
        "foot_r": unit(-0.05, 0.3, -1.0),
    }
    return pose, 0.0


# Speeds (m/s) that each cycle is authored at, so the game can match playback.
SPEEDS = {}


def cycle(name, period, stride, stance, **kw):
    frames = round(period * FPS)
    SPEEDS[name] = round(2 * stride / (stance * frames / FPS), 3)
    make(name, frames, lambda p: gait(p, stride, stance, **kw))


make("idle", 90, idle)
cycle("walk", 0.95, 0.36, 0.6, lift=0.09, hip=0.04, lean=0.05, arm_swing=0.32, elbow=0.25, bob=0.02)
cycle("jog", 0.72, 0.42, 0.45, lift=0.18, hip=0.07, lean=0.12, arm_swing=0.45, elbow=1.15, bob=0.035, twist=0.14)
cycle("run", 0.62, 0.55, 0.38, lift=0.3, hip=0.1, lean=0.22, arm_swing=0.7, elbow=1.4, bob=0.045, twist=0.16, sway=0.012)
make("crouch_idle", 80, crouch_idle)
cycle("crouch_walk", 0.85, 0.3, 0.6, lift=0.07, hip=0.42, lean=0.45, arm_swing=0.25, elbow=0.6, bob=0.015, twist=0.08, sway=0.01)
make("downed", 60, downed)
print("SPEEDS", SPEEDS)
for track in arm.animation_data.nla_tracks:
    track.mute = False
for pb in pbs:
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)

# Game mesh: bake the shape keys and the clothing masks in, then lighten.
DECIMATE = {"body": 0.5, HAIR: float(CFG.get("hair_decimate", 0.35))}
DECIMATE.update(CFG.get("decimate", {}))
## Materials are named by role (the game alpha-cuts hair, brows, lashes, eyes).
ROLES = {"body": "skin", HAIR: "hair", "high-poly": "eyes"}
for o in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    if o.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for m in list(o.modifiers):
        if m.type == "MASK":
            bpy.ops.object.modifier_apply(modifier=m.name)
    key = o.name.split(".", 1)[1]
    if key in DECIMATE:
        dec = o.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = DECIMATE[key]
        bpy.ops.object.modifier_move_to_index(modifier=dec.name, index=0)
        bpy.ops.object.modifier_apply(modifier=dec.name)
    # Simple glTF-friendly material: one base colour texture (+ its alpha).
    for i, mat in enumerate(o.data.materials):
        imgs = [n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
        diffuse = next((im for im in imgs if "normal" not in im.name and "_ao" not in im.name), None)
        role = ROLES.get(key, key)
        if key.startswith("eyebrow"):
            role = "eyebrows"
        elif key.startswith("eyelashes"):
            role = "eyelashes"
        new = bpy.data.materials.new(NAME + "_" + role)
        new.use_nodes = True
        nt = new.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.85 if key != "high-poly" else 0.25
        if diffuse is None:
            # Untextured parts (a cap): keep the original flat colour.
            for n in mat.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    bsdf.inputs["Base Color"].default_value = n.inputs["Base Color"].default_value
        if diffuse:
            if max(diffuse.size) > 1024 and key != "body":
                diffuse.scale(1024, 1024)
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = diffuse
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            if "hair" in role or role in ("eyebrows", "eyelashes"):
                nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
                new.surface_render_method = "BLENDED"
        o.data.materials[i] = new
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("MESH", o.name, "tris", tris)

bpy.ops.object.select_all(action="SELECT")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    use_selection=True,
    export_apply=False,
    export_skins=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_optimize_animation_size=True,
    export_image_format="WEBP",
    export_image_quality=88,
    export_morph=False,
    export_yup=True,
)
print("EXPORTED", OUT, os.path.getsize(OUT))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, "game.blend"))
