"""Patch a .rigby work file (ZIP with project.json + images/) for things the CLI/MCP tools can't do:
  - move a slot onto another bone (keeps the image where it is on screen)
  - set a slot's blend mode (normal / additive / multiply / screen)
  - add film effects: glow layers and particle emitters (doc.film, see src/core/filmfx.js)

Usage: python -I patch_rigby.py <in.rigby> <out.rigby> <patch.json>
patch.json:
  {"reparent": {"slot": "bone", ...},
   "blend": {"slot": "additive", ...},
   "top": {"textureFilter": "nearest", "pixelGrid": 1},
   "film": {"layers": [...], "emitters": [...]}}   # merged into project.json "film"
"""
import json, math, sys, zipfile


def world(bones):
    """World (x, y, rot) of each bone; assumes scale 1 / no shear (fine for fresh rigs)."""
    out = []
    for b in bones:
        x, y, r = b.get("x", 0), b.get("y", 0), b.get("rotation", 0)
        p = b.get("parent")
        if p is None:
            out.append((x, y, r))
            continue
        px, py, pr = out[p]
        c, s = math.cos(math.radians(pr)), math.sin(math.radians(pr))
        out.append((px + c * x - s * y, py + s * x + c * y, pr + r))
    return out


def main(src, dst, patch_file):
    patch = json.load(open(patch_file, encoding="utf-8"))
    with zipfile.ZipFile(src) as z:
        files = {n: z.read(n) for n in z.namelist()}
    doc = json.loads(files["project.json"])
    names = [b["name"] for b in doc["bones"]]
    w = world(doc["bones"])
    for slot in doc["slots"]:
        target = patch.get("reparent", {}).get(slot["name"])
        if target:
            ox, oy, orot = w[slot["bone"]]
            nb = names.index(target)
            nx, ny, nrot = w[nb]
            for a in slot["attachments"]:
                if "x" not in a:
                    continue  # meshes etc. not handled here
                c, s = math.cos(math.radians(orot)), math.sin(math.radians(orot))
                wx, wy = ox + c * a["x"] - s * a["y"], oy + s * a["x"] + c * a["y"]
                dx, dy = wx - nx, wy - ny
                c, s = math.cos(math.radians(-nrot)), math.sin(math.radians(-nrot))
                a["x"], a["y"] = c * dx - s * dy, s * dx + c * dy
                a["rotation"] = a.get("rotation", 0) + orot - nrot
            slot["bone"] = nb
        mode = patch.get("blend", {}).get(slot["name"])
        if mode:
            slot["blend"] = mode
    # top-level fields, e.g. {"textureFilter": "nearest", "pixelGrid": 1} for pixel art
    doc.update(patch.get("top", {}))
    if "film" in patch:
        film = doc.get("film") or {}
        for k, v in patch["film"].items():
            film[k] = (film.get(k) or []) + v if isinstance(v, list) else v
        doc["film"] = film
    files["project.json"] = json.dumps(doc, ensure_ascii=False, indent=1).encode("utf-8")
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for n, data in files.items():
            z.writestr(n, data)
    print("patched", dst)


if __name__ == "__main__":
    main(*sys.argv[1:4])
