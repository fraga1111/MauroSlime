---
name: bilancia
description: Cambiare numeri di gioco di Mauro of Duty (vita, velocità, salto, danno, cadenza, munizioni, ondate, slime, boss) senza toccare la logica.
---

# /bilancia — solo numeri

## Leggi SOLO questo
- Giocatore, telecamere, ondate, slime, munizioni, multiplayer, colpi in testa → `StanzaFPS/scripts/config.gd` (piccolo).
- Danno, cadenza, caricatore di un'arma → `StanzaFPS/scripts/data/weapons.gd`.
Nient'altro: la logica legge già questi numeri.

## Passi
1. Cambia i valori, dì all'utente prima → dopo (es. "vita 100 → 150").
2. Alla fine, UNA volta: `bash tools/check.sh --rapido` (niente screenshot).
   Solo se hai toccato salto/velocità/scivolata: `bash tools/check.sh` completo (ha i test delle mosse).
