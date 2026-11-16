# Trasforma una SCANSIONE 3D fatta col telefono (es. app KIRI Engine: .obj + .mtl + .jpg) in una persona
# del gioco, con gli stessi pezzi di actors/character_model.gd: GambaSX, GambaDX, Busto, Testa, Braccia.
#
#   - la scansione viene raddrizzata (guarda avanti), scalata a metri di gioco e ripulita (pezzetti volanti)
#   - la testa viene staccata al collo e girata dritta
#   - le braccia vengono staccate alle spalle e piegate in posa di mira (come gli altri personaggi)
#   - sotto il bacino la scansione si taglia: gambe (pantaloni) e scarpe sono inventate, fatte da codice
#   - i triangoli vengono ridotti (la scansione ne ha 250.000: troppi per il gioco) e la texture rimpicciolita
#
# Uso (da Git Bash, nella cartella StanzaFPS):
#   "/c/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --factory-startup \
#       --python tools/blender_scan.py -- --look=antonino --render
# Opzioni dopo "--":
#   --look=nome      chiave di SCANS qui sotto (default antonino)
#   --render         salva un'anteprima (davanti, 3/4, fianco, dietro) in ../blender/<nome>_anteprima.png
#   --testa          salva un primo piano della testa in ../blender/<nome>_primo_piano.png
#   --punti          anteprima della scansione grezza con i pezzi colorati (per correggere i numeri di SCANS)
#
# Risultato: ../blender/<nome>.blend (da ritoccare in Blender) e modelli/<nome>.glb (lo usa il gioco).
#
# Coordinate: i numeri di SCANS sono nella scansione GIA' RADDRIZZATA (unità della scansione, z in alto,
# la persona guarda verso +y, +x = sua destra). Per ritrovarli: --punti fa vedere dove cadono i pezzi.

import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)                         # StanzaFPS
ROOT = os.path.dirname(PROJ)                         # MauroSlime
OUT_BLEND = os.path.join(ROOT, "blender")
OUT_GLB = os.path.join(PROJ, "modelli")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {a[2:].split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in args if a.startswith("--")}
LOOK = opt.get("look", "antonino")

SCANS = {
    "antonino": {
        "obj": "persongg/Antonino/a.a/3DModel.obj",
        # raddrizzare: sposta (x, y), poi ruota di "yaw" gradi attorno a z, poi centra il busto in (cx, cy)
        "move": (-0.063, -0.182), "yaw": 120.0, "center": (-0.105, 0.085),
        # scala: unità della scansione -> metri di gioco; "hip" = altezza (scansione) che va all'anca del gioco
        "k": 0.56, "hip": 0.62,
        "cut": 0.50,                     # sotto questa altezza la scansione si butta (lì ci sono le gambe nuove)
        # collo: piano di taglio da davanti (y = +0.2) a dietro (y = -0.1); la testa si raddrizza con head_rot
        "neck_front": 1.70, "neck_back": 1.77, "head_rot": (28.0, 0.0, 0.0),   # gira (yaw), alza (pitch), inclina (roll)
        # braccia: punti lungo il braccio (spalla ... pugno), raggio della manica, quanto in alto si stacca
        "arm_r": [(0.20, 0.06, 1.55), (0.29, 0.07, 1.30), (0.32, 0.07, 1.15), (0.35, 0.09, 1.0),
                  (0.33, 0.14, 0.9), (0.35, 0.16, 0.8), (0.37, 0.27, 0.7), (0.36, 0.30, 0.58)],
        "arm_l": [(-0.42, 0.06, 1.55), (-0.48, 0.09, 1.30), (-0.48, 0.07, 1.2), (-0.47, 0.09, 1.1),
                  (-0.50, 0.09, 1.0), (-0.53, 0.16, 0.9), (-0.50, 0.19, 0.8), (-0.49, 0.27, 0.7),
                  (-0.47, 0.30, 0.58)],
        "arm_radius": 0.10, "elbow_z": 1.08, "hand_z": 0.62,
        "pocket_shrink": 0.8,            # sotto l'orlo il raggio del braccio si stringe (mani in tasca)
        # torso: metà larghezza del busto (dal centro) sotto la quale un punto NON è mai braccio
        "torso_half": (0.20, 0.20),      # (braccio destro, sinistro)
        "armpit": 1.30,                  # altezza dell'ascella: da qui in su il taglio della spalla va verso fuori
        "hip_half": 0.30,                # sotto l'orlo, più in fuori di così è roba da buttare (mani in tasca)
        "hem": 0.76,                     # orlo della maglia (sotto ci sono i pantaloni)
        # cima dei capelli: la scansione lì è bianca (non vista dal telefono) -> colore dei capelli
        "pale": (0.35, 0.22),
        "hair_top_z": 2.06, "hair_color": (0.30, 0.20, 0.12),
        # gambe e scarpe inventate (metri di gioco, come in data/looks.gd)
        "leg_x": 0.1,
        "leg_scale": 1.0,                # gambe più fini (< 1) o più grosse; il colore dei pantaloni è preso dalla scansione
        "shoe_colors": [(0.93, 0.93, 0.92), (0.97, 0.97, 0.96), (0.12, 0.12, 0.14)],
        "tris": {"Testa": 14000, "Busto": 7000, "Braccia": 6000},
        "tex": 2048,
    },
    # MARIPA: capelli lunghi castani, occhiali, cardigan grigio largo, top nero, jeans chiari.
    # Il cardigan è largo e le braccia sono "fuse" col busto: si staccano solo per distanza dalla spezzata.
    "maripa": {
        "obj": "persongg/Maripa/5a82d1411d694c2f999a3683a98be760/3DModel.obj",
        "move": (-0.069, -0.003), "yaw": 17.6, "center": (-0.03, -0.02),
        "k": 0.70, "hip": 0.27,
        "cut": 0.17,
        "neck_front": 1.13, "neck_back": 1.16, "head_rot": (0.0, 0.0, 0.0),
        "arm_r": [(0.20, -0.03, 1.0), (0.22, -0.02, 0.95), (0.22, -0.03, 0.75), (0.21, -0.02, 0.55),
                  (0.19, 0.0, 0.35), (0.17, 0.06, 0.25), (0.15, 0.09, 0.17)],
        "arm_l": [(-0.27, -0.03, 1.0), (-0.30, -0.03, 0.95), (-0.32, -0.03, 0.75), (-0.34, -0.02, 0.55),
                  (-0.35, -0.03, 0.35), (-0.34, -0.04, 0.25), (-0.31, -0.05, 0.18)],
        "arm_radius": 0.12, "elbow_z": 0.58, "hand_z": 0.22, "pocket_shrink": 1.0,
        "torso_half": (0.14, 0.19),
        "armpit": 0.82,
        "hip_half": 0.40,
        "hem": 0.30,
        "side_trim": (0.22, 0.25),       # (destra, sinistra) dal centro: più in fuori sono lembi di manica
        "code_arms": {"shoulder": 0.06, "elbow": 0.05, "cuff": 0.047, "hand": 0.03},   # raggi (metri di gioco)
        "pale": (0.42, 0.25),            # cima della testa: pixel chiari e poco colorati = non visti dal telefono
        "pants": (0.62, 0.71, 0.80),     # jeans chiari (nella scansione sono sbiaditi)
        "hair_top_z": 1.40, "hair_color": (0.33, 0.2, 0.13),
        "leg_x": 0.09,
        "leg_scale": 0.85,
        "shoe_colors": [(0.95, 0.94, 0.92), (0.97, 0.97, 0.96), (0.85, 0.62, 0.66)],
        "tris": {"Testa": 14000, "Busto": 8000, "Braccia": 5000},
        "tex": 2048,
    },
}
SC = SCANS[LOOK]

# posa delle mani in gioco (come character_model.gd), relative al perno delle braccia, coordinate di Godot
HAND_R = (0.14, -0.17, -0.34)
HAND_L = (0.07, -0.13, -0.62)


def g2b(p):
    """Godot (x, y su, z indietro) -> Blender (x, y avanti, z su)."""
    return (p[0], -p[2], p[1])


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ scansione
def load_scan():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = os.path.join(ROOT, SC["obj"])
    bpy.ops.wm.obj_import(filepath=path)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    ob = obs[0]
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix()
    # texture
    img = bpy.data.images.load(os.path.join(os.path.dirname(path), "3DModel.jpg"))
    # tieni solo il pezzo più grande (via i frammenti volanti)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    parts.sort(key=lambda o: len(o.data.polygons), reverse=True)
    for o in parts[1:]:
        bpy.data.objects.remove(o)
    ob = parts[0]
    # raddrizza: sposta, ruota, centra (resta in unità della scansione)
    mx, my = SC["move"]
    ob.data.transform(Matrix.Translation((mx, my, 0)))
    ob.data.transform(Matrix.Rotation(math.radians(SC["yaw"]), 4, "Z"))
    cx, cy = SC["center"]
    ob.data.transform(Matrix.Translation((-cx, -cy, 0)))
    return ob, img


def to_game(p):
    """Punto della scansione raddrizzata (unità scansione, centrata) -> Blender in metri di gioco."""
    k = SC["k"]
    cx, cy = SC["center"]
    p = np.asarray(p, dtype=np.float64)
    out = p * k
    out[..., 2] = 0.85 + (p[..., 2] - SC["hip"]) * k
    return out


def centered(pts):
    cx, cy = SC["center"]
    return [(x - cx, y - cy, z) for x, y, z in pts]


def seg_dist(P, A, B):
    """Distanza dei punti P (n,3) dal segmento AB e parametro t (0..1) lungo il segmento."""
    ab = B - A
    t = np.clip(((P - A) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (A + t[:, None] * ab), axis=1), t


def poly_dist(P, pts):
    """Distanza minima dalla spezzata pts e lunghezza (dalla spalla) del punto più vicino."""
    pts = np.array(pts)
    best = np.full(len(P), 1e9)
    along = np.zeros(len(P))
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d, t = seg_dist(P, a, b)
        ln = np.linalg.norm(b - a)
        upd = d < best
        best[upd] = d[upd]
        along[upd] = acc + t[upd] * ln
        acc += ln
    return best, along


def classify(ob):
    """Etichetta ogni faccia: 0 busto, 1 testa, 2 braccio destro, 3 braccio sinistro, -1 da buttare."""
    me = ob.data
    n = len(me.polygons)
    C = np.zeros(n * 3)
    me.polygons.foreach_get("center", C)
    C = C.reshape(-1, 3)
    lab = np.zeros(n, int)
    # collo: piano inclinato (davanti più basso)
    yf, yb = 0.2, -0.1
    zf, zb = SC["neck_front"], SC["neck_back"]
    zneck = zb + (C[:, 1] - yb) / (yf - yb) * (zf - zb)
    lab[C[:, 2] > zneck] = 1
    # braccia: vicino alla spezzata del braccio, fuori dal busto, sotto il collo
    for li, key, th in ((2, "arm_r", SC["torso_half"][0]), (3, "arm_l", SC["torso_half"][1])):
        pts = centered(SC[key])
        d, _ = poly_dist(C, pts)
        sx = pts[0][0]
        side = np.sign(sx)
        outside = C[:, 0] * side > th
        # alla spalla: piano inclinato (dall'ascella in su il taglio si sposta verso fuori)
        sh = (C[:, 2] < pts[0][2] - 0.02) | (C[:, 0] * side > th + (C[:, 2] - SC["armpit"]) * 0.25)
        rad = np.where(C[:, 2] < SC["hem"], SC["arm_radius"] * SC["pocket_shrink"], SC["arm_radius"])   # vicino alle tasche
        m = (d < rad) & outside & sh & (lab == 0)
        lab[m] = li
    lab[(C[:, 2] < SC["cut"]) & (lab == 0)] = -1
    # lembi di manica rimasti sui fianchi (cardigan largo): via tutto quello che è più in fuori di side_trim
    if "side_trim" in SC:
        r, l = SC["side_trim"]
        lab[(lab == 0) & (C[:, 2] < SC["armpit"] + 0.1) & ((C[:, 0] > r) | (C[:, 0] < -l))] = -1
    # mani in tasca rimaste attaccate ai fianchi
    lab[(C[:, 2] < SC["hem"]) & (np.abs(C[:, 0]) > SC["hip_half"]) & (lab == 0)] = -1
    return lab


def split(ob, lab, which, name):
    """Nuovo oggetto con solo le facce di etichetta which."""
    new = ob.copy()
    new.data = ob.data.copy()
    new.name = name
    new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    bm = bmesh.new()
    bm.from_mesh(new.data)
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if lab[f.index] != which]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    # via i pezzettini staccati rimasti
    bm.faces.ensure_lookup_table()
    seen, islands = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, isl = [f], []
        seen.add(f)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        islands.append(isl)
    islands.sort(key=len, reverse=True)
    small = [f for isl in islands[1:] if len(isl) < 2000 for f in isl]
    bmesh.ops.delete(bm, geom=small, context="FACES")
    bm.to_mesh(new.data)
    bm.free()
    return new


def fill_holes(ob, pick):
    """Chiude i buchi lasciati dai tagli. Le facce nuove sono a tinta unita: pick(centro del buco) dice
    quale ("maglia", "pantaloni" o "pelle")."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.active
    edges = [e for e in bm.edges if e.is_boundary]
    res = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    for f in res["faces"]:
        f.material_index = FLAT.index(pick(f.calc_center_median())) + 1
    bmesh.ops.triangulate(bm, faces=res["faces"])
    bm.to_mesh(ob.data)
    bm.free()


def face_info(me, pix):
    """Centri, normali, UV medie e colore della texture (al centro UV) di ogni faccia."""
    n = len(me.polygons)
    C = np.zeros(n * 3)
    me.polygons.foreach_get("center", C)
    N = np.zeros(n * 3)
    me.polygons.foreach_get("normal", N)
    st = np.zeros(n, np.int64)
    me.polygons.foreach_get("loop_start", st)
    tot = np.zeros(n, np.int64)
    me.polygons.foreach_get("loop_total", tot)
    uv = np.zeros(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    U = np.add.reduceat(uv, st) / tot[:, None]
    h, w = pix.shape[:2]
    col = pix[np.clip((U[:, 1] * h).astype(int), 0, h - 1), np.clip((U[:, 0] * w).astype(int), 0, w - 1), :3]
    return C.reshape(-1, 3), N.reshape(-1, 3), U, col, st, tot, uv


FLAT = ["maglia", "pantaloni", "pelle"]     # materiali a tinta unita: indice 1, 2, 3 (0 = texture della scansione)


def flatten_hidden(ob, lab, pix):
    """Le zone che il telefono non ha visto (fianchi sotto le braccia, interno delle braccia, tasche con le
    mani) nella scansione hanno la texture a strisce: lì si mette un materiale a tinta unita (maglia o
    pantaloni) col colore mediano della zona. Ritorna i colori."""
    me = ob.data
    C, N, U, col, st, tot, uv = face_info(me, pix)
    x, y, z = C[:, 0], C[:, 1], C[:, 2]
    zs = SC["arm_r"][0][2]                                    # altezza delle spalle
    sat = col.max(1) - col.min(1)
    ztop = z[lab == 1].max()
    zface = SC["neck_front"] + (ztop - SC["neck_front"]) * 0.35     # terzo basso della testa: mento e bocca
    sel = {
        # maglia: grigia/poco colorata (niente capelli né top scuro sotto)
        "maglia": (lab == 0) & (z > SC["hem"] + 0.05) & (z < zs) & (sat < SC.get("maglia_sat", 0.12)) &
                  (col.mean(1) > 0.15),
        "pantaloni": (lab == 0) & (np.abs(x) < 0.12) & (z < SC["hem"] - 0.02) & (z > SC["cut"]) & (N[:, 1] > 0.5),
        "pelle": (lab == 1) & (np.abs(x) < 0.05) & (z < zface) & (N[:, 1] > 0.7),
    }
    colors = {k: tuple(float(c) for c in np.median(col[m], 0)) for k, m in sel.items()}
    for k, c in colors.items():
        print("colore %s:" % k, ["%.2f" % x for x in c])
    # colore dei pantaloni della scansione: le gambe inventate saranno uguali
    SC.setdefault("pants", colors["pantaloni"])
    print("colore pantaloni preso dalla scansione:", ["%.2f" % c for c in SC["pants"]])
    to_set = {k: np.zeros(len(lab), bool) for k in sel}
    th = min(SC["torso_half"])
    near_arm = np.zeros(len(lab), bool)
    for key in ("arm_r", "arm_l"):
        d, _ = poly_dist(C, centered(SC[key]))
        near_arm |= d < 0.2
    # fianchi del busto vicino alle braccia
    to_set["maglia"] |= (lab == 0) & (z > SC["hem"]) & (z < zs - 0.05) & (np.abs(x) > th - 0.07) &         (np.abs(N[:, 0]) > 0.35) & near_arm
    # interno delle braccia (rivolto verso il busto), pugni esclusi
    for li, key in ((2, "arm_r"), (3, "arm_l")):
        side = np.sign(centered(SC[key])[0][0])
        to_set["maglia"] |= (lab == li) & (N[:, 0] * side < -0.3) & (z > SC["hand_z"] + 0.1)
    # bacino: mani in tasca (chiare) e fianchi
    pel = (lab == 0) & (z < SC["hem"])
    to_set["pantaloni"] |= pel & ((col.max(1) > 0.32) | ((np.abs(x) > th + 0.03) & (np.abs(N[:, 0]) > 0.4)))
    mi = np.zeros(len(lab), np.int32)
    for k, m in to_set.items():
        mi[m] = FLAT.index(k) + 1
        print("facce a tinta unita (%s): %d" % (k, int(m.sum())))
    me.polygons.foreach_set("material_index", mi)
    return colors


def verts(ob):
    co = np.zeros(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_verts(ob, co):
    ob.data.vertices.foreach_set("co", np.asarray(co, np.float32).ravel())
    ob.data.update()


def rot_between(a, b):
    return np.array(Vector(a).normalized().rotation_difference(Vector(b).normalized()).to_matrix())


def arm_joints(pts, hand_target, pole):
    """Spalla, gomito e polso della scansione (S, E, H) e nuovi gomito e mano (E2, T) per la posa di mira."""
    pts = to_game(np.array(centered(pts)))
    S = pts[0]
    ez = 0.85 + (SC["elbow_z"] - SC["hip"]) * SC["k"]
    hz = 0.85 + (SC["hand_z"] - SC["hip"]) * SC["k"]

    def at_z(z):
        for a, b in zip(pts, pts[1:]):
            if b[2] <= z <= a[2]:
                t = (a[2] - z) / (a[2] - b[2])
                return a + (b - a) * t
        return pts[-1]
    E, H = at_z(ez), at_z(hz)
    Lu, Lf = np.linalg.norm(E - S), np.linalg.norm(H - E)
    T = np.array(hand_target, float)
    d = np.linalg.norm(T - S)
    d = min(d, 0.97 * (Lu + Lf))
    n = (T - S) / np.linalg.norm(T - S)
    T = S + n * d
    a = (Lu * Lu - Lf * Lf + d * d) / (2 * d)
    h = math.sqrt(max(Lu * Lu - a * a, 0.0))
    p = np.array(pole, float)
    p = p - (p @ n) * n
    p /= np.linalg.norm(p)
    E2 = S + n * a + p * h
    return S, E, H, E2, T


def pose_arm(P, pts, hand_target, pole):
    """Piega il braccio (punti P, in metri di gioco) per portare il pugno su hand_target. Ritorna P nuovi."""
    S, E, H, E2, T = arm_joints(pts, hand_target, pole)
    Lf = np.linalg.norm(H - E)
    R1 = rot_between(E - S, E2 - S)
    R2 = rot_between(H - E, T - E2)
    up = S + (P - S) @ R1.T
    fore = E2 + (P - E) @ R2.T
    s = (P - E) @ ((H - E) / Lf)
    w = smoothstep(-0.03, 0.03, s)[:, None]
    return up * (1 - w) + fore * w


# ------------------------------------------------------------------ texture
def fix_texture(img, head):
    """Rimpicciolisce la texture e colora come capelli la cima della testa (bianca nella scansione)."""
    size = SC["tex"]
    if img.size[0] != size:
        img.scale(size, size)
    w, h = img.size
    pix = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    # facce in cima alla testa: maschera nella texture
    me = head.data
    zc = 0.85 + (SC["hair_top_z"] - SC["hip"]) * SC["k"]
    uvl = me.uv_layers.active.data
    mask = np.zeros((h, w), bool)
    for poly in me.polygons:
        if poly.center.z < zc:
            continue
        uvs = np.array([uvl[li].uv for li in poly.loop_indices]) * [w, h]
        if np.ptp(uvs, 0).max() > w * 0.05:          # faccia a cavallo di una cucitura: salta
            continue
        x0, y0 = np.floor(uvs.min(0)).astype(int)
        x1, y1 = np.ceil(uvs.max(0)).astype(int)
        x0, y0 = max(x0 - 1, 0), max(y0 - 1, 0)
        x1, y1 = min(x1 + 1, w - 1), min(y1 + 1, h - 1)
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        for k in range(1, len(uvs) - 1):             # triangoli a ventaglio, test baricentrico (+ mezzo pixel)
            a, b, c = uvs[0], uvs[k], uvs[k + 1]
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            e = 1.0 / max(np.ptp(uvs, 0).max(), 1.0)
            inside = (l1 > -e) & (l2 > -e) & (1 - l1 - l2 > -e)
            mask[y0:y1 + 1, x0:x1 + 1] |= inside
    rgb = pix[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    pale = mask & (mx > SC.get("pale", (0.3, 0.15))[0]) & ((mx - mn) < SC.get("pale", (0.3, 0.15))[1])
    print("pixel bianchi in cima alla testa ricolorati:", int(pale.sum()), "su", int(mask.sum()))
    # riempimento: media dei capelli VERI lì vicino (somme su un quadrato, con le somme cumulate),
    # poi si tiene la "grana" chiaro/scuro dei pixel bianchi, così sembrano ciocche e non una macchia piatta
    lum = rgb.mean(-1)
    good = (mask & ~pale & (lum < SC.get("hair_max", 0.4))).astype(np.float32)   # solo capelli veri (scuri)

    def box(a, r):
        c = np.cumsum(np.cumsum(np.pad(a, ((r + 1, r), (r + 1, r)) + ((0, 0),) * (a.ndim - 2)), 0), 1)
        return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]
    hc = np.array(SC["hair_color"], np.float32)       # i pixel delle immagini 8 bit sono già sRGB
    fill = np.broadcast_to(hc, rgb.shape).copy()
    done = np.zeros((h, w), bool)
    for r in (6, 16, 40):
        ws = box(good, r)
        cs = box(rgb * good[..., None], r)
        ok = (ws > 3) & ~done
        fill[ok] = cs[ok] / ws[ok][:, None]
        done |= ok
    grain = np.clip(lum / max(float(lum[pale].mean()), 1e-3), 0.75, 1.25) if pale.any() else lum
    rgb[pale] = fill[pale] * grain[pale][:, None]
    pix[..., :3] = rgb
    img.pixels.foreach_set(pix.ravel())
    img.name = "%s_scansione" % LOOK
    img.filepath_raw = os.path.join(OUT_BLEND, "%s_scansione.jpg" % LOOK)
    img.file_format = "JPEG"
    img.save()
    img.pack()


# ------------------------------------------------------------------ gambe e scarpe (come data/looks.gd)
def ring_pts(r, ang, n):
    c, s = np.cos(ang), np.sin(ang)
    x = np.sign(c) * np.abs(c) ** (2.0 / n) * r[1]
    z = np.sign(s) * np.abs(s) ** (2.0 / n) * r[2] + r[3]
    return np.stack([x, np.full_like(ang, r[0]), z], -1)


def loft(rings, n=2.4, open_=False, seg=24):
    ang = 2 * math.pi * np.arange(seg) / seg
    vs = [p for r in rings for p in ring_pts(r, ang, n)]
    faces = []
    nr = len(rings)
    for j in range(nr - 1):
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((j * seg + i, j * seg + i1, (j + 1) * seg + i1, (j + 1) * seg + i))
    if not open_:
        cb = len(vs)
        vs.append(np.array([0, rings[0][0], rings[0][3]]))
        vs.append(np.array([0, rings[-1][0], rings[-1][3]]))
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((cb, i1, i))
            faces.append((cb + 1, (nr - 1) * seg + i, (nr - 1) * seg + i1))
    return np.array(vs), faces


LEG = [   # pantaloni neri un po' larghi, risvolto alla caviglia
    [-0.745, 0.062, 0.07, 0.0],
    [-0.735, 0.07, 0.078, 0.0],
    [-0.70, 0.068, 0.076, 0.0],
    [-0.55, 0.074, 0.082, 0.0],
    [-0.40, 0.08, 0.088, 0.005],
    [-0.20, 0.092, 0.098, 0.0],
    [0.0, 0.105, 0.11, 0.0],
    [0.06, 0.1, 0.105, 0.0],
    [0.08, 0.05, 0.05, 0.0],
]
SHOE = [  # sneaker bassa
    [-0.835, 0.052, 0.135, -0.045],
    [-0.80, 0.06, 0.15, -0.045],
    [-0.77, 0.058, 0.14, -0.035],
    [-0.745, 0.05, 0.11, -0.015],
    [-0.725, 0.04, 0.065, 0.005],
    [-0.715, 0.02, 0.03, 0.005],
]
SOLE = [-0.852, -0.822, 0.066, 0.16, -0.045]


def mat(name, color, rough=0.8, image=None):
    m = bpy.data.materials.new("%s_%s" % (LOOK, name))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    if image is not None:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
        m.diffuse_color = (*[c ** 2.2 for c in color], 1)       # colore anche nella vista veloce
    return m


def mesh_obj(name, parts, pivot, parent):
    """parts = [(verts Godot, faces, materiale)]: oggetto con perno in pivot (Godot)."""
    allv, allf, fm, mats = [], [], [], []
    base = 0
    for v, f, m in parts:
        if m not in mats:
            mats.append(m)
        allv += [g2b(p) for p in v]
        allf += [tuple(i + base for i in face) for face in f]
        fm += [mats.index(m)] * len(f)
        base += len(v)
    me = bpy.data.meshes.new(name)
    me.from_pydata(allv, [], allf)
    for poly, mi in zip(me.polygons, fm):
        poly.material_index = mi
        poly.use_smooth = True
    for m in mats:
        me.materials.append(m)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = g2b(pivot)
    return ob


# ------------------------------------------------------------------ montaggio
def decimate(ob, tris):
    now = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if now <= tris:
        return
    md = ob.modifiers.new("riduci", "DECIMATE")
    md.ratio = tris / now
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)


def set_pivot(ob, pivot_b, parent):
    """Sposta i vertici in modo che l'origine dell'oggetto sia pivot_b (Blender, coordinate assolute)."""
    co = verts(ob) - np.array(pivot_b)
    set_verts(ob, co)
    ob.parent = parent
    ob.location = pivot_b if parent is None else Vector(pivot_b) - parent.matrix_world.translation


def code_arms(joints, pivot):
    """Braccia fatte da codice (per i vestiti larghi, dove la scansione ha le maniche fuse col busto):
    manica a tronco di cono spalla-gomito-polso, polsino, mano. Colori = punti a tinta unita della texture."""
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    a = SC["code_arms"]

    def piece(make, what):
        before = set(bm.faces)
        make()
        for f in bm.faces:
            if f not in before:
                f.material_index = FLAT.index(what) + 1

    def seg(p, q, r1, r2):
        d = Vector(q) - Vector(p)
        m = Matrix.Translation((Vector(p) + Vector(q)) / 2) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=14, radius1=r1, radius2=r2, depth=d.length, matrix=m)

    def ball(c, r, sz=1.0):
        m = Matrix.Translation(Vector(c)) @ Matrix.Diagonal((r, r, r * sz, 1))
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=1.0, matrix=m)

    for S, E, T in joints:
        S, E, T = (np.asarray(v, float) - pivot for v in (S, E, T))
        W = T - (T - E) / np.linalg.norm(T - E) * a["hand"] * 1.2          # polso: poco prima della mano
        piece(lambda: (ball(S, a["shoulder"]), seg(S, E, a["shoulder"], a["elbow"]), ball(E, a["elbow"]),
                       seg(E, W, a["elbow"], a["cuff"])), "maglia")
        piece(lambda: ball(T, a["hand"], 1.3), "pelle")
    me = bpy.data.meshes.new("Braccia")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Braccia", me)
    bpy.context.scene.collection.objects.link(ob)
    set_verts(ob, verts(ob) + pivot)
    return ob


def build():
    ob, img = load_scan()
    lab = classify(ob)
    if opt.get("punti"):
        return ob, lab
    w, h = img.size
    pix = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    plain = flatten_hidden(ob, lab, pix)
    del pix
    # la texture ha già la luce "dentro": le tinte unite si schiariscono un po' per non sembrare più scure
    lift = lambda c: tuple(min(x * 1.12, 1.0) for x in c)
    mats = [mat("scansione", None, 0.85, img)] + [mat(k, lift(plain[k]), 0.9 if k != "pelle" else 0.6) for k in FLAT]
    ob.data.materials.clear()
    for m in mats:
        ob.data.materials.append(m)
    hem_g = 0.85 + (SC["hem"] - SC["hip"]) * SC["k"]
    pieces = {nm: split(ob, lab, i, nm) for i, nm in ((0, "Busto"), (1, "Testa"), (2, "BraccioDX"), (3, "BraccioSX"))}
    bpy.data.objects.remove(ob)
    for o in pieces.values():
        set_verts(o, to_game(verts(o)))

    # testa: dritta (gira attorno al collo)
    neck = to_game(np.array([0.0, 0.03, (SC["neck_front"] + SC["neck_back"]) / 2]))
    head = pieces["Testa"]
    yaw, pitch, roll = (math.radians(a) for a in SC["head_rot"])
    R = np.array(Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(pitch, 3, "X") @ Matrix.Rotation(roll, 3, "Y"))
    set_verts(head, neck + (verts(head) - neck) @ R.T)

    # braccia in posa di mira: perno delle braccia all'altezza delle spalle
    sh = to_game(np.array(centered([SC["arm_r"][0], SC["arm_l"][0]])))
    arms_pivot = np.array([0.0, 0.0, sh[:, 2].mean() - 0.03])
    arm_list = (("BraccioDX", "arm_r", HAND_R, (1.0, -0.6, -1.0)), ("BraccioSX", "arm_l", HAND_L, (-1.0, -0.3, -1.0)))
    if "code_arms" in SC:
        joints = []
        for nm, key, hand, pole in arm_list:
            S, E, H, E2, T = arm_joints(SC[key], arms_pivot + np.array(g2b(hand)), pole)
            joints.append((S, E2, T))
            bpy.data.objects.remove(pieces[nm])
        arms = code_arms(joints, arms_pivot)
        for m in mats:
            arms.data.materials.append(m)
    else:
        for nm, key, hand, pole in arm_list:
            target = arms_pivot + np.array(g2b(hand))
            o = pieces[nm]
            set_verts(o, pose_arm(verts(o), SC[key], target, pole))
        # un solo oggetto Braccia
        bpy.ops.object.select_all(action="DESELECT")
        pieces["BraccioDX"].select_set(True)
        pieces["BraccioSX"].select_set(True)
        bpy.context.view_layer.objects.active = pieces["BraccioDX"]
        bpy.ops.object.join()
        arms = pieces["BraccioDX"]
        arms.name = arms.data.name = "Braccia"
    pieces = {"Busto": pieces["Busto"], "Testa": head, "Braccia": arms}

    picks = {
        "Busto": lambda c: "pantaloni" if c.z < hem_g else "maglia",
        "Testa": lambda c: "pelle",
        "Braccia": lambda c: "maglia",
    }
    for nm, o in pieces.items():
        fill_holes(o, picks[nm])
        decimate(o, SC["tris"][nm])
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_smooth()

    fix_texture(img, head)

    # gerarchia come character_model.gd
    root = bpy.data.objects.new(LOOK.capitalize(), None)
    bpy.context.scene.collection.objects.link(root)
    upper = pieces["Busto"]
    set_pivot(upper, (0, 0, 0), root)
    set_pivot(head, tuple(neck), upper)
    set_pivot(arms, tuple(arms_pivot), upper)
    print("perni (Godot): testa", (neck[0], neck[2], -neck[1]), "braccia", (0, arms_pivot[2], -arms_pivot[1]))

    # gambe e scarpe inventate
    pants = mat("pantaloni", SC["pants"], 0.9)
    sc = SC["shoe_colors"]
    upper_m, sole_m, detail_m = mat("scarpa", sc[0], 0.6), mat("suola", sc[1], 0.8), mat("scarpa_dettaglio", sc[2], 0.6)
    ls = SC.get("leg_scale", 1.0)
    ss = (1.0 + ls) / 2                                     # scarpe: un po' più piccole se le gambe sono fini
    so = SOLE
    so = [so[0], so[1], so[2] * ss, so[3] * ss, so[4] * ss]
    sole = loft([[so[0], so[2] * 0.85, so[3] * 0.9, so[4]], [so[0] + 0.006, so[2], so[3], so[4]],
                 [so[1], so[2], so[3], so[4]], [so[1] + 0.002, so[2] * 0.8, so[3] * 0.8, so[4]]], 2.6)
    dy = so[1] + 0.006
    stripe = loft([[dy, so[2] * 0.95, so[3] * 0.95, so[4]], [dy + 0.014, so[2] * 0.9, so[3] * 0.9, so[4]]], 2.6, True)
    leg = loft([[r[0], r[1] * ls, r[2] * ls, r[3]] for r in LEG], 2.2)
    shoe = loft([[r[0], r[1] * ss, r[2] * ss, r[3] * ss] for r in SHOE], 2.6)
    lx = SC["leg_x"]
    for s, nome in ((-1, "GambaSX"), (1, "GambaDX")):
        mesh_obj(nome, [(leg[0], leg[1], pants), (shoe[0], shoe[1], upper_m), (sole[0], sole[1], sole_m),
                        (stripe[0], stripe[1], detail_m)], (s * lx, 0.85, 0), root)

    bpy.context.scene.unit_settings.system = "METRIC"
    os.makedirs(OUT_BLEND, exist_ok=True)
    blend = os.path.join(OUT_BLEND, LOOK + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    glb = os.path.join(OUT_GLB, LOOK + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_yup=True, export_apply=False,
                              export_image_format="WEBP", export_image_quality=88)
    tot = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("triangoli totali:", tot)
    print("SALVATO", blend)
    print("SALVATO", glb)
    return None, None


# ------------------------------------------------------------------ anteprime
def render_views(name, aim_z, ortho, res, angles, color="TEXTURE"):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = color
    sc.render.resolution_x, sc.render.resolution_y = res
    world = bpy.data.worlds.new("Mondo")
    sc.world = world
    world.color = (0.35, 0.37, 0.4)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = []
    for i, deg in enumerate(angles):
        a = math.radians(deg)
        cam.location = (5 * math.sin(a), 5 * math.cos(a), aim_z)
        cam.rotation_euler = (Vector((0, 0, aim_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(OUT_BLEND, "_vista%d.png" % i)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(path)
        w, h = im.size
        shots.append(np.array(im.pixels[:], np.float32).reshape(h, w, 4))
        bpy.data.images.remove(im)
        os.remove(path)
    out = np.concatenate(shots, 1)
    h, w = out.shape[:2]
    img = bpy.data.images.new(name, w, h)
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = os.path.join(OUT_BLEND, name)
    img.file_format = "PNG"
    img.save()
    print("SALVATO", img.filepath_raw)


def show_labels(ob, lab):
    """--punti: colora i pezzi della scansione grezza (busto grigio, testa blu, braccia rosso/verde, via nero)."""
    me = ob.data
    me.materials.clear()
    cols = {0: (0.6, 0.6, 0.6), 1: (0.2, 0.3, 1.0), 2: (1.0, 0.2, 0.2), 3: (0.2, 1.0, 0.2), -1: (0.05, 0.05, 0.05)}
    for i, c in cols.items():
        m = bpy.data.materials.new("l%d" % i)
        m.diffuse_color = (*c, 1)
        me.materials.append(m)
    idx = {i: k for k, i in enumerate(cols)}
    me.polygons.foreach_set("material_index", np.array([idx[x] for x in lab], np.int32))
    sc = bpy.context.scene
    set_verts(ob, to_game(verts(ob)))
    render_views(LOOK + "_punti.png", 1.0, 2.2, (450, 700), (0, 90, 180, 270), "MATERIAL")


ob, lab = build()
if opt.get("punti"):
    show_labels(ob, lab)
if opt.get("render"):
    render_views(LOOK + "_anteprima.png", 0.95, 2.0, (400, 700), (0, 35, 90, 180))
if opt.get("testa"):
    render_views(LOOK + "_primo_piano.png", 1.62, 0.45, (400, 450), (0, 30, 60, 90, 150))
if opt.get("busto"):
    render_views(LOOK + "_braccia_anteprima.png", 1.2, 0.9, (500, 500), (0, 45, 90, 200, 300))
