---
name: prova
description: Controllo FINALE di MauroSlime dopo una modifica (check.sh rapido o completo + solo gli screenshot che servono). Usala una volta sola, alla fine del lavoro, non dopo ogni singola modifica.
---

# /prova — controllo finale, una volta sola

Da Git Bash nella cartella `StanzaFPS`. Scegli il controllo più LEGGERO che copre la modifica:

| Cosa è cambiato | Comando | Screenshot da guardare |
|---|---|---|
| Solo numeri (config.gd, weapons.gd) o testi | `bash tools/check.sh --rapido` | nessuno |
| Un personaggio (characters.gd, looks, .glb) | `bash tools/check.sh --rapido --char=N --solo=ritratti,menu` | ritratti.png, menu.png |
| Un'arma (weapons.gd, gun_models.gd) | `bash tools/check.sh --rapido --solo=armi,terza_persona` | armi.png, terza_persona.png |
| Stanza / mobili (room.gd, kit.gd, textures.gd) | `bash tools/check.sh --solo=stanza_dall_alto,sopra_la_scrivania,rampa` | quelli tre |
| HUD o menu | `bash tools/check.sh --rapido --solo=menu,terza_persona` | menu.png, terza_persona.png |
| Macchinina o aeroplanino (aspetto) | `bash tools/check.sh --rapido --solo=garage,macchinina,aeroplanino` | quelli tre |
| Movimento, telecamera, player.gd, veicoli (guida/volo), slime, ondate, rete | `bash tools/check.sh` (completo, con i test) | nessuno, salvo grafica |
| Tante cose insieme o prima di un commit | `bash tools/check.sh --shots` | tutti |

Regole:
- `N` = posizione del personaggio in `LIST` di `scripts/data/characters.gd` (0 = il primo).
- `--solo=` fa solo gli screenshot nominati (nomi elencati in cima a `tools/check.sh`).
- Guarda con Read SOLO i png della tabella, in `StanzaFPS/tools/shots/`.
- Se esce "CI SONO ERRORI": leggi le righe d'errore stampate, correggi, rilancia lo STESSO comando.
- Fine: "TUTTO OK" + cosa hai visto negli screenshot, detto in breve all'utente in italiano.
