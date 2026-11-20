# Mauro of Duty (ex MauroSlime) — guida al progetto

Sparatutto in prima/terza persona fatto in **Godot 4.7.2 + GDScript**. Il giocatore è un omino alto
10 cm dentro un vero ufficio di circa 3 × 4,5 m (ricostruito dalle foto in `ft/`). GIOCA OFFLINE: ondate di nemici
(gli stessi omini del menu) che ti sparano, sempre più difficili. Online (OSPITA) si sceglie CO-OP (le stesse ondate tutti insieme)
o TUTTI CONTRO TUTTI. L'arma si sceglie nel menu; dopo ogni ondata un forziere ne dà una seconda (si portano 2 armi).
I nemici hanno un alone rosso e non usano mai i personaggi dei giocatori. Punti = danni fatti; a fine partita (e con Tab)
c'è la classifica con uccisioni e assist, e ogni partita finita va nello STORICO (record e classifica di tutti i tempi, tasto H nel menu).
**Tutto è generato da codice**: niente modelli 3D o scene da editor (c'è solo `main.tscn`, vuota).
Eccezioni: le texture delle persone vere (Matteo, Broski) sono ritagli delle loro foto (`StanzaFPS/textures/persone/`),
e una persona vera può avere un modello fatto in Blender (`StanzaFPS/modelli/<look>.glb`): se c'è, il gioco usa quello.
ANTONINO e MARIPA sono scansioni 3D fatte col telefono (app KIRI, `persongg/<nome>/`), adattate da `tools/blender_scan.py`.

Questa guida serve a chiunque modifichi il gioco (persone o IA). Lingua del progetto: **italiano**
(commenti, testi a schermo, nomi dei file di dati).

## Cartelle

```
MauroSlime/
├─ Gioca.bat               avvia il gioco: copia StanzaFPS in %LOCALAPPDATA%\MauroSlime, la prepara e la avvia da lì
│                          (così si gioca anche da una cartella OneDrive condivisa senza conflitti)
├─ Apri editor Godot.bat   apre il progetto nell'editor
├─ Godot/                  motore (Godot_v4.7.2-stable_win64.exe + _console.exe)
├─ ft/                     foto della stanza vera + planimetria.pdf (riferimento per room.gd)
├─ persongg/               foto delle persone vere (riferimento per data/looks.gd)
├─ blender/                file .blend delle persone (da aprire e ritoccare in Blender) + texture cotte
└─ StanzaFPS/              PROGETTO GODOT
   ├─ project.godot, main.tscn
   ├─ scripts/
   │  ├─ config.gd              TUTTI i numeri di bilanciamento + scala S + livelli di collisione
   │  ├─ main.gd                regia: stanza → menu → partita; collega i segnali
   │  ├─ data/characters.gd     i personaggi giocabili (dati puri): tutti uguali, cambia solo l'aspetto
│  ├─ data/weapons.gd        le armi (evidenziatore, spillatrice, telefono, spillatrice a pinza)
   │  ├─ data/looks.gd          aspetto delle persone vere (Matteo, Broski): forme arrotondate + foto
   │  ├─ data/looks_minecraft.gd  versione "Minecraft" (a cubi) di Matteo e Broski
   │  ├─ world/room.gd          DISPOSIZIONE dell'ufficio (solo layout, a sezioni)
   │  ├─ world/kit.gd           funzioni per costruire: box, cyl, sphere, quad, mat, emis, glass...
   │  ├─ world/textures.gd      texture procedurali (moquette, vista finestra, schermi...)
   │  ├─ world/world_setup.gd   ambiente/luce generale + mesh di navigazione dei nemici
   │  ├─ actors/player.gd       giocatore: movimento, telecamere 1ª/3ª persona, sparo
   │  ├─ actors/character_model.gd  omino a blocchi / persona con foto + animazioni (copricapi qui)
   │  ├─ actors/gun_models.gd   modelli delle armi (oggetti d'ufficio, ricostruiti dalle foto)
   │  ├─ actors/nemico.gd       nemico offline: un omino del menu che insegue e spara
   │  ├─ actors/avatar.gd       omino di un ALTRO giocatore in multiplayer (mosso dalla rete)
   │  ├─ actors/veicolo.gd      base dei veicoli: salire/scendere (E), posto a sedere, telecamera
   │  ├─ actors/macchinina.gd   Opel Agila bianca in scala 1:18, si guida (anche su per la rampa)
   │  ├─ actors/aeroplanino.gd  aeroplanino di carta a quadretti, si pilota in volo
   │  ├─ game/ondate.gd         ondate offline: quanti nemici, dove compaiono, quanto sono forti, punti
   │  ├─ game/input_setup.gd    tasti
   │  ├─ game/rete.gd           MULTIPLAYER in rete locale: ospita / unisciti, faro per trovare le partite, versione
   │  ├─ game/munizioni.gd      scatole di graffette a terra (un caricatore in più per ogni arma)
   │  ├─ game/punteggi.gd       punti (= danni), uccisioni, assist di ogni giocatore; classifica (offline e rete)
   │  ├─ game/storico.gd        storico delle partite e record (user://storico.json)
   │  ├─ game/forziere.gd       forziere di fine ondata: dà una seconda arma
   │  ├─ actors/effetti.gd      colpi luminosi (tracer) e segni sui muri (buco o macchia colorata)
   │  ├─ ui/hud.gd              interfaccia in partita
   │  ├─ ui/menu.gd             schede del menu iniziale
   │  └─ ui/menu_stage.gd       vetrina 3D del menu (omini + telecamera)
   ├─ modelli/                modelli .glb esportati da Blender (es. matteo.glb); li usa character_model.gd
   ├─ textures/persone/       ritagli delle foto di persongg/ (li crea tools/foto_personaggi.py)
   ├─ archivio_personaggi_cubetti/  vecchia versione a quadratini di Matteo e Broski
   └─ tools/
      ├─ check.sh               controllo completo (vedi "Verificare")
      ├─ test_nemici.gd         test ondate: i nemici compaiono, si avvicinano, sparano; l'ondata 2 è più forte
      ├─ test_coop.sh / .gd     test co-op: due copie del gioco (ospita + unisciti) contro le stesse ondate
      ├─ test_moves.gd          test di corsa, scivolata, a terra, visuale frontale, super salto (sedia)
      ├─ test_veicoli.gd        test di macchinina (gas, sterzo, rampa, scendere) e aeroplanino (decollo)
      ├─ test_novita.gd         test di classifica/assist, nemici (alone, niente tuo personaggio), forziere, zoom, storico
      ├─ ritratti.gd            screenshot di tutti i personaggi (davanti, 3/4, fianco, dietro)
      ├─ armi.gd                primo piano di tutte le armi (fianco, alto, dietro)
      ├─ graffette.gd           primo piano della scatola di graffette e delle macchie fluo
      ├─ blender_persona.py     crea in Blender una persona di looks.gd (.blend + modelli/<look>.glb)
      ├─ blender_scan.py        scansione 3D del telefono (.obj) -> persona del gioco (modelli/<look>.glb), gambe e scarpe inventate
      ├─ blender_testa.py       testa anatomica (naso, orbite, labbra, mento, orecchie) misurata sulla foto frontale
      ├─ foto_personaggi.py     ritaglia le foto di persongg/ in textures/persone/ (Python + Pillow + numpy)
      ├─ primo_piano.sh         primi piani di Matteo e Broski -> tools/shots/primi_piani.png
      └─ shots/                 screenshot generati da check.sh --shots
```

## Convenzioni (importanti)

- **Scala**: nella stanza e nei mobili si scrive in **metri reali**; `kit.gd` moltiplica per
  `Config.S = 18`. Personaggi, armi, velocità e telecamere sono invece in **metri di gioco**
  (omino = 1,8 m). Per passare da reale a gioco: `posizione_reale * Config.S`.
- **Assi** (come la planimetria vista dall'alto): `-Z` = parete con le 3 finestre, `+Z` = parete con la porta,
  `-X` = sinistra (ovest), `+X` = destra (est), `y = 0` pavimento. I personaggi guardano verso `-Z`.
- **In kit.gd**: `pos` = centro della **base** dell'oggetto; `look` = `Color` oppure `Material`;
  `collide=false` per i dettagli piccoli (tasti, penne, cavi) che non devono bloccare.
  Per mobili ruotati: `var o := xf(origine, gradi)` e poi `lbox(o, ...)` / `lcyl(o, ...)` in coordinate locali.
- **Pezzi uniti (prestazioni)**: box/cyl/quad... di kit.gd NON creano nodi: la grafica va in una mesh unica per
  materiale e le collisioni in un solo StaticBody3D; `finish()` alla fine di `build()` crea le mesh. Le funzioni non
  ritornano niente. Per una **stanza nuova** (corridoio...) metti `zona = "corridoio"` prima di costruirla: zone diverse
  restano mesh separate e la scheda video salta quelle che non si vedono. Misura con `--fps` (disegni e FPS).
- **Collisioni**: livelli in `config.gd` (`LAYER_WORLD=1`, `LAYER_PLAYER=2`, `LAYER_ENEMY=4`).
  I nemici camminano solo dove la mesh di navigazione lo permette: pendenza ≤ 40°,
  gradini ≤ 0,5 m di gioco. Il giocatore sale da solo i gradini ≤ 0,6 m di gioco (circa 3 cm reali).
- **Script**: non usare `class_name`. Ogni file si richiama con
  `const Nome := preload("res://scripts/...")`, e quella costante si può usare anche come tipo.
- **GDScript tipizzato**: `var x := qualcosa` dà errore se `qualcosa` è un Variant (elementi di Array o
  Dictionary, risultati di oggetti non tipizzati). In quei casi scrivi il tipo: `var c: Color = LISTA[i]`.
- I file `.uid` accanto agli script li crea Godot. Se sposti uno script, cancella il suo `.uid`.
  Se Godot fa cose strane dopo uno spostamento, cancella la cartella `StanzaFPS/.godot/` (è solo cache).

## Dove cambiare cosa

| Voglio… | File | Come |
|---|---|---|
| Cambiare vita, velocità, salto (uguali per tutti) | `config.gd` | sezione "giocatore" (`PLAYER_HP`, ...) |
| Cambiare danno, cadenza, caricatore di un'arma | `data/weapons.gd` | modifica i valori (sono spiegati in cima al file) |
| Aggiungere un'arma | `data/weapons.gd` + `actors/gun_models.gd` | copia un blocco `{...}` e fai il modello; il menu crea il pulsante da solo (in partita l'arma non si cambia) |
| Aggiungere un personaggio | `data/characters.gd` | copia un blocco `{...}`: il menu crea la scheda da solo (tasti 1–9) |
| Aggiungere una persona vera con le foto | `tools/foto_personaggi.py` + `data/looks.gd` + `data/characters.gd` | foto in `persongg/<nome>/`, rettangoli di ritaglio in `CROPS`, `python tools/foto_personaggi.py --prova`; poi copia un blocco di LOOKS (forme ad anelli) e metti `"look": "nome"` nel personaggio |
| Correggere un ritaglio di foto (faccia storta, sfondo che si vede) | `tools/foto_personaggi.py` | cambia il rettangolo in `CROPS`, rilancia lo script, poi `bash tools/primo_piano.sh` e guarda `tools/shots/primi_piani.png` |
| Modello Blender di una persona vera | `tools/blender_persona.py` | `blender.exe -b --factory-startup --python tools/blender_persona.py -- --look=matteo --render`; ritocchi in `blender/<look>.blend`, poi esporta glTF in `modelli/<look>.glb` (pezzi `GambaSX GambaDX Busto Testa Braccia`). Per tornare al modello da codice cancella il `.glb`. Testa realistica: punti della faccia (occhi, naso, bocca, sagoma) in `FIT` di `tools/blender_testa.py`; chi non è in `FIT` usa la vecchia testa a uovo. Primo piano: aggiungi `--testa` → `blender/<look>_primo_piano.png` |
| Persona da SCANSIONE 3D del telefono (es. Antonino, app KIRI: .obj + .jpg) | `tools/blender_scan.py` | `blender.exe -b --factory-startup --python tools/blender_scan.py -- --look=antonino --render --testa`; misure in `SCANS` (raddrizzare, collo, braccia, scala, gambe/scarpe inventate, triangoli e texture). `--punti` colora i pezzi per controllare i tagli, `--busto` primo piano di busto e braccia. Vestiti larghi con le maniche fuse al busto (Maripa): `code_arms` fa le braccia da codice e `side_trim` toglie i lembi rimasti. Le zone non viste dal telefono diventano materiali a tinta unita (maglia, pantaloni, pelle). Poi `"look": "nome"` nel personaggio (senza voce in looks.gd). Texture esportata in WebP: Godot non legge i JPEG scritti da Blender 5.3 |
| Versione Minecraft (a cubi) di una persona vera | `data/looks_minecraft.gd` | disegni a quadratini e blocchi; nel menu il pulsante ASPETTO (tasto T) sceglie BLENDER o MINECRAFT; da riga di comando `--minecraft` |
| Nuovo copricapo | `actors/character_model.gd` | nuovo caso nel `match` di `"hat"` in `setup()` |
| Nuova arma (aspetto) | `actors/gun_models.gd` | nuovo caso nel `match kind`; lascia il nodo `Muzzle`; `red_dot = false` per gli oggetti d'ufficio (niente mirino) |
| Ingrandire un'arma in mano (spillatrice e telefono sono al doppio) | `actors/gun_models.gd` | nel caso dell'arma `size = 2.0` e `back_z` = z del fondo (resta fermo, l'arma cresce in avanti) |
| Macchinina / aeroplanino: velocità, sterzo, volo | `config.gd` | sezioni "veicoli", "macchinina", "aeroplanino" |
| Macchinina / aeroplanino: aspetto, comandi, posto a sedere | `actors/macchinina.gd`, `actors/aeroplanino.gd` | `_build()` per il modello, `_physics_process` per la guida; dove stanno: `CAR_SPOT` / `PLANE_SPOT` in `world/room.gd`; salire/scendere in `actors/player.gd` (`enter_vehicle`, `exit_vehicle`) |
| Nuovo veicolo | `actors/veicolo.gd` | nuovo file con `extends "res://scripts/actors/veicolo.gd"` (come macchinina.gd), poi crealo in `_spawn_vehicles()` di `main.gd` |
| Cambiare difficoltà, numero di nemici, capo | `config.gd` | sezione "partita OFFLINE" (`WAVE_*`, `ENEMY_*`, `BOSS_*`): valore = base + ondata × aumento |
| Velocità base, salto, telecamera, FOV | `config.gd` | sezioni "giocatore" e "telecamere" |
| Super salto (B), corsa, scivolata (F, o Ctrl correndo), a terra (Z), visuale frontale (V) | `config.gd` + `actors/player.gd` | numeri in config (`PLAYER_SUPER_JUMP` è un'altezza: il sedile delle sedie è a ~9 m di gioco); logica in `_physics_process`; pose sdraiato/scivolata in `animate()` di `character_model.gd`; telecamera frontale in `follow_camera.gd` (`front`) |
| Spostare o aggiungere un mobile/oggetto | `world/room.gd` | nella sezione giusta (indice in cima al file) |
| Spostare monitor, tastiere o sedie delle postazioni | `world/room.gd` | tabella `STATIONS` |
| Cambiare le misure della stanza | `world/room.gd` | costanti `W D H T`, bordi isola `IX0..IZ1`, porta `DOOR_X0/X1` |
| Dove compaiono giocatore e nemici | `world/room.gd` | `PLAYER_SPAWN`, `ENEMY_SPAWNS` |
| Luci della stanza | `world/room.gd` | `_ceiling_and_lights()` (funzione `omni`) |
| Luce generale / atmosfera | `world/world_setup.gd` | `add_environment()` |
| Nuova texture (es. poster) | `world/textures.gd` | nuova funzione statica, poi in room.gd `quad(..., lit(Textures.nome()))` |
| Comportamento dei nemici | `actors/nemico.gd` | movimento e mira in `_physics_process`, sparo in `_shoot`, colpi presi in `take_hit`; personaggi e statistiche per ondata in `game/ondate.gd` (`_spawn`) |
| Multiplayer (ospita / unisciti, stessa rete) | `game/rete.gd`, `actors/avatar.gd`, `ui/menu.gd` | porta `PORT` (7777) e giocatori max in rete.gd; danno tra giocatori e rientro in `config.gd` (sezione multiplayer); pannello MULTIPLAYER al centro del menu (pulsante MULTIPLAYER o tasto M, `toggle_multiplayer`). La prima volta Windows chiede di consentire Godot sulla rete: rispondere Sì (reti private) |
| Co-op online (ondate tutti insieme) | `game/ondate.gd` (parte "rete"), `actors/nemico.gd` (`puppet`) | chi ospita comanda i nemici e li manda agli altri; gli altri hanno copie e mandano i colpi a chi ospita. Pulsante MODO nel menu (`coop` in `ui/menu.gd`); numeri in `config.gd` (sezione CO-OP). Chi muore rientra a fine ondata, se cadono tutti finisce |
| Munizioni a terra (graffette) | `config.gd` + `world/room.gd` | sezione "munizioni" (ogni quanto, quante, caricatori) e `PICKUP_SPOTS`; modello in `game/munizioni.gd` |
| Colpi colorati di un'arma | `data/weapons.gd` | campi `tracer` (colpo che vola) e `splat` (macchia sul muro) |
| Colpi in testa | `config.gd` | `HEADSHOT_MULT`; zona della testa in `actors/avatar.gd` (`take_hit`) |
| Punti, uccisioni, assist, classifica | `game/punteggi.gd` + `config.gd` | `POINTS_PER_DAMAGE`; chi avvisa: `nemico.gd apply_damage` (via `ondate.enemy_damaged`), `rete.gd _hit` (tutti contro tutti); classifica a schermo in `ui/hud.gd show_scoreboard` (Tab e fine partita, `_show_end` in main.gd) |
| Storico partite e record | `game/storico.gd` + `ui/menu.gd` | salvataggio in `main.gd _save_history`; record in `records()`, classifica di tutti i tempi in `leaderboard()`; pannello nel menu `toggle_history` (tasto H) |
| Forziere di fine ondata (seconda arma) | `game/forziere.gd` + `config.gd` | sezione "forziere" (`MAX_WEAPONS`...); lo crea `main.gd _spawn_chest`; armi portate in `player.gd` (`owned`, `give_weapon`) |
| Alone rosso dei nemici | `config.gd` + `actors/nemico.gd` | `ENEMY_AURA_COLOR`, `ENEMY_AURA_GROW`; shader `AURA_SHADER` |
| Zoom (click destro forte, doppio click leggero) | `config.gd` + `actors/player.gd` | `TP_ADS_FOV`, `TP_ADS_LIGHT_FOV`, `ZOOM_DOUBLE_CLICK`, `ZOOM_HOLD`; logica in `_zoom_click` |
| Tasti | `game/input_setup.gd` | dizionari `KEYS` e `MOUSE` |
| Testi e grafica di HUD e menu | `ui/hud.gd`, `ui/menu.gd` | |
| Posizione degli omini e della telecamera nel menu | `ui/menu_stage.gd` | costanti in cima (metri reali) |
| Vetrina del menu: buio, fari, piatti girevoli (omino e arma) | `ui/menu_stage.gd` | costanti in cima: `ROOM_DIM`/`AMBIENT_DIM` (quanto è buio), `PLATE_*`, `GUN_*`, `SPOT_*` (fari), `SPIN`/`KICK` (giro del piatto e giro in più quando scegli) |
| Logo del gioco | `textures/logo_mauro_of_duty.png` + `ui/menu.gd` (`_build_logo`) | il gioco si chiama **Mauro of Duty**; `config/name` in project.godot resta "MauroSlime FPS" apposta (da lì Godot sceglie la cartella dei salvataggi); il titolo della finestra lo mette `main.gd` |

**Se cambi la stanza**, controlla anche: `ENEMY_SPAWNS`, `PLAYER_SPAWN`, `CAR_SPOT` e `PLANE_SPOT` (non dentro i mobili),
le costanti di `ui/menu_stage.gd` (vetrina del menu), le pose di test in `main.gd` (`_apply_pose`)
e `tools/test_nemici.gd`. La **rampa** (`_ramp`) serve per salire sulle scrivanie:
se la togli, servono un'altra salita o un ponte.

### Esempio: aggiungere un oggetto alla stanza

```gdscript
# in world/room.gd, dentro la sezione adatta (es. _desk_clutter):
cyl(0.04, 0.1, Vector3(0.3, T, -0.7), mat(Color(0.9, 0.1, 0.1), 0.4))        # tazza rossa sull'isola
box(Vector3(0.3, 0.02, 0.2), Vector3(-1.2, 0, 0.3), Color(0.2, 0.2, 0.8), true, 30.0)  # libro sul pavimento ruotato di 30°
```

## Lavorare veloce (regole per l'IA)

- **Leggi solo il ramo che serve**: usa la tabella "Dove cambiare cosa" e i comandi su misura
  (`/personaggio`, `/scansione`, `/arma`, `/stanza`, `/bilancia`, in `.claude/skills/`). Nei file grossi
  (player.gd, character_model.gd, room.gd, blender_scan.py) trova la funzione con Grep e leggi solo quelle righe.
- **Prima tutte le modifiche, poi i controlli UNA volta sola alla fine** con `/prova`, che sceglie il controllo
  più leggero e solo gli screenshot che servono. Non lanciare check.sh dopo ogni singola modifica.

## Verificare (alla fine del lavoro)

Da Git Bash, nella cartella `StanzaFPS`:

```bash
bash tools/check.sh                       # completo: import, menu, tutti i personaggi, test rampa/telecamera/mosse/veicoli → "TUTTO OK"
bash tools/check.sh --rapido --char=N     # veloce: import, menu e UNA partita (per modifiche piccole)
bash tools/check.sh --solo=ritratti,menu  # solo gli screenshot nominati (nomi in cima a check.sh)
bash tools/check.sh --shots               # completo + tutti gli screenshot in tools/shots/ (prima di un commit)
```

Gli screenshot vanno **guardati** dopo modifiche grafiche o alla stanza (quali: vedi `/prova`).

Opzioni da riga di comando del gioco, utili per provare (`Godot..._console.exe --path . -- <opzioni>`):
`--autostart` (salta il menu), `--fps` o `--fps=SECONDI` (stampa FPS, disegni e triangoli ed esce; in partita F3 mostra/nasconde gli FPS), `--char=N`, `--weapon=N` (arma di partenza), `--fp` (prima persona), `--shot=percorso.png` (screenshot dopo 90 frame ed esce),
`--minecraft` (persone vere a cubi), `--nonemici` (offline senza ondate), `--forziere` / `--classifica` (forziere o classifica finta, per gli screenshot), `--storico` (menu con lo storico d'esempio aperto), `--nosalva` (non scrive lo storico), `--host` / `--join=IP` / `--name=NOME` (multiplayer), `--shotframe=N` (screenshot al fotogramma N), `--overview` / `--desk` / `--door` / `--garage` (posizioni della telecamera o del giocatore), `--front` (visuale frontale), `--prone` (sdraiato), `--guida` (seduto in macchinina), `--vola` (sull'aeroplanino in volo).
