"""Turns a third-party monster model into a game-ready GLB for one map.

blender -b --python build_monster.py -- <monsters.json> <id> <source_root> <out.glb>

For each entry in monsters.json:
- import the FBX and relink textures whose files were renamed;
- simplify the mesh to the mobile budget (and textures to 1024 px);
- rigged models: rename their own animations to the game's clip names;
- unrigged models: build a humanoid skeleton fitted to the mesh, skin it,
  and write the clips procedurally (menacing walk, sprint, search, roar,
  wind-up, strike, flinch, door push);
- export with the clips the game plays: idle, walk, run, search, alert,
  windup, strike, recover, hit, open_door.
Prints MONSTER <id> height=<m> so the catalog can scale it to its target.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

CFG_PATH, MID, SRC, OUT = sys.argv[sys.argv.index("--") + 1 :][:4]
CFG = json.load(open(CFG_PATH, encoding="utf-8"))[MID]
CLIPS = ["idle", "walk", "run", "search", "alert", "windup", "strike", "recover", "hit", "open_door"]
FPS = 30

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
src_file = os.path.join(SRC, CFG["file"])
bpy.ops.import_scene.fbx(filepath=src_file, automatic_bone_orientation=False)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
for o in meshes:
    if o.name in CFG.get("drop_meshes", []):
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]

# --- Textures --------------------------------------------------------------------
tex_dir = os.path.join(SRC, CFG.get("texture_dir", os.path.dirname(CFG["file"])))
relink = CFG.get("relink", {})
for img in list(bpy.data.images):
    if img.source != "FILE":
        continue
    path = bpy.path.abspath(img.filepath)
    if os.path.exists(path):
        continue
    name = os.path.basename(path)
    target = relink.get(name) or relink.get("*")
    if target:
        img.filepath = os.path.join(tex_dir, target)
        img.reload()
        print("RELINK", name, "->", target)
tint = CFG.get("tint")
for img in bpy.data.images:
    if tint and img.source == "FILE" and img.size[0] > 0:
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        lum = px[:, :3].mean(axis=1, keepdims=True)
        sat = float(CFG.get("saturation", 1.0))
        px[:, :3] = (lum + (px[:, :3] - lum) * sat) * np.array(tint, dtype=np.float32)
        img.pixels.foreach_set(px.ravel())
        img.update()
        print("TINT", img.name)
for img in bpy.data.images:
    if img.size[0] > 1024 and img.has_data:
        img.scale(1024, int(1024 * img.size[1] / img.size[0]))

# --- Mesh budget -------------------------------------------------------------------
budget = int(CFG.get("triangles", 14000))
for o in meshes:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    share = budget * tris / max(1, sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes))
    if tris > share * 1.05:
        bpy.context.view_layer.objects.active = o
        for x in bpy.data.objects:
            x.select_set(x == o)
        dec = o.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = share / tris
        if arms:
            bpy.ops.object.modifier_move_to_index(modifier=dec.name, index=0)
        bpy.ops.object.modifier_apply(modifier=dec.name)
        print("DECIMATE", o.name, tris, "->", sum(len(p.vertices) - 2 for p in o.data.polygons))


def world_points(objs):
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        m = o.evaluated_get(dg).to_mesh()
        pts += [tuple(o.matrix_world @ v.co) for v in m.vertices]
    return np.array(pts)


# =================================================================================
# Rigged: map the model's own clips.
# =================================================================================
def map_rigged():
    arm = arms[0]
    arm.animation_data_create()
    by_name = {a.name.split("|")[-1].strip(): a for a in bpy.data.actions}
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    for clip, src_name in CFG["clips"].items():
        act = by_name.get(src_name)
        if act is None:
            print("MISSING CLIP", clip, src_name)
            continue
        new = act.copy()
        new.name = clip
        track = arm.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, int(act.frame_range[0]), new)
        track.mute = True
    arm.animation_data.action = None
    for t in arm.animation_data.nla_tracks:
        t.mute = False
    print("CLIPS", [t.name for t in arm.animation_data.nla_tracks])


# =================================================================================
# Unrigged: fit a humanoid skeleton, skin it, write the clips.
# =================================================================================
BONES = [
    ("pelvis", None), ("spine_01", "pelvis"), ("spine_02", "spine_01"), ("spine_03", "spine_02"),
    ("neck_01", "spine_03"), ("head", "neck_01"),
    ("upperarm_l", "spine_03"), ("lowerarm_l", "upperarm_l"), ("hand_l", "lowerarm_l"),
    ("upperarm_r", "spine_03"), ("lowerarm_r", "upperarm_r"), ("hand_r", "lowerarm_r"),
    ("thigh_l", "pelvis"), ("calf_l", "thigh_l"), ("foot_l", "calf_l"),
    ("thigh_r", "pelvis"), ("calf_r", "thigh_r"), ("foot_r", "calf_r"),
]


def fit_skeleton(pts):
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    H = hi[2] - lo[2]
    z0 = lo[2]
    cx = float(np.median(pts[:, 0]))
    cy = float(np.median(pts[(pts[:, 2] > z0 + 0.4 * H) & (pts[:, 2] < z0 + 0.7 * H)][:, 1]))

    def zh(f):
        return z0 + f * H

    body = {}
    body["pelvis"] = (Vector((cx, cy, zh(0.52))), Vector((cx, cy, zh(0.58))))
    body["spine_01"] = (body["pelvis"][1], Vector((cx, cy, zh(0.64))))
    body["spine_02"] = (body["spine_01"][1], Vector((cx, cy, zh(0.71))))
    body["spine_03"] = (body["spine_02"][1], Vector((cx, cy, zh(0.8))))
    body["neck_01"] = (body["spine_03"][1], Vector((cx, cy - 0.01 * H, zh(0.86))))
    body["head"] = (body["neck_01"][1], Vector((cx, cy - 0.01 * H, zh(0.98))))
    sh_z = zh(0.81)
    t_pose = (hi[0] - lo[0]) > 0.75 * H
    for side, sx in (("l", 1.0), ("r", -1.0)):
        sh = Vector((cx + sx * 0.11 * H, cy, sh_z))
        if t_pose:
            # Arms out: hands at the far ends of the mesh at shoulder height.
            arm_pts = pts[(sx * (pts[:, 0] - cx) > 0.3 * H) & (np.abs(pts[:, 2] - sh_z) < 0.12 * H)]
            tip = arm_pts[np.argmax(sx * (arm_pts[:, 0] - cx))] if len(arm_pts) else (cx + sx * 0.45 * H, cy, sh_z)
            hand = Vector((tip[0] - sx * 0.07 * H, cy, sh_z - 0.01 * H))
        else:
            # Arms down: the lowest point of the outer upper body is the hand.
            arm_pts = pts[(sx * (pts[:, 0] - cx) > 0.13 * H) & (pts[:, 2] > zh(0.3)) & (pts[:, 2] < zh(0.78))]
            tip = arm_pts[np.argmin(arm_pts[:, 2])] if len(arm_pts) else (cx + sx * 0.2 * H, cy, zh(0.42))
            hand = Vector((tip[0], tip[1], tip[2] + 0.07 * H))
        elbow = sh.lerp(hand, 0.5) + Vector((0, 0.02 * H, 0))
        body["upperarm_" + side] = (sh, elbow)
        body["lowerarm_" + side] = (elbow, hand)
        body["hand_" + side] = (hand, hand + (hand - elbow).normalized() * 0.08 * H)
        hip = Vector((cx + sx * 0.055 * H, cy, zh(0.5)))
        knee = Vector((cx + sx * 0.06 * H, cy - 0.01 * H, zh(0.27)))
        ankle = Vector((cx + sx * 0.065 * H, cy + 0.01 * H, zh(0.045)))
        body["thigh_" + side] = (hip, knee)
        body["calf_" + side] = (knee, ankle)
        body["foot_" + side] = (ankle, Vector((ankle.x, ankle.y - 0.08 * H, z0 + 0.01 * H)))
    return body, H, t_pose


def build_armature(body):
    arm_data = bpy.data.armatures.new(CFG["name"] + "_rig")
    arm = bpy.data.objects.new(CFG["name"], arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for x in bpy.data.objects:
        x.select_set(x == arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for name, parent in BONES:
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = body[name]
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        eb[name] = b
    # Roll so every bone's local Z points the same way (forward = -Y).
    for b in arm_data.edit_bones:
        b.align_roll(Vector((0, -1, 0)) if abs(b.vector.normalized().y) < 0.9 else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(mesh_obj, arm, body, t_pose=False):
    """Weights by distance to each bone segment, limbs kept to their own side."""
    segs = {n: (np.array(tuple(body[n][0])), np.array(tuple(body[n][1]))) for n, _ in BONES}
    groups = {n: mesh_obj.vertex_groups.new(name=n) for n, _ in BONES}
    pts = np.array([tuple(mesh_obj.matrix_world @ v.co) for v in mesh_obj.data.vertices])
    cx = float(np.median(pts[:, 0]))
    dists = {}
    for n, (a, b) in segs.items():
        ab = b - a
        tt = np.clip(((pts - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
        d = np.linalg.norm(pts - (a + tt[:, None] * ab), axis=1)
        side = n[-2:]
        # Arms only take what is close to them (not a coat hanging beside them).
        if "arm" in n or n.startswith("hand"):
            # In a T-pose the arms stand clear of the body: baggy sleeves belong to them.
            reach = float(CFG.get("arm_reach", 0.16 if t_pose else 0.05))
            d = np.where(d > reach * (pts[:, 2].max() - pts[:, 2].min()), d + 10.0, d)
        if side == "_l":
            d = np.where(pts[:, 0] < cx - 0.01, d + 10.0, d)
        elif side == "_r":
            d = np.where(pts[:, 0] > cx + 0.01, d + 10.0, d)
        dists[n] = d
    names = list(dists)
    D = np.stack([dists[n] for n in names], axis=1)
    order = np.argsort(D, axis=1)[:, :3]
    for vi in range(len(pts)):
        idx = order[vi]
        dd = D[vi, idx]
        w = 1.0 / np.maximum(dd, 1e-4) ** 4
        w = w / w.sum()
        for k in range(3):
            if w[k] > 0.02:
                groups[names[idx[k]]].add([vi], float(w[k]), "REPLACE")
    mesh_obj.parent = arm
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ---- procedural clips (bone directions in armature space; the body faces -Y) ----
def unit(x, y, z):
    return Vector((x, y, z)).normalized()


def down_fwd(a, x=0.0):
    return unit(x, -math.sin(a), -math.cos(a))


def up_fwd(a, x=0.0):
    return unit(x, -math.sin(a), math.cos(a))


def make_clips(arm, body, H):
    pbs = arm.pose.bones
    order = [n for n, _ in BONES]
    rest = {n: (body[n][0].copy(), body[n][1].copy()) for n in order}
    l_th = (rest["thigh_l"][1] - rest["thigh_l"][0]).length
    l_ca = (rest["calf_l"][1] - rest["calf_l"][0]).length
    hip_z = rest["thigh_l"][0].z
    ankle_z = rest["foot_l"][0].z
    hunch = float(CFG.get("hunch", 0.25))

    def leg(side, fy, fz, drop):
        sx = 1.0 if side == "l" else -1.0
        hip = Vector((0, 0, hip_z - drop))
        v = Vector((0, -fy, fz)) - hip
        dist = min(v.length, l_th + l_ca - 0.002)
        base = math.atan2(fy, -(fz - hip.z))
        ca = (l_th ** 2 + dist ** 2 - l_ca ** 2) / (2 * l_th * dist)
        th = down_fwd(base + math.acos(max(-1, min(1, ca))))
        knee = hip + th * l_th
        calf = (hip + v.normalized() * dist - knee).normalized()
        th.x, calf.x = 0.06 * sx, 0.06 * sx
        return th.normalized(), calf.normalized()

    def apply(pose, drop=0.0, sway=0.0, twist=None):
        twist = twist or {}
        for pb in pbs:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        bpy.context.view_layer.update()
        for name in order:
            pb = pbs[name]
            if name == "pelvis" and (drop or sway):
                m = pb.matrix.copy()
                m.translation.z -= drop
                m.translation.x += sway
                pb.matrix = m
                bpy.context.view_layer.update()
            m = pb.matrix.copy()
            rot = Matrix(m.to_3x3()).to_4x4()
            if name in pose:
                q = m.col[1].xyz.normalized().rotation_difference(pose[name])
                rot = q.to_matrix().to_4x4() @ rot
            if twist.get(name):
                rot = Matrix.Rotation(twist[name], 4, rot.col[1].xyz.normalized()) @ rot
            rot.translation = m.translation
            pb.matrix = rot
            bpy.context.view_layer.update()

    def torso(lean, head=0.0, turn=0.0):
        return {
            "spine_01": up_fwd(lean * 0.4), "spine_02": up_fwd(lean * 0.7), "spine_03": up_fwd(lean),
            "neck_01": up_fwd(lean * 0.9 + 0.1), "head": up_fwd(lean * 0.4 + head, turn),
        }

    def arms_down(fl, fr, bend_l=0.3, bend_r=0.3, out=0.18):
        return {
            "upperarm_l": down_fwd(fl, out), "lowerarm_l": down_fwd(fl + bend_l, out * 0.6),
            "hand_l": down_fwd(fl + bend_l, out * 0.5),
            "upperarm_r": down_fwd(fr, -out), "lowerarm_r": down_fwd(fr + bend_r, -out * 0.6),
            "hand_r": down_fwd(fr + bend_r, -out * 0.5),
        }

    def stand(pose, drop=0.03, spread=0.06):
        for side, y in (("l", spread), ("r", -spread * 0.5)):
            th, ca = leg(side, y, ankle_z, drop)
            pose["thigh_" + side], pose["calf_" + side] = th, ca
            pose["foot_" + side] = unit(0, -1, -0.1)
        return pose

    def gait(p, stride, stance, lift, drop, lean, swing, elbow, bob, drag=0.0):
        pose = torso(lean, -lean * 0.5)
        for side, off in (("l", 0.0), ("r", 0.5)):
            q = (p + off) % 1.0
            # A dragging gait: one foot scuffs low and lands late (drag > 0).
            lft = lift * (1.0 - drag if side == "r" else 1.0)
            if q < stance:
                t = q / stance
                y, z = stride * (1 - 2 * t), ankle_z
                pitch = -0.2 * (1 - t / 0.15) if t < 0.15 else (0.05 if t < 0.7 else 0.05 + (t - 0.7) / 0.3 * 0.5)
            else:
                t = (q - stance) / (1 - stance)
                y = -stride + 2 * stride * (0.5 - 0.5 * math.cos(math.pi * t))
                z = ankle_z + lft * math.sin(math.pi * t)
                pitch = 0.5 * (1 - t) - 0.15 * t
            th, ca = leg(side, y, z, drop)
            pose["thigh_" + side], pose["calf_" + side] = th, ca
            pose["foot_" + side] = unit(0, -math.cos(pitch), -math.sin(pitch) - 0.08)
        s = math.sin(2 * math.pi * p)
        pose.update(arms_down(swing * s, -swing * s, elbow, elbow))
        c = math.cos(2 * math.pi * p)
        tw = {"pelvis": -0.12 * c, "spine_03": 0.16 * c, "head": -0.06 * c}
        return pose, drop + bob * (0.5 + 0.5 * math.cos(4 * math.pi * p)), 0.015 * c * H, tw

    clips = {}
    clips["idle"] = (90, lambda p: (stand({**torso(hunch + 0.03 * math.sin(2 * math.pi * p), 0.1 * math.sin(4 * math.pi * p), 0.15 * math.sin(2 * math.pi * p)), **arms_down(0.05, 0.08, 0.3, 0.35)}), 0.03, 0.0, {}))
    clips["walk"] = (round(1.3 * FPS), lambda p: gait(p, 0.17 * H, 0.62, 0.05 * H, 0.03 * H, hunch, 0.22, 0.35, 0.012 * H, drag=float(CFG.get("drag", 0.4))))
    clips["run"] = (round(0.62 * FPS), lambda p: gait(p, 0.3 * H, 0.38, 0.16 * H, 0.06 * H, hunch + 0.25, 0.75, 1.3, 0.025 * H))

    def search(p):
        a = 2 * math.pi * p
        pose = stand({**torso(hunch + 0.1, -0.15, 0.6 * math.sin(a)), **arms_down(0.15, 0.25, 0.4, 0.5)}, 0.05)
        return pose, 0.05, 0.0, {"spine_03": 0.35 * math.sin(a), "head": 0.5 * math.sin(a)}

    clips["search"] = (round(3.0 * FPS), search)

    def alert(p):
        k = min(1.0, p * 3.0)
        pose = stand({**torso(hunch - 0.25 * k, 0.25 * k), **arms_down(0.4 * k, 0.4 * k, 0.9 * k, 0.9 * k, 0.5 * k + 0.18)}, 0.06 * k)
        return pose, 0.06 * k, 0.0, {}

    clips["alert"] = (round(1.1 * FPS), alert)

    def windup(p):
        k = 0.5 - 0.5 * math.cos(math.pi * p)
        pose = stand({**torso(hunch - 0.2 * k, 0.1, -0.2 * k), **arms_down(0.1, -0.6 - 1.8 * k, 0.3, 0.6 + 0.6 * k, 0.25)}, 0.08 * k)
        pose["upperarm_r"] = unit(-0.4, 0.3 * k, -0.6 + 1.6 * k)
        return pose, 0.08 * k, 0.0, {"spine_03": -0.4 * k}

    clips["windup"] = (round(0.7 * FPS), windup)

    def strike(p):
        k = min(1.0, p * 2.5)
        pose = stand({**torso(hunch + 0.35 * k, -0.1, 0.25 * k), **arms_down(0.2, 2.1 - 1.6 * k, 0.3, 0.3)}, 0.1)
        pose["upperarm_r"] = unit(-0.25, -0.9 * k, 1.0 - 1.4 * k)
        return pose, 0.1, 0.0, {"spine_03": 0.45 * k}

    clips["strike"] = (round(0.5 * FPS), strike)
    clips["recover"] = (round(0.8 * FPS), lambda p: (stand({**torso(hunch + 0.2 * (1 - p), 0.0), **arms_down(0.1, 0.4 * (1 - p), 0.3, 0.4)}, 0.06), 0.06, 0.0, {}))

    def hit(p):
        k = math.sin(math.pi * min(1.0, p * 1.5))
        pose = stand({**torso(hunch - 0.35 * k, 0.3 * k), **arms_down(-0.3 * k, -0.3 * k, 0.6, 0.6, 0.3)}, 0.04)
        return pose, 0.04, 0.0, {}

    clips["hit"] = (round(0.6 * FPS), hit)

    def door(p):
        k = math.sin(math.pi * p)
        pose = stand({**torso(hunch + 0.1 * k, 0.0), **arms_down(0.1, 0.3 + 1.2 * k, 0.3, 0.2)}, 0.04)
        pose["upperarm_r"] = unit(-0.2, -0.3 - 0.7 * k, -0.8 + 0.6 * k)
        pose["lowerarm_r"] = unit(-0.1, -0.5 - 0.5 * k, -0.6 + 0.6 * k)
        return pose, 0.04, 0.0, {}

    clips["open_door"] = (round(1.0 * FPS), door)

    arm.animation_data_create()
    for name in CLIPS:
        frames, fn = clips[name]
        arm.animation_data.action = None
        for t in arm.animation_data.nla_tracks:
            t.mute = True
        solved = []
        for f in range(frames + 1):
            pose, drop, sway, tw = fn((f % frames) / frames)
            apply(pose, drop, sway, tw)
            solved.append({n: (pbs[n].rotation_quaternion.copy(), pbs[n].location.copy()) for n in order})
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        for f, fr in enumerate(solved):
            for n, (rq, loc) in fr.items():
                pbs[n].rotation_quaternion = rq
                pbs[n].location = loc
                pbs[n].keyframe_insert("rotation_quaternion", frame=f, group=n)
            pbs["pelvis"].keyframe_insert("location", frame=f, group="pelvis")
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act)
        tr.mute = True
        arm.animation_data.action = None
    for t in arm.animation_data.nla_tracks:
        t.mute = False
    for pb in pbs:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    print("CLIPS", [t.name for t in arm.animation_data.nla_tracks])


# =================================================================================
if arms:
    map_rigged()
    pts = world_points(meshes)
else:
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        for x in bpy.data.objects:
            x.select_set(x == o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.context.view_layer.objects.active = meshes[0]
        for x in bpy.data.objects:
            x.select_set(x in meshes)
        bpy.ops.object.join()
        meshes = [bpy.context.view_layer.objects.active]
    # Feet on the floor, centred over the origin.
    pts = world_points(meshes)
    shift = Vector((-float(np.median(pts[:, 0])), -float(np.median(pts[:, 1])), -float(pts[:, 2].min())))
    meshes[0].data.transform(Matrix.Translation(shift))
    pts = world_points(meshes)
    body, H, t_pose = fit_skeleton(pts)
    print("SKELETON fitted, height %.2f, %s" % (H, "T-pose" if t_pose else "arms down"))
    arm = build_armature(body)
    skin(meshes[0], arm, body, t_pose)
    make_clips(arm, body, H)
    arms = [arm]

height = float(pts[:, 2].max() - pts[:, 2].min())
for o in bpy.data.objects:
    o.select_set(o.type in ("MESH", "ARMATURE"))
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
    export_def_bones=bool(CFG.get("deform_bones_only", False)),
    export_optimize_animation_size=True,
    export_image_format="WEBP",
    export_image_quality=85,
    export_morph=False,
    export_yup=True,
)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("MONSTER %s height=%.3f tris=%d size=%d" % (MID, height, tris, os.path.getsize(OUT)))
bpy.ops.wm.save_as_mainfile(filepath=OUT[:-4] + ".blend")
