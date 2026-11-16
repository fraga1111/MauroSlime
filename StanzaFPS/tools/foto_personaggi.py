"""RITAGLI DELLE FOTO PER I PERSONAGGI "VERI" (Matteo, Broski).

Prende le foto in ../persongg/, ritaglia testa, busto e gambe viste da davanti, da dietro e di fianco,
toglie lo sfondo (muro, pavimento, mobili) allargando i colori della persona, e salva le texture in
textures/persone/<nome>_<parte>_<vista>.png. Le usa actors/character_model.gd (_build_photo_person).

Uso (dalla cartella StanzaFPS):   python tools/foto_personaggi.py          -> rigenera le texture
                                  python tools/foto_personaggi.py --prova  -> in più salva tools/shots/ritagli_*.png
Per correggere un ritaglio cambia il rettangolo in CROPS: [sinistra, alto, destra, basso] in pixel della foto.
I ritagli della stessa parte devono avere gli stessi riferimenti (es. testa: da cima dei capelli al mento).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FOTO = os.path.join(HERE, "..", "..", "persongg")
OUT = os.path.join(HERE, "..", "textures", "persone")
P = "WhatsApp Image 2026-11-13 at "

# foto usate per ogni persona: davanti, dietro, fianco (fianco = profilo con il naso verso DESTRA)
PHOTOS = {
    "matteo": {"front": "matteo/" + P + "10.37.43.jpeg",
               "back": "matteo/" + P + "10.37.44 (2).jpeg",
               "side": "matteo/" + P + "10.37.44 (5).jpeg"},
    "broski": {"front": "broski/" + P + "10.37.44 (8).jpeg",
               "back": "broski/" + P + "10.37.45.jpeg",
               "side": "broski/" + P + "10.37.45 (3).jpeg",
               "side_testa": "broski/" + P + "15.17.12 (1).jpeg",    # primi piani (testa intera)
               "back_testa": "broski/" + P + "15.17.11.jpeg"},
}

# parte -> vista -> [sinistra, alto, destra, basso] in pixel della foto ("foto" = un'altra foto della stessa persona).
# Una vista può essere un dizionario: {"box": [...], "foto": "front", "rot": gradi, "flip": True}
#   rot  raddrizza la testa (profili presi a testa china)     flip  rovescia in orizzontale
# keep = ovale [sinistra, alto, destra, basso] in px del ritaglio FINALE dove non si toglie mai lo "sfondo"
#        (il bianco degli occhi e i riflessi somigliano al muro bianco: senza keep diventano pelle)
# pad = colore per le parti fuori dalla foto (es. cima della testa tagliata: colore dei capelli)
# Gambe: ritaglio della SOLA gamba destra del personaggio (la sinistra la usa specchiata).
CROPS = {
    "matteo": {
        "head": {"size": (256, 320), "bg": "wall",
                 "front": [592, 80, 803, 398], "back": [602, 170, 800, 430],
                 "side": {"box": [630, 140, 890, 420], "rot": 18}},
        "torso": {"size": (256, 384), "bg": "wall_bright",
                  "front": [592, 425, 878, 1150], "back": [490, 445, 870, 1140],
                  "side": {"box": [775, 425, 850, 1100], "foto": "front"}},
        "legs": {"size": (128, 512), "bg": "dark",
                 "front": [538, 1120, 712, 1700], "back": [640, 1140, 800, 1800],
                 "side": [530, 1160, 750, 1810]},
    },
    "broski": {
        "head": {"size": (256, 320), "bg": "wall",
                 "front": [590, 138, 836, 498], "keep": [40, 120, 200, 300],
                 "back": {"box": [590, 610, 1080, 1300], "foto": "back_testa"},
                 "side": {"box": [490, 575, 1040, 1170], "foto": "side_testa"}},
        "torso": {"size": (256, 384), "bg": "wall",
                  "front": [540, 505, 885, 1235], "back": [505, 205, 935, 1160],
                  "side": {"box": [640, 230, 800, 1160], "foto": "back"}},
        "legs": {"size": (128, 512), "bg": "jeans",
                 "front": [452, 1235, 672, 1830], "back": [610, 1140, 890, 1960],
                 "side": [380, 1090, 760, 1940]},
    },
}


def background(rgb: np.ndarray, kind: str) -> np.ndarray:
    """True dove il pixel è sfondo (da riempire)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    if kind == "wall_bright":   # solo muro molto chiaro (quando la maglia stessa è grigia)
        return (mx > 0.84) & (sat < 0.1)
    if kind == "wall":      # muro bianco/grigio chiaro poco saturo
        return (mx > 0.6) & (sat < 0.14)
    if kind == "dark":      # pantaloni neri: sfondo = tutto ciò che è chiaro
        return mx > 0.33
    if kind == "jeans":     # jeans azzurri: sfondo = ciò che non è azzurro
        return ~((b - r > 0.07) & (mx > 0.35))
    return np.zeros(rgb.shape[:2], bool)


def fill(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Riempie lo sfondo con i colori vicini della persona, sfumati (piramide di medie pesate)."""
    known = (~bg).astype(np.float32)
    if known.sum() == 0:
        return rgb
    levels = [(rgb * known[..., None], known)]
    while min(levels[-1][1].shape) > 2:
        c, k = levels[-1]
        h, w = (k.shape[0] // 2) * 2, (k.shape[1] // 2) * 2
        c2 = c[:h, :w].reshape(h // 2, 2, w // 2, 2, 3).sum((1, 3))
        k2 = k[:h, :w].reshape(h // 2, 2, w // 2, 2).sum((1, 3))
        levels.append((c2, k2))
    c, k = levels[-1]
    est = c / np.maximum(k, 1e-6)[..., None]
    for c, k in reversed(levels[:-1]):
        up = np.stack([np.asarray(Image.fromarray(est[..., i].astype(np.float32), "F")
                                  .resize((k.shape[1], k.shape[0]), Image.BILINEAR)) for i in range(3)], -1)
        a = np.clip(k, 0, 1)[..., None]
        est = np.where(k[..., None] > 0, c / np.maximum(k, 1e-6)[..., None], up) * a + up * (1 - a)
    return np.where(bg[..., None], est, rgb)


def crop(photos: dict, view: str, spec, pad) -> Image.Image:
    """Ritaglio che può uscire dalla foto: le parti fuori prendono il colore pad, con un po' di
    "ciocche" finte (o, senza pad, vengono riempite come lo sfondo)."""
    if not isinstance(spec, dict):
        spec = {"box": spec}
    pad = spec.get("pad", pad)
    img = photos[spec.get("foto", view)].convert("RGBA")
    if spec.get("rot"):
        img = img.rotate(spec["rot"], resample=Image.BICUBIC,
                         center=((spec["box"][0] + spec["box"][2]) / 2, (spec["box"][1] + spec["box"][3]) / 2))
    l, t, r, b = spec["box"]
    out = Image.new("RGBA", (r - l, b - t), (0, 0, 0, 0))
    if pad:
        rng = np.random.default_rng(1)
        h, w = b - t, r - l
        streak = rng.normal(0, 1, (1, w)).repeat(h, 0) * 0.6 + rng.normal(0, 1, (h, w)) * 0.4
        streak = np.asarray(Image.fromarray(streak.astype(np.float32), "F").resize((w, h)))
        hair = np.clip(np.array(pad, np.float32)[None, None, :] * (1 + 0.25 * streak[..., None]), 0, 255)
        out = Image.fromarray(np.dstack([hair, np.full((h, w), 254, np.float32)]).astype(np.uint8), "RGBA")
    out.alpha_composite(img.crop((max(l, 0), max(t, 0), min(r, img.width), min(b, img.height))),
                        (max(-l, 0), max(-t, 0)))
    if spec.get("flip"):
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    return out


def main() -> None:
    prova = "--prova" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    for who, parts in CROPS.items():
        photos = {v: Image.open(os.path.join(FOTO, f)) for v, f in PHOTOS[who].items()}
        sheet = []
        for part, spec in parts.items():
            for view in ("front", "back", "side"):
                im = crop(photos, view, spec[view], spec.get("pad")).resize(spec["size"], Image.LANCZOS)
                a = np.asarray(im).astype(np.float32) / 255.0
                rgb, alpha = a[..., :3], a[..., 3]
                oob = alpha < 0.5                      # fuori dalla foto
                bg = (background(rgb, spec["bg"]) & ~oob) | oob
                if view == "front" and "keep" in spec:          # dentro la faccia niente "sfondo"
                    x0, y0, x1, y1 = spec["keep"]
                    yy, xx = np.mgrid[0:bg.shape[0], 0:bg.shape[1]]
                    inside = (((xx - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 2
                              + ((yy - (y0 + y1) / 2) / ((y1 - y0) / 2)) ** 2) < 1
                    bg &= ~inside
                res = fill(rgb, bg)
                # trasparenza = sagoma della persona (un po' ristretta e sfumata): il gioco usa la foto
                # solo dove c'è la persona, altrove prende un'altra vista
                m = Image.fromarray(((~bg) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
                m = np.asarray(m.filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255.0
                if part == "head" and view == "front":
                    hair_band = res[16:52, 60:196]
                if part == "head" and view != "front" and oob.any():
                    # testa tagliata in alto nella foto: ci mettiamo i capelli presi dalla foto davanti
                    hh, ww = oob.shape
                    tile = np.stack([np.asarray(Image.fromarray(hair_band[..., i].astype(np.float32), "F")
                                              .resize((ww, hh), Image.BICUBIC)) for i in range(3)], -1)
                    f = np.asarray(Image.fromarray((oob * 255).astype(np.uint8)).filter(
                        ImageFilter.GaussianBlur(8))).astype(np.float32)[..., None] / 255.0
                    f = np.clip(f * 2.0, 0, 1)
                    res = res * (1 - f) + tile * f
                    m = np.maximum(m, f[..., 0])
                out = Image.fromarray((np.clip(np.dstack([res, m]), 0, 1) * 255).astype(np.uint8), "RGBA")
                out.save(os.path.join(OUT, f"{who}_{part}_{view}.png"))
                if prova:
                    raw = im.convert("RGB")
                    sheet.append((f"{part} {view}", raw, out))
        if prova:
            w = sum(max(r.width, 128) for _, r, _ in sheet) + 10 * len(sheet)
            h = 2 * 512 + 40
            s = Image.new("RGB", (w, h), (60, 60, 70))
            d = ImageDraw.Draw(s)
            x = 0
            for name, raw, out in sheet:
                s.paste(raw, (x, 20))
                s.paste(out.convert("RGB"), (x, 40 + 512))
                d.text((x + 2, 2), name, fill=(255, 255, 255))
                x += max(raw.width, 128) + 10
            os.makedirs(os.path.join(HERE, "shots"), exist_ok=True)
            s.save(os.path.join(HERE, "shots", f"ritagli_{who}.png"))
    print("texture salvate in", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
