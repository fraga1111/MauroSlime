---
name: arma
description: Aggiungere o cambiare un'arma di Mauro of Duty (dati in weapons.gd, modello in gun_models.gd, colpi colorati).
---

# /arma — nuova arma o modifica

## Leggi SOLO questo
1. `StanzaFPS/scripts/data/weapons.gd` (spiegazione dei campi in cima, blocchi in `LIST`).
2. Per il modello: in `scripts/actors/gun_models.gd` Grep `match kind` e leggi SOLO il caso dell'arma più simile.
3. Colpi/macchie: campi `tracer` e `splat` in weapons.gd (non serve aprire effetti.gd).

## NON leggere
player.gd (lo sparo usa già i dati), menu.gd (il pulsante si crea da solo), room.gd.

## Passi
1. Copia un blocco in `LIST`, cambia nome, `model`, danno, cadenza, caricatore.
2. Nuovo caso in `match kind` di gun_models.gd: lascia il nodo `Muzzle`, `red_dot = false` per oggetti d'ufficio.
   Per ingrandirla in mano: `size = 2.0` (il doppio) e `back_z` = z del fondo, che resta fermo contro il petto.
3. Solo numeri cambiati? niente screenshot.
4. Alla fine, UNA volta: `/prova` (riga "Un'arma" oppure "Solo numeri").
