# Crea in Blender una PERSONA VERA del gioco (Matteo, Broski) uguale a quella di actors/character_model.gd,
# con le foto "cotte" in texture UV vere (così il modello si può aprire, ritoccare ed esportare).
#
# Uso (da Git Bash, nella cartella StanzaFPS):
#   "/c/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --factory-startup \
#       --python tools/blender_persona.py -- --look=matteo
# Opzioni dopo "--":
#   --look=nome      chiave di LOOKS in scripts/data/looks.gd (default matteo)
#   --render         salva anche un'anteprima (davanti, 3/4, fianco, dietro) in ../blender/<nome>_anteprima.png
#   --testa          salva un primo piano della testa da 5 angoli in ../blender/<nome>_primo_piano.png
#
# Risultato:
#   ../blender/<nome>.blend           file da aprire in Blender (texture incluse)
#   ../blender/<nome>_*.png           texture cotte (testa, busto, gambe)
#   modelli/<nome>.glb                da usare nel gioco (stessa gerarchia di character_model.gd)
#
# Le misure e i colori vengono letti da scripts/data/looks.gd: se cambi lì, rilancia questo script.
# Tutto in metri di gioco (omino = 1,8 m). In Blender Z è in alto e la persona guarda verso +Y
# (= -Z di Godot, quindi nel gioco guarda nella direzione giusta).

import math
import os
import re
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import blender_testa as BT    # noqa: E402  testa anatomica (naso, orbite, labbra, orecchie)
PROJ = os.path.dirname(HERE)                         # StanzaFPS
OUT_BLEND = os.path.join(os.path.dirname(PROJ), "blender")
OUT_GLB = os.path.join(PROJ, "modelli")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {a[2:].split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in args if a.startswith("--")}
LOOK = opt.get("look", "matteo")


# ------------------------------------------------------------------ lettura di looks.gd
def read_look(name):
    src = open(os.path.join(PROJ, "scripts", "data", "looks.gd"), encoding="utf-8").read()
    start = src.index('"%s": {' % name) + len('"%s": ' % name)
    depth = 0
    for i in range(start, len(src)):
        depth += {"{": 1, "}": -1}.get(src[i], 0)
        if depth == 0:
            block = src[start:i + 1]
            break
    block = re.sub(r"#[^\n]*", "", block)
    block = block.replace("Color(", "(").replace("true", "True").replace("false", "False")
    return eval(block)


LK = read_look(LOOK)
WHO = LK["photos"]


# ------------------------------------------------------------------ forme
def ring_pts(r, ang, n):
    """Punti (x, y, z) di Godot di un anello [y, mezza larg., mezza prof., sposta z] agli angoli ang."""
    c, s = np.cos(ang), np.sin(ang)
    x = np.sign(c) * np.abs(c) ** (2.0 / n) * r[1]
    z = np.sign(s) * np.abs(s) ** (2.0 / n) * r[2] + r[3]
    return np.stack([x, np.full_like(ang, r[0]), z], -1)


def ring_t(rings):
    """Posizione 0..1 di ogni anello lungo il profilo (per la coordinata v della texture)."""
    d = [0.0]
    for a, b in zip(rings, rings[1:]):
        d.append(d[-1] + math.hypot(b[0] - a[0], max(b[1], b[2]) - max(a[1], a[2])) + 1e-6)
    return np.array(d) / d[-1]


V0 = 0.04   # sotto questa v la texture è il colore "top" (per i tappi)


def loft(rings, n=2.4, open_=False, seg=32):
    """Come _loft di character_model.gd. Ritorna (verts, faces, uvs per faccia)."""
    ang = 2 * math.pi * np.arange(seg) / seg
    verts = [p for r in rings for p in ring_pts(r, ang, n)]
    t = ring_t(rings)
    faces, uvs = [], []
    nr = len(rings)
    for j in range(nr - 1):
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((j * seg + i, j * seg + i1, (j + 1) * seg + i1, (j + 1) * seg + i))
            v0, v1 = V0 + (1 - V0) * t[j], V0 + (1 - V0) * t[j + 1]
            uvs.append(((i / seg, v0), ((i + 1) / seg, v0), ((i + 1) / seg, v1), (i / seg, v1)))
    if not open_:
        cb = len(verts)
        verts.append(np.array([0, rings[0][0], rings[0][3]]))
        verts.append(np.array([0, rings[-1][0], rings[-1][3]]))
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((cb, i1, i))
            faces.append((cb + 1, (nr - 1) * seg + i, (nr - 1) * seg + i1))
            uvs += [((i / seg, 0.01),) * 3] * 2
    return np.array(verts), faces, uvs


def capsule(frm, to, r):
    """Capsula tra due punti (coordinate di Godot), come _limb."""
    frm, to = Vector(frm), Vector(to)
    d = to - frm
    h = d.length / 2
    rings = []
    for k in range(7):                                   # mezza sfera sotto
        a = -math.pi / 2 + k * math.pi / 12
        rings.append([-h + r * math.sin(a), r * math.cos(a) + 1e-4, r * math.cos(a) + 1e-4, 0])
    for k in range(6, 13):                               # mezza sfera sopra
        a = -math.pi / 2 + k * math.pi / 12
        rings.append([h + r * math.sin(a), r * math.cos(a) + 1e-4, r * math.cos(a) + 1e-4, 0])
    v, f, uv = loft(rings, 2.0, seg=20)
    q = Vector((0, 1, 0)).rotation_difference(d.normalized())
    mid = frm + d * 0.5
    v = np.array([tuple(q @ Vector(p) + mid) for p in v])
    return v, f, uv


def ellipsoid(center, rad, half_h, rot_x):
    rings = []
    for k in range(13):
        a = -math.pi / 2 + k * math.pi / 12
        rings.append([half_h * math.sin(a), rad * math.cos(a) + 1e-4, rad * math.cos(a) + 1e-4, 0])
    v, f, uv = loft(rings, 2.0, seg=20)
    m = Matrix.Rotation(rot_x, 3, "X")
    v = np.array([tuple(m @ Vector(p) + Vector(center)) for p in v])
    return v, f, uv


# ------------------------------------------------------------------ foto -> texture (come PHOTO_SHADER)
def load_rgba(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]   # riga 0 = in alto
    bpy.data.images.remove(img)
    return a


def sample(img, u, v, clamp_v=False):
    h, w = img.shape[:2]
    x = np.clip(u * w - 0.5, 0, w - 1)
    y = np.clip(v * h - 0.5, 0, h - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, w - 1), np.minimum(y0 + 1, h - 1)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    top = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    bot = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    out = top * (1 - fy) + bot * fy
    outside = (u < 0) | (u > 1) | (v < 0) | ((v > 1) & (not clamp_v))
    out = np.where(outside, 0, 1)[..., None] * out   # repeat_disable
    return out


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def bake_photo(rings, n, part, top, W, H, mirror=False, front_end=0.75, sharp_top=0.75):
    """Texture W x H della forma: per ogni texel calcola punto e normale sulla superficie e mescola le foto."""
    views = {k: load_rgba(os.path.join(PROJ, "textures", "persone", "%s_%s_%s.png" % (WHO, part, k)))
             for k in ("front", "back", "side")}
    # ingombro come mesh.get_aabb() con 32 segmenti
    bv, _, _ = loft(rings, n)
    bmin, bmax = bv.min(0), bv.max(0)
    s = bmax - bmin
    # griglia fine: anelli x angoli, normali lisce
    ang = 2 * math.pi * (np.arange(W) + 0.5) / W
    P = np.stack([ring_pts(r, ang, n) for r in rings])            # (nr, W, 3)
    dth = np.roll(P, -1, 1) - np.roll(P, 1, 1)
    dj = np.empty_like(P)
    dj[1:-1] = P[2:] - P[:-2]
    dj[0], dj[-1] = P[1] - P[0], P[-1] - P[-2]
    N = np.cross(dth, dj)
    # verso fuori: dall'asse dell'anello (0, y, spostamento z) verso il punto
    axis = np.zeros_like(P)
    axis[..., 1] = P[..., 1]
    axis[..., 2] = np.array([r[3] for r in rings])[:, None]
    flip = np.sign(np.sum(N * (P - axis), -1, keepdims=True))
    N = N * np.where(flip == 0, 1, flip)
    N /= np.linalg.norm(N, axis=-1, keepdims=True) + 1e-9
    # riga della texture -> anello + frazione
    t = ring_t(rings)
    vv = ((np.arange(H) + 0.5) / H - V0) / (1 - V0)               # 0 in basso, 1 in alto
    j = np.clip(np.searchsorted(t, vv, side="right") - 1, 0, len(rings) - 2)
    f = np.clip((vv - t[j]) / (t[j + 1] - t[j]), 0, 1)[:, None, None]
    p = P[j] * (1 - f) + P[j + 1] * f                               # (H, W, 3)
    nn = N[j] * (1 - f) + N[j + 1] * f
    nn /= np.linalg.norm(nn, axis=-1, keepdims=True) + 1e-9

    v = np.clip((bmax[1] - p[..., 1]) / s[1], 0, 1)
    uf = (bmax[0] - p[..., 0]) / s[0]
    ub = (p[..., 0] - bmin[0]) / s[0]
    if mirror:
        uf, ub = 1 - uf, 1 - ub
    cf = sample(views["front"], uf, v)
    cb = sample(views["back"], ub, v)
    cs = sample(views["side"], (bmax[2] - p[..., 2]) / s[2], v)
    a = np.arctan2(np.abs(nn[..., 0]), -nn[..., 2]) / (math.pi / 2)
    wf = (1 - smoothstep(front_end, front_end + 0.3, a)) * cf[..., 3]
    wb = smoothstep(2 - front_end - 0.3, 2 - front_end, a) * cb[..., 3]
    ws = (1 - smoothstep(0.25, 0.55, np.abs(a - 1))) * cs[..., 3] * 0.999
    wsum = wf + wb + ws
    c = (cf[..., :3] * wf[..., None] + cb[..., :3] * wb[..., None] + cs[..., :3] * ws[..., None]) \
        / np.maximum(wsum, 1e-4)[..., None]
    topc = np.array(top[:3], dtype=np.float32)
    c = topc * (1 - smoothstep(0, 0.25, wsum))[..., None] + c * smoothstep(0, 0.25, wsum)[..., None]
    wt = smoothstep(sharp_top, 1, nn[..., 1]) * 0.7
    c = c * (1 - wt[..., None]) + topc * wt[..., None]
    c[(np.arange(H) + 0.5) / H < V0] = topc                         # striscia dei tappi
    # riga 0 = v 0 = in basso, come vuole Blender
    return np.concatenate([c, np.ones((H, W, 1), np.float32)], -1)


# ------------------------------------------------------------------ testa anatomica
def head_colors(hd, P, N, views, bb, hair, skin):
    """Colori della testa vera: foto frontale sui punti giusti, fianco allineato su orecchio e occhio, nuca."""
    t = (P[..., 1] - hd.f["chin_y"]) / hd.H
    cf = sample(views["front"], hd.px_of_x(P[..., 0]) / hd.iw, hd.py_of_t(t) / hd.ih)
    us, vs = hd.side_uv(P)
    cs = sample(views["side"], us, vs, clamp_v=True)   # sotto il bordo della foto: allunga la pelle del collo
    bmin, bmax = bb
    s = bmax - bmin
    v = np.clip((bmax[1] - P[..., 1]) / s[1], 0, 1)
    cb = sample(views["back"], (P[..., 0] - bmin[0]) / s[0], v)
    a = np.arctan2(np.abs(N[..., 0]), -N[..., 2]) / (math.pi / 2)    # 0 davanti, 1 fianco, 2 dietro
    soft = lambda al: smoothstep(0.35, 0.95, al)                       # bordi delle sagome morbidi
    wf = (1 - smoothstep(0.62, 1.0, a)) * soft(cf[..., 3])
    ws = smoothstep(0.35, 0.8, a) * (1 - smoothstep(1.2, 1.75, a)) * soft(cs[..., 3])
    wb = smoothstep(0.95, 1.5, a) * soft(cb[..., 3])
    # le foto hanno luce diversa: il fianco e la nuca si "intonano" alla frontale dove si sovrappongono
    cs = cs.copy()
    cb = cb.copy()
    for col, w in ((cs, ws), (cb, wb)):
        both = (wf > 0.25) & (w > 0.25) & (t < 0.55)[...] if col is cs else (ws > 0.3) & (w > 0.3)
        ref = cf if col is cs else cs
        if both.sum() > 200:
            gain = ref[..., :3][both].mean(0) / np.maximum(col[..., :3][both].mean(0), 1e-3)
            col[..., :3] *= np.clip(gain, 0.75, 1.35)
    hair = np.array(hair[:3], np.float32)
    skin = np.array(skin[:3], np.float32)
    # dove nessuna foto arriva: capelli sopra e dietro (fino alla nuca), pelle davanti e sotto
    hairy = np.maximum(smoothstep(0.58, 0.66, t), smoothstep(0.9, 1.2, a) * smoothstep(0.24, 0.34, t))
    c = skin * (1 - hairy[..., None]) + hair * hairy[..., None]
    for w, col in ((wb, cb), (ws, cs), (wf, cf)):
        c = c * (1 - w[..., None]) + col[..., :3] * w[..., None]
    wt = smoothstep(0.8, 1.0, N[..., 1]) * 0.6 * (t > 0.7)
    c = c * (1 - wt[..., None]) + hair * wt[..., None]
    # sotto il mento la foto frontale non arriva bene: pelle in ombra
    wu = smoothstep(0.25, 0.6, -N[..., 1]) * (t < 0.15)
    c = c * (1 - wu[..., None]) + skin * 0.8 * wu[..., None]
    return np.concatenate([c, np.ones(c.shape[:-1] + (1,), np.float32)], -1).astype(np.float32)


def photo_skin(hd):
    """Colore medio della pelle di guance e mento nella foto frontale (per collo, braccia, mani)."""
    img = load_rgba(os.path.join(PROJ, "textures", "persone", "%s_head_front.png" % WHO))
    f = hd.f
    ys = slice(f["nose_tip"][1] - 5, f["mouth"][1] + 20)
    pts = []
    for ex, _ in f["eyes"]:
        xs = slice(int(ex) - 12, int(ex) + 12)
        pts.append(img[ys, xs].reshape(-1, 4))
    px = np.concatenate(pts)
    px = px[px[:, 3] > 0.9, :3]
    return tuple(float(c) for c in np.median(px, 0))


def real_head(part, hair, skin):
    """Testa anatomica + orecchie con le foto cotte. Ritorna i pezzi da aggiungere a Part."""
    hd = BT.Head(LOOK)
    views = {k: load_rgba(os.path.join(PROJ, "textures", "persone", "%s_head_%s.png" % (WHO, k)))
             for k in ("front", "back", "side")}
    center = lambda P: np.stack([np.zeros_like(P[..., 0]), P[..., 1], np.full_like(P[..., 0], -0.01)], -1)
    # testa
    hv, hf, huv = BT.grid_mesh(hd.point, 128, 96)
    bb = (hv.min(0), hv.max(0))
    print("cuocio la texture della testa vera ...")
    P, N = BT.grid_surface(hd.point, 2048, 1024, center)
    img = make_image("%s_testa" % LOOK, head_colors(hd, P, N, views, bb, hair, skin), OUT_BLEND)
    part.add((hv, hf, huv), make_material("%s_testa_foto" % LOOK, rough=0.85, image=img))
    # orecchie
    for side, nome in ((1, "dx"), (-1, "sx")):
        fn = lambda th, s, sd=side: hd.ear_point(sd, th, s)
        ec, _ = hd.ear_frame(side)
        ev, ef, euv = BT.grid_mesh(fn, 40, 24)
        P, N = BT.grid_surface(fn, 256, 128, lambda P, c=ec: np.broadcast_to(c, P.shape))
        # l'orecchio si colora tutto dalla foto di fianco (anche il retro, che è pelle e non capelli)
        Ns = np.zeros_like(N)
        Ns[..., 0] = side
        img = make_image("%s_orecchio_%s" % (LOOK, nome), head_colors(hd, P, Ns, views, bb, hair, skin), OUT_BLEND)
        part.add((ev, ef, euv), make_material("%s_orecchio_%s" % (LOOK, nome), rough=0.7, image=img))


# ------------------------------------------------------------------ Blender
def g2b(p):
    """Godot (x, y su, z indietro) -> Blender (x, y avanti... cioè -z, z su)."""
    return (p[0], -p[2], p[1])


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name, color=None, rough=0.8, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    if image is not None:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-350, 250)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.25
    else:
        bsdf.inputs["Base Color"].default_value = (*srgb_to_lin(color[:3]), 1)
    return m


def srgb_to_lin(c):
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def make_image(name, pix, folder):
    h, w = pix.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.pixels.foreach_set(pix.astype(np.float32).ravel())
    img.filepath_raw = os.path.join(folder, name + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


class Part:
    """Raccoglie pezzi (vertici in coordinate di Godot relative al perno) per un unico oggetto Blender."""

    def __init__(self):
        self.v, self.f, self.uv, self.mat = [], [], [], []
        self.mats = []

    def add(self, geo, material):
        v, f, uv = geo
        if material not in self.mats:
            self.mats.append(material)
        mi = self.mats.index(material)
        base = sum(len(x) for x in self.v)
        self.v.append(v)
        self.f += [tuple(i + base for i in face) for face in f]
        self.uv += uv
        self.mat += [mi] * len(f)

    def build(self, name, pivot, parent=None):
        verts = [g2b(p) for p in np.concatenate(self.v)]
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], self.f)
        me.update()
        uvl = me.uv_layers.new(name="UVMap")
        for poly, puv, mi in zip(me.polygons, self.uv, self.mat):
            poly.material_index = mi
            poly.use_smooth = True
            for li, uv in zip(poly.loop_indices, puv):
                uvl.data[li].uv = uv
        for m in self.mats:
            me.materials.append(m)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = g2b(pivot)
        if parent is not None:
            ob.parent = parent
        return ob


def build():
    clear_scene()
    os.makedirs(OUT_BLEND, exist_ok=True)
    os.makedirs(OUT_GLB, exist_ok=True)
    rnd = LK.get("round", 2.4)
    M = {}

    def mat(key, color, rough):
        if key not in M:
            M[key] = make_material("%s_%s" % (LOOK, key), color, rough)
        return M[key]

    skin_col = LK["skin"]
    if LOOK in BT.FIT:
        skin_col = photo_skin(BT.Head(LOOK))
        print("colore pelle preso dalla foto:", ["%.2f" % c for c in skin_col])
    skin = mat("pelle", skin_col, 0.6)
    shirt = mat("maglia", LK["shirt"], 0.9)
    sc = LK["shoe_colors"]
    upper_m, sole_m, detail_m = mat("scarpa", sc[0], 0.7), mat("suola", sc[1], 0.8), mat("scarpa_dettaglio", sc[2], 0.75)

    def photo(part, rings, n, top, W, H, mirror=False, front_end=0.75, tag=None):
        tag = tag or part
        print("cuocio la texture", tag, "...")
        pix = bake_photo(rings, n, part, top, W, H, mirror, front_end)
        img = make_image("%s_%s" % (LOOK, tag), pix, OUT_BLEND)
        return make_material("%s_%s_foto" % (LOOK, tag), rough=0.92, image=img)

    # radice (nel gioco: il nodo CharacterModel)
    root = bpy.data.objects.new(LOOK.capitalize(), None)
    bpy.context.scene.collection.objects.link(root)
    root.empty_display_size = 0.3

    # gambe
    leg_x = LK.get("leg_x", 0.12)
    so = LK["sole"]
    shoe = loft(LK["shoe"], 2.6)
    sole = loft([[so[0], so[2] * 0.85, so[3] * 0.9, so[4]], [so[0] + 0.006, so[2], so[3], so[4]],
                 [so[1], so[2], so[3], so[4]], [so[1] + 0.002, so[2] * 0.8, so[3] * 0.8, so[4]]], 2.6)
    dy = so[1] + 0.006
    stripe = loft([[dy, so[2] * 0.95, so[3] * 0.95, so[4]], [dy + 0.014, so[2] * 0.9, so[3] * 0.9, so[4]]], 2.6, True)
    for s, nome in ((-1, "GambaSX"), (1, "GambaDX")):
        pm = photo("legs", LK["leg"], rnd, LK["pants"], 512, 1024, s < 0, tag="gamba_sx" if s < 0 else "gamba_dx")
        p = Part()
        p.add(loft(LK["leg"], rnd), pm)
        p.add(shoe, upper_m)
        p.add(sole, sole_m)
        p.add(stripe, detail_m)
        p.build(nome, (s * leg_x, 0.85, 0), root)

    # busto
    p = Part()
    p.add(loft(LK["torso"], rnd), photo("torso", LK["torso"], rnd, LK["shirt"], 1024, 512, tag="busto"))
    upper = p.build("Busto", (0, 0, 0), root)

    # testa + collo
    nk = LK["neck"]
    p = Part()
    p.add(capsule((0, nk[1], 0.01), (0, nk[2], 0.01), nk[0]), skin)
    if LOOK in BT.FIT:
        real_head(p, LK["hair"], skin_col)
    else:
        p.add(loft(LK["head"], 2.2), photo("head", LK["head"], 2.2, LK["hair"], 1024, 512, front_end=0.85, tag="testa"))
    head = p.build("Testa", (0, 1.48, 0), upper)
    head.location = g2b((0, 1.48, 0))

    # braccia (in posa di mira, come nel gioco)
    w = LK.get("arm_r", 0.045)
    tv, _, _ = loft(LK["torso"], rnd)
    sx = tv[:, 0].max() - w * 0.9
    arms = [
        ((sx, -0.02, 0.0), (0.14, -0.17, -0.31), LK.get("sleeve_r", 0.45), LK.get("bracelets_r", [])),
        ((-sx, -0.02, 0.0), (0.07, -0.12, -0.58), LK.get("sleeve_l", 0.3), LK.get("bracelets_l", [])),
    ]
    p = Part()
    for frm, to, cut, brac in arms:
        frm, to = Vector(frm), Vector(to)
        d = to - frm
        p.add(capsule(frm, to, w), skin)
        p.add(capsule(frm - d * 0.04, frm + d * cut, w * 1.3), shirt)
        for k, c in enumerate(brac):
            at = 0.9 - k * 0.035
            p.add(capsule(frm + d * at, frm + d * (at + 0.02), w * 1.12),
                  mat("braccialetto_%s" % "_".join("%.2f" % x for x in c), c, 0.35))
    for h in ((0.14, -0.18, -0.34), (0.07, -0.13, -0.62)):
        p.add(ellipsoid(h, w * 1.05, w * 1.3, 1.2), skin)
    p.build("Braccia", (0, 1.38, 0), upper)

    # comodità in Blender: unità in metri, vista sul personaggio
    bpy.context.scene.unit_settings.system = "METRIC"

    blend = os.path.join(OUT_BLEND, LOOK + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    glb = os.path.join(OUT_GLB, LOOK + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_yup=True, export_apply=False)
    print("SALVATO", blend)
    print("SALVATO", glb)


def render_preview(close=False):
    """4 viste (davanti, 3/4, fianco, dietro) affiancate in un PNG. close = primo piano della testa."""
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    if sc.render.engine == "BLENDER_WORKBENCH":
        sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = (400, 450) if close else (400, 700)
    aim_z = 1.48 + 0.17 if close else 0.95
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("Mondo")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.37, 0.4, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    sun = bpy.data.objects.new("Sole", bpy.data.lights.new("Sole", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(150))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.42 if close else 2.0
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    for i, deg in enumerate((0, 35, 90, 180) if not close else (0, 30, 60, 90, 150)):
        a = math.radians(deg)
        # la persona guarda verso +Y: telecamera davanti = +Y
        cam.location = (5 * math.sin(a), 5 * math.cos(a), aim_z)
        cam.rotation_euler = (math.radians(90), 0, math.radians(180) + a * -1)
        cam.rotation_euler = (Vector((0, 0, aim_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(OUT_BLEND, "_vista%d.png" % i)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        shots.append(load_rgba(path))
        os.remove(path)
    out = np.concatenate(shots, 1)[::-1]
    h, w = out.shape[:2]
    img = bpy.data.images.new("anteprima", w, h)
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = os.path.join(OUT_BLEND, LOOK + ("_primo_piano.png" if close else "_anteprima.png"))
    img.file_format = "PNG"
    img.save()
    print("SALVATO", img.filepath_raw)


build()
if opt.get("render"):
    render_preview()
if opt.get("testa"):
    render_preview(close=True)
