# TESTA ANATOMICA per tools/blender_persona.py (Blender + numpy, niente bpy qui dentro).
#
# Invece dell'"uovo ad anelli" del gioco costruisce una testa umana vera:
#   - sagoma vista da davanti presa dalla FOTO FRONTALE (larghezza riga per riga);
#   - profilo (fronte, arcata delle sopracciglia, orbite, zigomi, naso, labbra, mento) da proporzioni
#     umane medie, con i punti messi dove sono nella foto (occhi, punta del naso, bocca, mento);
#   - orecchie a parte (conchiglie schiacciate e inclinate);
#   - la foto frontale viene proiettata ESATTAMENTE su quei punti: il naso della foto cade sul naso 3D.
#
# Unità: H = altezza della testa dal mento alla cima dei capelli (metri di gioco). Le coordinate sono quelle
# di Godot relative al perno della testa (attaccatura del collo): x a destra, y in alto, z indietro (-z = avanti).
# Ogni persona ha i suoi numeri in FIT: si leggono sulla foto textures/persone/<nome>_head_front.png
# (256 x 320 px; conviene aprirla con una griglia sopra).

import math

import numpy as np

FIT = {
    "matteo": {
        "img": (256, 320),           # dimensioni del ritaglio frontale
        "top_px": 5,                 # cima dei capelli (y in px)
        "chin_px": 318,              # punta del mento
        "mid_px": 113,               # asse della faccia (in mezzo agli occhi)
        "chin_y": 0.02,              # dove sta il mento rispetto al perno della testa (metri di gioco)
        "height": 0.30,              # mento -> cima dei capelli (metri di gioco)
        "x_scale": 0.83,             # il ritaglio è stato allargato (211 px -> 256): px orizzontali più corti
        "width_scale": 1.05,         # la foto è un filo girata: la metà "pulita" è un po' più stretta del vero
        # mezza larghezza della sagoma (px) riga per riga, lato senza orecchio, capelli spettinati smussati
        "half_width": [(5, 6), (10, 25), (20, 47), (30, 63), (40, 76), (50, 84), (60, 88), (70, 90),
                       (80, 91), (100, 91), (120, 90), (140, 87), (160, 85), (180, 84), (200, 83),
                       (220, 80), (240, 75), (260, 69), (280, 60), (295, 50), (305, 40), (313, 26),
                       (318, 12)],
        # punti della faccia (px): occhi, punta del naso, attaccatura del naso, bocca
        "eyes": [(70, 168), (160, 168)],
        "brow_px": 148,
        "nose_tip": (106, 228),
        "nose_root": (113, 166),
        "mouth": (112, 260),
        "ear_px": (163, 238),        # orecchio: da y a y (px)
        # foto di FIANCO (matteo_head_side.png): dove sono il centro dell'orecchio e l'occhio, e quanto il
        # ritaglio è stato stirato (px del ritaglio per px della foto originale, in x e in y)
        "side_ear": (95, 240),
        "side_eye": (215, 215),
        "side_stretch": (0.985, 1.143),
    },
    "broski": {
        "img": (256, 320),
        "top_px": 9,                 # cima dei capelli (ciuffo)
        "chin_px": 319,              # punta del mento (in fondo al ritaglio)
        "mid_px": 120,               # asse della faccia
        "chin_y": 0.035,             # un po' di collo sotto il mento (nelle foto si vede, con le collanine)
        "height": 0.325,
        "x_scale": 0.854,            # ritaglio 246 x 360 px -> 256 x 320
        "width_scale": 1.0,
        # sagoma misurata sulla foto (media dei due lati, orecchie escluse): capelli larghi in alto,
        # mascella che si stringe verso il mento
        "half_width": [(9, 14), (14, 44), (22, 70), (32, 90), (46, 106), (73, 118), (108, 114), (144, 109),
                       (180, 107), (215, 104), (251, 95), (277, 83), (300, 65), (313, 44), (319, 21)],
        "eyes": [(73, 166), (166, 166)],
        "brow_px": 144,
        "nose_tip": (120, 220),
        "nose_root": (120, 166),
        "mouth": (120, 261),
        "ear_px": (171, 242),
        # primo piano di profilo (broski_head_side.png, ritaglio 550 x 595 px -> 256 x 320, mento compreso)
        "side_ear": (118, 198),
        "side_eye": (221, 165),
        "side_stretch": (0.465, 0.538),
    },

}


# ------------------------------------------------------------------ utilità
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def spline(knots, x):
    """Interpolazione morbida (Catmull-Rom) di una tabella [(x, y), ...] con x crescenti."""
    kx = np.array([k[0] for k in knots], float)
    ky = np.array([k[1] for k in knots], float)
    x = np.clip(np.asarray(x, float), kx[0], kx[-1])
    i = np.clip(np.searchsorted(kx, x, side="right") - 1, 0, len(kx) - 2)
    x0, x1 = kx[i], kx[i + 1]
    t = (x - x0) / (x1 - x0)
    p0 = ky[np.maximum(i - 1, 0)]
    p1, p2 = ky[i], ky[i + 1]
    p3 = ky[np.minimum(i + 2, len(ky) - 1)]
    # tangenti scalate per passi non uniformi
    xm = kx[np.maximum(i - 1, 0)]
    xp = kx[np.minimum(i + 2, len(kx) - 1)]
    m1 = (p2 - p0) / np.maximum(x1 - xm, 1e-9) * (x1 - x0)
    m2 = (p3 - p1) / np.maximum(xp - x0, 1e-9) * (x1 - x0)
    t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * p1 + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2 + (t3 - t2) * m2


def gauss(x, y, cx, cy, sx, sy):
    return np.exp(-((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2)


# profilo umano medio, in H, con t = 0 mento, 1 cima dei capelli
# F = quanto sporge la faccia (piano delle guance, senza naso/labbra) davanti all'asse delle orecchie
F_KNOTS = [(-0.06, 0.02), (-0.03, 0.15), (0.0, 0.24), (0.05, 0.30), (0.12, 0.315), (0.2, 0.325),
           (0.3, 0.335), (0.4, 0.34), (0.48, 0.345), (0.56, 0.365), (0.66, 0.37), (0.76, 0.355),
           (0.85, 0.31), (0.92, 0.23), (0.97, 0.13), (1.0, 0.0)]
# B = nuca dietro l'asse
B_KNOTS = [(-0.06, 0.02), (-0.03, 0.08), (0.0, 0.12), (0.1, 0.2), (0.2, 0.29), (0.3, 0.355),
           (0.45, 0.4), (0.6, 0.41), (0.72, 0.39), (0.82, 0.34), (0.9, 0.26), (0.96, 0.15), (1.0, 0.0)]


class Head:
    def __init__(self, name):
        f = FIT[name]
        self.f = f
        self.H = f["height"]
        self.k = self.H / (f["chin_px"] - f["top_px"])          # metri per px (in verticale)
        self.kx = self.k * f.get("x_scale", 1.0)                 # metri per px in orizzontale
        self.iw, self.ih = f["img"]

    # conversioni foto <-> testa
    def t_of_py(self, py):
        return (self.f["chin_px"] - py) / (self.f["chin_px"] - self.f["top_px"])

    def py_of_t(self, t):
        return self.f["chin_px"] - t * (self.f["chin_px"] - self.f["top_px"])

    def px_of_x(self, x):
        return self.f["mid_px"] - x / self.kx

    def half_width(self, t):
        """Mezza larghezza (H) alla quota t, dalla sagoma della foto; sotto il mento chiude."""
        sc = self.f["width_scale"] * self.f.get("x_scale", 1.0) / (self.f["chin_px"] - self.f["top_px"])
        hw = [(self.t_of_py(py), w * sc)
              for py, w in self.f["half_width"]][::-1]
        hw = [(-0.06, 0.03), (-0.03, 0.11)] + [(max(a, 0.0), b) for a, b in hw]
        hw[2] = (0.0, max(hw[2][1], 0.12))
        return spline(hw, t)

    def features(self, xpx, t):
        """Rilievi della faccia (H, in avanti) in funzione del punto della foto: naso, orbite, labbra..."""
        f = self.f
        T = self.t_of_py
        d = np.zeros_like(xpx, dtype=float)
        # naso: cresta dall'attaccatura alla punta, con l'asse che segue la foto (testa un filo girata)
        tt, tr = T(f["nose_tip"][1]), T(f["nose_root"][1])
        s = np.clip((t - tt) / (tr - tt), -1.5, 1.5)            # 0 = punta, 1 = radice
        cx = f["nose_tip"][0] + (f["nose_root"][0] - f["nose_tip"][0]) * np.clip(s, 0, 1)
        amp = spline([(-0.5, 0.0), (-0.32, 0.012), (-0.12, 0.05), (0.0, 0.072), (0.15, 0.064), (0.45, 0.045),
                      (0.8, 0.022), (1.0, 0.012), (1.25, 0.0)], s)
        wid = spline([(-0.5, 9.0), (0.0, 11.0), (0.3, 8.0), (0.8, 6.5), (1.2, 9.0)], s)
        d += amp * np.exp(-((xpx - cx) / wid) ** 2)
        # ali del naso e narici
        for side in (-1, 1):
            d += 0.024 * gauss(xpx, t, f["nose_tip"][0] + side * 15, tt + 0.01, 7.5, 0.028)
        # orbite (incavate) e bulbi degli occhi (leggero rilievo)
        for ex, ey in f["eyes"]:
            te = T(ey)
            d -= 0.045 * gauss(xpx, t, ex, te + 0.005, 21, 0.055)
            d += 0.022 * gauss(xpx, t, ex, te, 12, 0.03)
        # arcata sopracciglia e fronte
        tb = T(f["brow_px"])
        eyes_x = [e[0] for e in f["eyes"]]
        span = smoothstep(0, 1, 1 - np.abs(xpx - f["mid_px"]) / (abs(eyes_x[1] - eyes_x[0]) * 0.95))
        d += 0.016 * np.exp(-((t - tb) / 0.035) ** 2) * span
        # zigomi
        for ex, ey in f["eyes"]:
            out = ex + (ex - f["mid_px"]) * 0.25
            d += 0.022 * gauss(xpx, t, out, T(ey) - 0.1, 22, 0.06)
        # bocca: labbro superiore, inferiore, fessura; solco sotto il labbro; mento
        mx, my = f["mouth"]
        tm = T(my)
        d += 0.03 * gauss(xpx, t, mx, tm + 0.022, 22, 0.02)
        d += 0.026 * gauss(xpx, t, mx, tm - 0.02, 19, 0.022)
        d -= 0.012 * gauss(xpx, t, mx, tm + 0.002, 26, 0.007)
        d -= 0.008 * gauss(xpx, t, mx, tm + 0.045, 7, 0.02)     # filtro (solco sopra il labbro)
        d -= 0.014 * gauss(xpx, t, mx, tm - 0.06, 24, 0.018)
        d += 0.034 * gauss(xpx, t, mx, 0.06, 24, 0.045)          # mento
        # pieghe naso-labiali (leggere) ai lati della bocca
        for side in (-1, 1):
            d -= 0.008 * gauss(xpx, t, mx + side * 30, tm + 0.04, 6, 0.05)
        return d

    def point(self, th, s):
        """Punto della testa (Godot, metri) per angolo th (0 = davanti, +pi/2 = destra del personaggio)
        e quota s in 0..1 (dal basso del collo alla cima)."""
        t = -0.06 + 1.06 * s
        H = self.H
        a = self.half_width(t) * H
        F = spline(F_KNOTS, t) * H
        B = spline(B_KNOTS, t) * H
        sn, cs = np.sin(th), np.cos(th)
        nf = 2.5                                   # faccia un po' più piatta di un ovale
        nb = 2.15
        n = np.where(cs > 0, nf, nb)
        x = np.sign(sn) * np.abs(sn) ** (2 / n) * a
        fwd = np.where(cs > 0, F, B) * np.sign(cs) * np.abs(cs) ** (2 / n)
        # rilievi del viso, solo sul davanti
        xpx = self.px_of_x(x)                      # la foto: a destra dell'immagine c'è la SINISTRA (-x)
        front = smoothstep(0.25, 0.75, cs) * smoothstep(-0.04, 0.03, t)
        fwd = fwd + self.features(xpx, t) * H * front
        y = self.f["chin_y"] + t * H
        return np.stack([x, y, -fwd], -1)

    def side_uv(self, P):
        """Coordinate (u, v) nella foto di fianco: similitudine fissata da orecchio e occhio."""
        f = self.f
        sx, sy = f["side_stretch"]
        c, _ = self.ear_frame(1)
        te = self.t_of_py(f["eyes"][0][1])
        eye_fwd = float(spline(F_KNOTS, te)) * self.H - 0.01
        g = [complex(-c[2], -c[1]), complex(eye_fwd, -(f["chin_y"] + te * self.H))]
        q = [complex(f["side_ear"][0] / sx, f["side_ear"][1] / sy), complex(f["side_eye"][0] / sx, f["side_eye"][1] / sy)]
        a = (q[1] - q[0]) / (g[1] - g[0])
        b = q[0] - a * g[0]
        w = a * (-P[..., 2] - 1j * P[..., 1]) + b
        return w.real * sx / self.iw, w.imag * sy / self.ih

    # ------------------------------------------------------------------ orecchie
    def ear_frame(self, side):
        """Centro e orientamento dell'orecchio (side = +1 destra, -1 sinistra)."""
        f = self.f
        t0, t1 = self.t_of_py(f["ear_px"][1]), self.t_of_py(f["ear_px"][0])
        tc = (t0 + t1) / 2
        x = float(self.half_width(tc)) * self.H + 0.002
        c = np.array([side * x, f["chin_y"] + tc * self.H, 0.012])
        h = (t1 - t0) * self.H / 2                # mezza altezza
        return c, h

    def ear_point(self, side, th, s):
        """Conchiglia schiacciata: th intorno, s dal lato attaccato alla testa (0) a quello esterno (1)."""
        c, h = self.ear_frame(side)
        ph = (s - 0.5) * math.pi                  # -pi/2 .. pi/2
        # ellisse dell'orecchio: alto h, profondo 0.55 h, spesso 0.22 h; più largo in alto (lobo stretto)
        cy, sy = np.cos(ph), np.sin(ph)
        up = np.sin(th)
        wid = 0.55 * h * (0.85 + 0.25 * up)
        ly = h * up * cy
        lz = wid * np.cos(th) * cy
        r2 = (np.sin(th) * cy) ** 2 + (np.cos(th) * cy) ** 2
        lx = 0.28 * h * sy
        lx = lx - 0.14 * h * np.clip(sy, 0, 1) * (1 - r2) * 2.4   # conca: il centro esterno rientra
        p = np.stack([lx, ly, lz], -1)
        # ruota: bordo posteriore in fuori (25°) e cima un po' indietro (12°)
        a, b = math.radians(32), math.radians(12)
        ry = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
        rx = np.array([[1, 0, 0], [0, math.cos(b), -math.sin(b)], [0, math.sin(b), math.cos(b)]])
        p = p @ (rx @ ry).T
        p[..., 0] *= side
        return p + c


def grid_mesh(fn, seg, rings, close=True):
    """Mesh da una funzione fn(th, s) -> punti, th in -pi..pi (colonne), s in 0..1 (righe, poli esclusi).
    Ritorna verts, faces, uvs (u = (th + pi) / 2pi, v = s)."""
    ss = (np.arange(rings) + 0.5) / rings
    th = -math.pi + 2 * math.pi * np.arange(seg) / seg
    S, TH = np.meshgrid(ss, th, indexing="ij")
    P = fn(TH, S).reshape(-1, 3)
    verts = list(P)
    faces, uvs = [], []
    for j in range(rings - 1):
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((j * seg + i, j * seg + i1, (j + 1) * seg + i1, (j + 1) * seg + i))
            uvs.append(((i / seg, ss[j]), ((i + 1) / seg, ss[j]), ((i + 1) / seg, ss[j + 1]), (i / seg, ss[j + 1])))
    if close:
        bot = fn(np.zeros(1), np.zeros(1))[0]
        top = fn(np.zeros(1), np.ones(1))[0]
        cb = len(verts)
        verts += [bot, top]
        for i in range(seg):
            i1 = (i + 1) % seg
            faces.append((cb, i1, i))
            faces.append((cb + 1, (rings - 1) * seg + i, (rings - 1) * seg + i1))
            uvs.append((((i + 0.5) / seg, 0.0), (i1 / seg if i1 else 1.0, ss[0]), (i / seg, ss[0])))
            uvs.append((((i + 0.5) / seg, 1.0), (i / seg, ss[-1]), ((i + 1) / seg, ss[-1])))
    return np.array(verts), faces, uvs


def grid_surface(fn, W, Hh, center_fn):
    """Punti e normali (verso fuori) su una griglia fitta W x Hh nello spazio UV della grid_mesh."""
    u = (np.arange(W) + 0.5) / W
    v = (np.arange(Hh) + 0.5) / Hh
    V, U = np.meshgrid(v, u, indexing="ij")
    th = -math.pi + 2 * math.pi * U
    e = 1e-3
    P = fn(th, V)
    dth = fn(th + e, V) - fn(th - e, V)
    ds = fn(th, np.clip(V + e, 0, 1)) - fn(th, np.clip(V - e, 0, 1))
    N = np.cross(dth, ds)
    out = P - center_fn(P)
    N = N * np.where(np.sum(N * out, -1, keepdims=True) < 0, -1, 1)
    N /= np.linalg.norm(N, axis=-1, keepdims=True) + 1e-12
    return P, N
