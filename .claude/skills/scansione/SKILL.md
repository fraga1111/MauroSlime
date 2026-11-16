---
name: scansione
description: Trasformare una scansione 3D fatta col telefono (app KIRI, .obj + .jpg in persongg/<nome>/) in un personaggio di MauroSlime con tools/blender_scan.py.
---

# /scansione — persona vera da scansione 3D

## Leggi SOLO questo
- In `StanzaFPS/tools/blender_scan.py` NON leggere tutto (800 righe): leggi le righe 1–42 (spiegazione) e la tabella `SCANS` (riga ~43, ~120 righe).
- Copia il blocco di `maripa` (vestiti larghi, braccia da codice `code_arms`) o di `antonino` (braccia della scansione).
- Poi `/personaggio` per aggiungere `"look": "nome"` in characters.gd.

## Ciclo veloce (Blender 5.3, da Git Bash in StanzaFPS)
```
"/c/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --factory-startup --python tools/blender_scan.py -- --look=NOME --render --testa
```
- Guarda `../blender/NOME_anteprima.png` e `NOME_primo_piano.png`; aggiusta le misure in `SCANS`; ripeti.
- Strumenti di controllo: `--punti` (pezzi colorati: testa/busto/braccia/scarti), `--busto` (busto e braccia).
- Chiavi principali: `move/yaw/center` (raddrizzare), `k/hip/cut` (scala e taglio gambe), `neck_front/neck_back` (collo),
  `arm_r/arm_l` + `arm_radius` (braccia), `code_arms` + `side_trim` (maniche fuse al busto), `pale/hair_top_z` (cima capelli),
  `leg_scale/shoe_colors/pants` (gambe inventate), `tris` (triangoli: totale ≤ ~36k), `tex` (2048).
- Prima vai di anteprime Blender; il gioco (`/prova`) solo quando l'anteprima va bene.

## Trappole note
- Texture in WebP: Godot non legge i JPEG di Blender 5.3.
- Non cancellare i png in `../blender/` che non hai creato tu (es. `matteo_busto.png` è usato).
- Ruotare la testa con capelli lunghi lascia una riga: meglio `head_rot (0,0,0)`.
