extends RefCounted
## TUTTI I NUMERI DI BILANCIAMENTO DEL GIOCO, IN UN POSTO SOLO.
## I personaggi (data/characters.gd) sono tutti uguali come abilità: cambia solo l'aspetto.
## Le armi (danno, cadenza, caricatore...) sono in data/weapons.gd.
## Le misure della stanza sono in world/room.gd.

## Scala del mondo: 1 metro reale = 18 metri di gioco (un omino di 10 cm diventa alto 1,8 m).
const S := 18.0

# --- livelli di collisione (bit) -------------------------------------------
const LAYER_WORLD := 1      # stanza e mobili
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4      # nemici; in multiplayer anche gli omini degli altri giocatori (actors/avatar.gd)

# --- giocatore (uguale per tutti i personaggi) ---------------------------------
const PLAYER_HP := 100.0
const PLAYER_WALK := 6.0
const PLAYER_SPRINT := 11.0       # correndo (Shift o tasto laterale del mouse)
const PLAYER_CROUCH := 3.0
const PLAYER_PRONE := 1.6         # strisciando a terra (Z)
const PLAYER_JUMP := 6.5          # salto normale (Spazio): circa 1,3 m di gioco
const PLAYER_SUPER_JUMP := 10.5   # SUPER SALTO (B): altezza in metri di gioco
                                  # Il sedile delle sedie è a ~9 m (50 cm reali): così dal pavimento ci arrivi
const SLIDE_BOOST := 1.35         # scivolata (Ctrl mentre corri): parte a velocità di corsa x questo...
const SLIDE_TIME := 0.75          # ...e rallenta fino a fermarsi in questi secondi
const GRAVITY := 16.0
const PLAYER_HEIGHT := 1.8
const PLAYER_CROUCH_HEIGHT := 1.0
const PLAYER_PRONE_LENGTH := 1.8  # sdraiato a terra: la capsula diventa orizzontale, lunga così
const PLAYER_RADIUS := 0.35
const STEP_HEIGHT := 0.6          # gradini saliti senza saltare (tastiere, libri)
const MAX_SLOPE_DEG := 46.0       # pendenza massima su cui si cammina (la rampa è a 37°)
const RELOAD_TIME := 1.6
const WEAPON_SWITCH_TIME := 0.35  # dopo aver cambiato arma non si spara per questi secondi
const MOUSE_SENSITIVITY := 0.0025

# --- munizioni a terra (game/munizioni.gd): scatole di graffette -------------------
const PICKUP_FIRST := 8.0         # secondi prima della prima scatola
const PICKUP_INTERVAL := 15.0     # poi ne compare una ogni tanti secondi...
const PICKUP_MAX := 3             # ...finché a terra ce ne sono al massimo tante
const PICKUP_CLIPS := 1           # caricatori in più per OGNI arma quando ne prendi una

# --- multiplayer (game/rete.gd) ---------------------------------------------------
const PVP_DAMAGE := 5.0           # danno a un altro giocatore = danno dell'arma x questo (vita 100)
const HEADSHOT_MULT := 3.0        # colpo in testa: danno x questo
const RESPAWN_TIME := 3.0         # secondi a terra prima di rientrare in partita
const SPAWN_SPREAD := 1.2         # distanza tra i punti di comparsa dei giocatori (metri di gioco)

# --- telecamera in terza persona (actors/follow_camera.gd), metri di gioco -------
const TP_FOV := 70.0
const TP_ADS_FOV := 52.0          # mirando (click destro)
const TP_DISTANCE := 3.4          # distanza dietro l'omino
const TP_ADS_DISTANCE := 1.7
const TP_SHOULDER := 0.65         # spostamento a destra (visuale da sopra la spalla)
const TP_ADS_SHOULDER := 0.5
const TP_LIFT := 0.45             # quanto sta più in alto delle spalle dell'omino
const TP_PITCH_LIMIT := 1.2       # quanto si può guardare in su/giù (radianti)
const TP_CAM_RADIUS := 0.22       # "ingombro" della telecamera: non si avvicina ai muri più di così
const TP_FADE_START := 1.4        # sotto questa distanza l'omino comincia a sparire...
const TP_FADE_END := 0.85         # ...e sotto questa è invisibile (non copre la visuale)
const TP_FRONT_DISTANCE := 3.6    # visuale frontale (V): telecamera davanti all'omino, che guarda verso di te
const TP_SPRINT_FOV := 78.0       # correndo la visuale si allarga un po'
