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
const LAYER_VEHICLE := 8    # macchinina e aeroplanino (actors/veicolo.gd): ci si sbatte contro, i colpi passano

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

# --- veicoli (actors/veicolo.gd): E per salire e scendere -----------------------------
const ENTER_DISTANCE := 4.5       # quanto vicino devi essere per salire (metri di gioco, dal centro)

# --- macchinina (actors/macchinina.gd), metri di gioco al secondo ------------------
const CAR_MAX_SPEED := 18.0       # col gas (W)
const CAR_TURBO_SPEED := 27.0     # col gas + Shift
const CAR_REVERSE := 7.0          # in retromarcia (S da fermo)
const CAR_ACCEL := 12.0           # quanto in fretta prende velocità
const CAR_BRAKE := 30.0           # quanto frena (S mentre vai avanti)
const CAR_DRAG := 4.0             # senza gas rallenta da sola così
const CAR_STEER := 0.6            # sterzata massima delle ruote (radianti; ad alta velocità meno)
const CAR_CAM_DISTANCE := 8.0     # telecamera dietro la macchinina

# --- aeroplanino di carta (actors/aeroplanino.gd) ------------------------------------
const PLANE_MAX_SPEED := 26.0     # con W tenuto
const PLANE_CRUISE := 15.0        # in volo senza toccare niente
const PLANE_MIN_FLY := 8.0        # sotto questa velocità non regge e scende (e da terra non decolla)
const PLANE_ACCEL := 9.0
const PLANE_TURN := 1.6           # quanto in fretta gira verso dove punti (radianti al secondo)
const PLANE_CAM_DISTANCE := 9.0   # telecamera dietro l'aeroplanino

# --- partita OFFLINE: ondate di nemici (game/ondate.gd) -----------------------------
# I nemici sono gli omini del menu (data/characters.gd) che ti sparano (actors/nemico.gd).
# Ogni ondata ce ne sono di più e sono più forti: valore = BASE + ondata * PER_ONDATA (con un limite).
const WAVE_FIRST_DELAY := 3.0     # secondi prima della prima ondata
const WAVE_NEXT_DELAY := 5.0      # pausa tra un'ondata e l'altra
const WAVE_SPAWN_INTERVAL := 1.2  # secondi tra un nemico e il successivo
const WAVE_BASE_COUNT := 2        # nemici nell'ondata = BASE + ondata * PER_WAVE
const WAVE_COUNT_PER_WAVE := 1
const WAVE_MAX_ALIVE := 7         # mai più di tanti nemici vivi insieme (gli altri aspettano)
const WAVE_DESK_FROM := 3         # da quale ondata compaiono nemici sopra le scrivanie
const WAVE_MIN_SPAWN_DIST := 18.0 # non compaiono più vicini di così al giocatore (metri di gioco)
const WAVE_CLEAR_HEAL := 35.0     # vita restituita a fine ondata
const WAVE_CLEAR_CLIPS := 1       # caricatori in più per ogni arma a fine ondata
const WAVE_BOSS_EVERY := 5        # ogni tante ondate arriva un CAPO (più grosso, tanta vita)

const ENEMY_HP := 6.0             # vita (i colpi delle armi fanno 1-3)
const ENEMY_HP_PER_WAVE := 1.5
const ENEMY_SPEED := 4.0          # metri di gioco al secondo
const ENEMY_SPEED_PER_WAVE := 0.3
const ENEMY_MAX_SPEED := 8.0
const ENEMY_DAMAGE := 3.0         # danno di ogni colpo che ti prende (vita 100)
const ENEMY_DAMAGE_PER_WAVE := 0.5
const ENEMY_MAX_DAMAGE := 9.0
const ENEMY_FIRE_DELAY := 0.55    # secondi tra un colpo e l'altro della raffica
const ENEMY_FIRE_DELAY_MIN := 0.18
const ENEMY_BURST := 3            # colpi per raffica (+1 ogni 3 ondate)...
const ENEMY_BURST_PAUSE := 1.6    # ...poi si ferma un attimo (meno con le ondate)
const ENEMY_SPREAD := 0.09        # imprecisione in radianti (più basso = mira meglio)
const ENEMY_SPREAD_MIN := 0.025
const ENEMY_REACTION := 0.9       # secondi prima di sparare quando ti vede
const ENEMY_REACTION_MIN := 0.25
const ENEMY_RANGE := 45.0         # da quanto lontano ti spara (metri di gioco)
const ENEMY_KEEP_DIST := 9.0      # se ti vede si ferma a questa distanza e spara
const ENEMY_HIT_RADIUS := 0.45    # quanto vicino al tuo petto deve passare il colpo per prenderti
const ENEMY_TRACER := Color(1.0, 0.3, 0.2)   # colore dei colpi dei nemici (se l'arma non ne ha uno)
const BOSS_SCALE := 1.6
const BOSS_HP_MULT := 5.0
const BOSS_DAMAGE_MULT := 1.5

# --- CO-OP online (game/ondate.gd con net = true): ondate contro tutti i giocatori insieme -----
const COOP_EXTRA_PER_PLAYER := 0.5   # nemici in più per ogni giocatore oltre al primo (0,5 = +50%)
const COOP_SEND_RATE := 20.0         # aggiornamenti al secondo delle posizioni dei nemici

# --- multiplayer (game/rete.gd) ---------------------------------------------------
const PVP_DAMAGE := 5.0           # (solo TUTTI CONTRO TUTTI) danno a un altro giocatore = danno dell'arma x questo (vita 100)
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
