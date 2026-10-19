"""Drops textures that have no image (and references to them) from GLB files (in place).

python fix_glb.py <file.glb> [...]

Blender can export a texture slot whose image it failed to pack (Poly Haven's
sofa_03 roughness map); Godot then refuses the whole file.
"""
import json
import struct
import sys


def fix(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20 : 20 + n])
    textures = doc.get("textures", [])
    bad = {i for i, t in enumerate(textures) if "source" not in t and not any(
        "source" in e for e in t.get("extensions", {}).values())}
    if not bad:
        return False

    def strip(node):
        if isinstance(node, dict):
            for key in [k for k, v in node.items() if isinstance(v, dict) and v.get("index") in bad and k.endswith("Texture")]:
                del node[key]
            for v in node.values():
                strip(v)
        elif isinstance(node, list):
            for v in node:
                strip(v)

    strip(doc.get("materials", []))
    # Godot parses every texture, used or not: remove them and renumber.
    remap = {}
    for i in range(len(textures)):
        if i not in bad:
            remap[i] = len(remap)
    doc["textures"] = [t for i, t in enumerate(textures) if i not in bad]

    def renumber(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if isinstance(v, dict) and k.endswith("Texture") and "index" in v:
                    v["index"] = remap[v["index"]]
                renumber(v)
        elif isinstance(node, list):
            for v in node:
                renumber(v)

    renumber(doc.get("materials", []))
    chunk = json.dumps(doc, separators=(",", ":")).encode()
    chunk += b" " * (-len(chunk) % 4)
    rest = data[20 + n :]
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(chunk) + len(rest))
    out += struct.pack("<I4s", len(chunk), b"JSON") + chunk + rest
    open(path, "wb").write(out)
    return True


for p in sys.argv[1:]:
    if fix(p):
        print("fixed", p)
