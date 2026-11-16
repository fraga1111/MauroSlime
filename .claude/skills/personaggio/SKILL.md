---
name: personaggio
description: Aggiungere o cambiare un personaggio giocabile di MauroSlime (omino a blocchi, persona vera con foto o con modello Blender). Dice quali file leggere e quali NO.
---

# /personaggio — nuovo personaggio o modifica

## Leggi SOLO questo
1. `StanzaFPS/scripts/data/characters.gd` (piccolo: leggilo tutto). Ogni blocco `{...}` di `LIST` = una scheda del menu; il menu e i tasti 1–9 si fanno da soli.
2. Solo se serve:
   - copricapo nuovo → in `scripts/actors/character_model.gd` Grep `d.get("hat"` (è in `_build_soldier`) e leggi solo quel `match`;
   - persona vera con FOTO → blocco in `scripts/data/looks.gd` + ritagli `CROPS` in `tools/foto_personaggi.py`;
   - persona vera da SCANSIONE 3D del telefono → usa `/scansione`;
   - modello Blender da looks.gd → `tools/blender_persona.py` (vedi riga nella tabella di CLAUDE.md).

## NON leggere
player.gd, room.gd, menu.gd, menu_stage.gd, main.gd, slime.gd, rete.gd: non servono per un personaggio.

## Passi
1. Copia il blocco più simile in `LIST` (soldatino: MAURO; persona con modello: ANTONINO) e cambia nome, colori, `accent`, `scale`.
2. Persona con modello: `"look": "nome"` e serve `StanzaFPS/modelli/nome.glb`.
3. Se i personaggi diventano più di 6: in `StanzaFPS/tools/check.sh` allunga il `for c in 0 1 2 3 4 5`.
4. Alla fine, UNA volta: `/prova` (riga "Un personaggio").
