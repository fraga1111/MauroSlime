---
name: stanza
description: Spostare, aggiungere o cambiare mobili e oggetti dell'ufficio di Mauro of Duty (room.gd), luci, texture.
---

# /stanza — ufficio, mobili, luci

## Leggi SOLO questo
1. Le prime ~50 righe di `StanzaFPS/scripts/world/room.gd`: indice delle sezioni + misure (W D H T, bordi isola).
2. Poi Grep `func _nome_sezione` e leggi SOLO quella funzione.
3. Firme delle funzioni di costruzione (box, cyl, quad, lbox, xf…): Grep `^func` in `scripts/world/kit.gd`, non leggerlo tutto.
4. Texture nuova: aggiungi una funzione statica in `scripts/world/textures.gd`.

## Regole
- Metri REALI (kit.gd moltiplica per S=18). `pos` = centro della base. `collide=false` per i dettagli piccoli.
- Assi: -Z finestre, +Z porta, -X ovest, +X est.
- Se sposti mobili grossi controlla che non coprano `PLAYER_SPAWN`, `ENEMY_SPAWNS`, `PICKUP_SPOTS` (in room.gd) e la rampa.

## Fine
UNA volta: `/prova` (riga "Stanza / mobili").
