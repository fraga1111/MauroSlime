extends Node3D
## REGIA DEL GIOCO: costruisce la stanza, mostra il menu, avvia la partita e collega i pezzi.
## Qui non ci sono numeri da bilanciare (stanno in config.gd) né oggetti della stanza (world/room.gd).
## Mappa completa del progetto: CLAUDE.md nella cartella principale.
##
## GIOCA OFFLINE: arrivano ondate di nemici (gli omini del menu, game/ondate.gd), sempre più difficili.
## Multiplayer (OSPITA / UNISCITI): in CO-OP le stesse ondate contro tutti i giocatori insieme
## (comanda chi ospita), oppure TUTTI CONTRO TUTTI senza nemici. Il modo lo sceglie chi ospita.

const Config := preload("res://scripts/config.gd")
const InputSetup := preload("res://scripts/game/input_setup.gd")
const WorldSetup := preload("res://scripts/world/world_setup.gd")
const Room := preload("res://scripts/world/room.gd")
const Characters := preload("res://scripts/data/characters.gd")
const Player := preload("res://scripts/actors/player.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const MenuStage := preload("res://scripts/ui/menu_stage.gd")
const Rete := preload("res://scripts/game/rete.gd")
const Munizioni := preload("res://scripts/game/munizioni.gd")
const Macchinina := preload("res://scripts/actors/macchinina.gd")
const Aeroplanino := preload("res://scripts/actors/aeroplanino.gd")
const Ondate := preload("res://scripts/game/ondate.gd")
const Punteggi := preload("res://scripts/game/punteggi.gd")
const Storico := preload("res://scripts/game/storico.gd")
const Forziere := preload("res://scripts/game/forziere.gd")
const Menu := preload("res://scripts/ui/menu.gd")

var player: Player
var macchinina: Macchinina        # Opel Agila bianca a terra (E per guidarla)
var aeroplanino: Aeroplanino      # aeroplanino di carta (E per pilotarlo)
var hud: Hud
var game_over := false
var _stage: MenuStage
var rete: Rete                    # multiplayer (game/rete.gd)
var munizioni: Munizioni          # scatole di graffette a terra
var ondate: Ondate                # partita offline: ondate di nemici
var nemici := true                # false = partita offline senza nemici (test automatici, --nonemici)
var _nav: NavigationRegion3D      # dove possono camminare i nemici (calcolata all'inizio della partita)
var player_index := 0            # personaggio scelto (serve alle ondate)
var _pending := []               # client: partita da avviare quando il collegamento riesce
var punteggi: Punteggi            # danni, punti, uccisioni e assist di ognuno (classifica)
var forziere: Forziere            # forziere di fine ondata (una seconda arma)
var _match_t0 := 0.0             # quando è iniziata la partita (per lo storico)
var _wave_pts0 := 0              # i miei punti all'inizio dell'ondata in corso
var _best_wave_pts := 0          # i miei punti nella mia ondata migliore (record nello storico)
var _saved := false              # partita già salvata nello storico

# opzioni da riga di comando, solo per test automatici (vedi CLAUDE.md):
#   --autostart  --char=N  --weapon=N  --minecraft  --host  --join=IP  --name=NOME  --shot=file.png  --overview | --desk | --door | --ramp | --wall | --back
#   --guida (seduto in macchinina)  --vola (sull'aeroplanino, già in volo)  --nosalva (niente storico)
var _shot_path := ""
var _shot_frames := 0
var _shot_at := 90               # --shotframe=N: fotogramma dello screenshot
var _auto := false
var _auto_char := 0
var _auto_weapon := 0
var _auto_style := ""
var _auto_net := ""              # "host" oppure l'IP a cui unirsi
var _auto_name := ""
var _auto_coop := true           # --pvp: ospita in TUTTI CONTRO TUTTI
var _pose := ""
var _bench := 0.0                # --fps: secondi di misura (stampa FPS e disegni, poi esce)
var _bench_t := 0.0
var _bench_frames := 0
var _extra: Array[String] = []


func _ready() -> void:
	# nome della finestra: config/name in project.godot resta "MauroSlime FPS" perché da lì Godot sceglie
	# la cartella dei salvataggi (user://: storico e multiplayer.cfg), che così non si perdono
	get_window().title = "Mauro of Duty"
	InputSetup.setup()
	WorldSetup.add_environment(self)
	_nav = NavigationRegion3D.new()          # la stanza sta qui dentro: i nemici camminano sui suoi mobili
	_nav.name = "Navigazione"
	add_child(_nav)
	var room := Node3D.new()                 # stanza e mobili (tutto ciò che ha una collisione)
	room.name = "Stanza"
	_nav.add_child(room)
	Room.new().build(room, self)

	rete = Rete.new()
	rete.name = "Rete"
	add_child(rete)
	rete.joined.connect(_on_joined)
	rete.join_failed.connect(_on_join_failed)
	rete.host_closed.connect(_on_host_closed)
	rete.coop_known.connect(func() -> void:
		if player and ondate == null and nemici:
			_start_waves(player_index))
	rete.message.connect(func(t: String) -> void:
		if hud:
			hud.show_message(t, 3.0))
	punteggi = Punteggi.new()
	punteggi.name = "Punteggi"
	punteggi.rete = rete
	rete.punteggi = punteggi
	add_child(punteggi)
	punteggi.changed.connect(_update_score)
	munizioni = Munizioni.new()
	munizioni.name = "Munizioni"
	add_child(munizioni)
	munizioni.picked.connect(func(t: String) -> void:
		if hud:
			hud.show_message(t, 1.5))

	_parse_debug_args()
	var nm := _auto_name if _auto_name != "" else "Giocatore"
	if _auto_net == "host":
		host_game(_auto_char, _auto_weapon, _auto_style, nm, _auto_coop)
	elif _auto_net != "":
		join_game(_auto_char, _auto_weapon, _auto_style, nm, _auto_net)
	elif _auto:
		start_game(_auto_char, _auto_weapon, _auto_style)
	else:
		show_menu()


func show_menu() -> void:
	_stage = MenuStage.new()
	add_child(_stage)
	_stage.start_game.connect(start_game)
	_stage.host_game.connect(host_game)
	_stage.join_game.connect(join_game)


# ---------------------------------------------------------------- multiplayer

func _net_info(index: int, weapon: int, stile: String, player_name: String) -> Dictionary:
	return {"name": player_name, "char": index, "weapon": weapon, "stile": stile, "ver": Rete.version()}


## OSPITA: apre la partita su questo computer e ci entra subito.
func host_game(index: int, weapon: int, stile: String, player_name: String, coop := true) -> void:
	rete.my_info = _net_info(index, weapon, stile, player_name)
	rete.my_info["coop"] = coop
	rete.coop = coop
	var err := rete.host()
	if err != OK:
		if _stage:
			_stage.set_net_status("Non riesco ad aprire la partita (porta %d occupata?)" % Rete.PORT)
		return
	start_game(index, weapon, stile)
	var ips := Rete.local_ips()
	hud.show_message("STAI OSPITANDO
Gli amici scrivono il tuo IP:  %s" % (", ".join(ips) if ips.size() > 0 else "?"), 8.0)


## UNISCITI: si collega a chi ospita; la partita parte quando il collegamento riesce (_on_joined).
func join_game(index: int, weapon: int, stile: String, player_name: String, ip: String) -> void:
	rete.my_info = _net_info(index, weapon, stile, player_name)
	_pending = [index, weapon, stile]
	if rete.join(ip) != OK:
		_on_join_failed("Indirizzo non valido: %s" % ip)


func _on_joined() -> void:
	if _pending.is_empty():
		return
	start_game(_pending[0], _pending[1], _pending[2])
	_pending = []
	hud.show_message("Sei entrato nella partita!", 3.0)


func _on_join_failed(text: String) -> void:
	_pending = []
	if _stage:
		_stage.set_net_status(text)


func _on_host_closed() -> void:
	if hud:
		hud.show_message("Chi ospitava ha chiuso la partita.
Torno al menu...", 3.0)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()


func start_game(index: int, weapon := 0, stile := "") -> void:
	if _stage:
		_stage.queue_free()
		_stage = null
	var data: Dictionary = Characters.LIST[index].duplicate()
	if stile != "":
		data["stile"] = stile              # persone vere: "blender" o "minecraft" (scelto nel menu)
	_spawn_vehicles()
	if not rete.online:
		# offline: il nome del menu serve alla classifica e allo storico
		var nm := Menu.last_name if Menu.last_name != "" else String(data["name"])
		rete.my_info = _net_info(index, weapon, stile, nm)
	_match_t0 = Time.get_ticks_msec() / 1000.0

	player = Player.new()
	player.char_data = data
	player.start_weapon = clampi(weapon, 0, Player.Weapons.LIST.size() - 1)
	player.position = Room.PLAYER_SPAWN * Config.S
	if rete.online:
		# ogni giocatore compare un po' più in là, così non nascono uno dentro l'altro
		var slot := 0 if rete.is_host else 1 + multiplayer.get_unique_id() % 4
		var side := [0.0, 1.0, -1.0, 2.0, -2.0][slot] as float
		player.position += Vector3(side * Config.SPAWN_SPREAD, 0, 0)
	add_child(player)

	hud = Hud.new()
	add_child(hud)
	hud.set_health(player.hp)
	hud.set_ammo(player.mag, player.reserve, false)
	hud.set_weapon(player.weapon_label())
	hud.show_message("%s è pronto!" % data["name"], 2.5)

	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(hud.set_ammo)
	player.weapon_changed.connect(hud.set_weapon)
	player.hit_target.connect(hud.hit)
	player.died.connect(_on_player_died)
	player.front_view_changed.connect(hud.set_front_view)
	player.fired.connect(rete.on_player_fired)
	player.vehicle_hint.connect(hud.set_hint)
	player.driving_changed.connect(hud.set_driving)
	rete.player = player
	munizioni.player = player

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_pose()
	player_index = index
	if nemici and (not rete.online or (rete.coop and rete.is_host)):
		_start_waves(index)
	# chi si unisce in CO-OP crea le ondate quando chi ospita gli dice il modo (rete.coop_known)


## Partita offline: calcola dove possono camminare i nemici e fa partire le ondate (game/ondate.gd).
func _start_waves(index: int) -> void:
	var leader := not rete.online or rete.is_host       # chi comanda i nemici (offline o chi ospita)
	if leader:
		WorldSetup.bake_navigation(_nav)
	ondate = Ondate.new()
	ondate.name = "Ondate"
	ondate.net = rete.online
	ondate.is_host = leader
	ondate.rete = rete
	ondate.player = player
	ondate.player_char = index
	ondate.punteggi = punteggi
	ondate.spawn_parent = self
	add_child(ondate)
	ondate.wave_started.connect(func(w: int, boss: bool) -> void:
		hud.set_wave(w)
		_wave_pts0 = int(punteggi.my_row().get("points", 0))
		hud.show_message("ONDATA %d%s" % [w, "\nARRIVA UN CAPO!" if boss else ""], 2.5))
	ondate.wave_cleared.connect(func(w: int) -> void:
		_best_wave_pts = maxi(_best_wave_pts, int(punteggi.my_row().get("points", 0)) - _wave_pts0)
		if not player.alive:
			player.respawn()                          # co-op: chi era a terra rientra
		else:
			player.heal(Config.WAVE_CLEAR_HEAL)
		player.add_clips(Config.WAVE_CLEAR_CLIPS)
		hud.show_message("ONDATA %d SUPERATA!\n+vita  +graffette  +FORZIERE con un'arma nuova" % w, 3.5)
		_spawn_chest())
	ondate.all_down.connect(_on_all_down)
	ondate.enemies_changed.connect(hud.set_enemies_left)
	hud.set_wave(0)
	_update_score()
	if leader:
		ondate.start()
	else:
		hud.show_message("CO-OP: tutti insieme contro le ondate!", 3.0)


## Punti in alto a destra: della squadra e, se si gioca in tanti, anche i miei (game/punteggi.gd).
func _update_score() -> void:
	if hud == null or ondate == null:
		return
	var mine := -1
	if rete.online:
		mine = int(punteggi.my_row().get("points", 0))
	hud.set_score(punteggi.total_points(), mine)


## Fine ondata: forziere davanti al giocatore con un'arma che non ha (game/forziere.gd).
func _spawn_chest() -> void:
	if not is_instance_valid(player):
		return
	if forziere and is_instance_valid(forziere):
		forziere.close_and_free()
	forziere = Forziere.new()
	forziere.name = "Forziere"
	forziere.player = player
	forziere.weapon = Forziere.pick_weapon(player.owned)
	add_child(forziere)
	var pos := Forziere.pick_spot(player)
	forziere.global_position = pos
	var to: Vector3 = player.global_position - pos
	forziere.rotation.y = atan2(-to.x, -to.z)         # la serratura guarda verso il giocatore
	forziere.taken.connect(func(_w: int, dropped: String) -> void:
		hud.show_message("HAI PRESO: %s%s\n1 / 2, rotellina o Q per cambiare arma" % [
				Player.Weapons.LIST[_w]["name"], ("\n(lasci %s)" % dropped) if dropped != "" else ""], 3.0))


## Classifica a fine partita (e salvataggio nello storico, game/storico.gd).
func _show_end(title: String, wave: int) -> void:
	game_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_message("")
	var rows := punteggi.rows()
	hud.show_scoreboard(title, rows, punteggi.my_id(),
			"Arrivati all'ondata %d  ·  punti di squadra %d\n\nPremi INVIO per tornare al menu" % [wave, punteggi.total_points()])
	_save_history(wave, rows)


func _save_history(wave: int, rows: Array) -> void:
	# i test automatici (main aggiunto da uno script, non come scena) non sporcano lo storico
	if _saved or get_tree().current_scene != self or "--nosalva" in OS.get_cmdline_user_args():
		return
	_saved = true
	var righe := []
	for r in rows:
		righe.append({"name": r["name"], "char": r["char"], "points": r["points"], "damage": r["damage"],
				"kills": r["kills"], "assists": r["assists"], "heads": r["heads"], "deaths": r["deaths"]})
	Storico.add({
		"data": Time.get_datetime_string_from_system(false, true),
		"modo": "offline" if not rete.online else ("coop" if rete.coop else "tutti contro tutti"),
		"ondata": wave,
		"io": String(rete.my_info.get("name", "?")),
		"personaggio": String(Characters.LIST[player_index]["name"]),
		"durata": int(Time.get_ticks_msec() / 1000.0 - _match_t0),
		"ondata_top": _best_wave_pts,
		"righe": righe,
	})


## Macchinina e aeroplanino nei loro posti (world/room.gd: CAR_SPOT, PLANE_SPOT). Ognuno ha i suoi:
## in multiplayer ogni giocatore guida i propri (gli altri vedono solo l'omino seduto).
func _spawn_vehicles() -> void:
	if macchinina:
		return
	macchinina = Macchinina.new()
	macchinina.name = "Macchinina"
	macchinina.position = Room.CAR_SPOT * Config.S
	macchinina.rotation.y = deg_to_rad(Room.CAR_YAW)
	add_child(macchinina)
	aeroplanino = Aeroplanino.new()
	aeroplanino.name = "Aeroplanino"
	aeroplanino.position = Room.PLANE_SPOT * Config.S
	aeroplanino.rotation.y = deg_to_rad(Room.PLANE_YAW)
	add_child(aeroplanino)


func _process(delta: float) -> void:
	if _shot_path != "":
		_shot_frames += 1
		if _shot_frames == _shot_at:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()
	if player:
		hud.update_crosshair(player.current_spread)
		if not game_over:
			# Tab tenuto: classifica della partita in corso
			if Input.is_action_pressed("scoreboard"):
				hud.show_scoreboard("CLASSIFICA", punteggi.rows(), punteggi.my_id(), "punti = danni fatti x %d" % int(Config.POINTS_PER_DAMAGE))
			else:
				hud.hide_scoreboard()
	if _bench > 0.0 and player:
		_bench_t += delta
		_bench_frames += 1
		if _bench_t >= 2.0 and _bench_frames > 0:     # i primi secondi servono a scaldare
			var P := Performance
			print("FPS %.0f  frame %.1f ms  oggetti %d  disegni %d  triangoli %d  nodi %d" % [
				P.get_monitor(P.TIME_FPS), P.get_monitor(P.TIME_PROCESS) * 1000.0,
				P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.OBJECT_NODE_COUNT)])
			_bench -= _bench_t
			_bench_t = 0.0
			if _bench <= 0.0:
				get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			rete.leave()
			get_tree().reload_current_scene()


# ---------------------------------------------------------------- eventi di gioco

func _on_health_changed(hp: float) -> void:
	hud.set_health(hp)
	hud.damage_flash()


func _on_player_died() -> void:
	punteggi.death(punteggi.my_id())
	if rete.online and rete.coop:
		hud.show_message("SEI A TERRA!\n\nRientri alla fine dell'ondata,\nse i tuoi amici resistono", 4.0)
		return
	if rete.online:
		# in multiplayer non si perde: si resta a terra qualche secondo e si rientra
		hud.show_message("SEI STATO STESO!

Rientri tra %d secondi" % int(Config.RESPAWN_TIME), Config.RESPAWN_TIME)
		await get_tree().create_timer(Config.RESPAWN_TIME).timeout
		if is_instance_valid(player):
			player.respawn()
		return
	game_over = true
	if ondate:
		ondate.stop()
		punteggi.flush()
		_show_end("SEI FUORI GIOCO!", ondate.wave)
	else:
		hud.show_message("SEI FUORI GIOCO!\n\nPremi INVIO per tornare al menu")


## CO-OP: tutti i giocatori a terra, la partita è finita (lo decide chi ospita, game/ondate.gd).
func _on_all_down(wave: int, _score: int) -> void:
	if ondate:
		ondate.stop()
	_show_end("SIETE TUTTI A TERRA!", wave)


# ---------------------------------------------------------------- test automatici

func _parse_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--fps"):
			_bench = 10.0 if a == "--fps" else float(a.substr(6))
		elif a == "--pvp":
			_auto_coop = false
		elif a == "--nonemici":
			nemici = false
		elif a == "--autostart":
			_auto = true
		elif a.begins_with("--char="):
			_auto_char = clampi(int(a.substr(7)), 0, Characters.LIST.size() - 1)
		elif a.begins_with("--shotframe="):
			_shot_at = int(a.substr(12))
		elif a == "--host":
			_auto_net = "host"
		elif a.begins_with("--join="):
			_auto_net = a.substr(7)
		elif a.begins_with("--name="):
			_auto_name = a.substr(7)
		elif a == "--minecraft":
			_auto_style = "minecraft"
		elif a.begins_with("--weapon="):
			_auto_weapon = int(a.substr(9))
		elif a in ["--overview", "--desk", "--door", "--ramp", "--wall", "--back", "--garage"]:
			_pose = a
		elif a in ["--front", "--prone", "--guida", "--vola", "--forziere", "--classifica"]:   # visuale frontale / sdraiato / veicoli / forziere / classifica
			_extra.append(a)


## Posizioni di prova (metri reali). Se cambi la stanza, controlla che siano ancora in punti liberi.
func _apply_pose() -> void:
	if "--front" in _extra:
		player.set_front_view(true)
	if "--prone" in _extra:
		player._prone = true
	if "--guida" in _extra:
		player.enter_vehicle(macchinina)
	if "--forziere" in _extra:
		_spawn_chest.call_deferred()
	if "--classifica" in _extra:
		# classifica finta di fine partita (per lo screenshot)
		game_over = true
		hud.show_scoreboard("SIETE TUTTI A TERRA!", [
			{"peer": 1, "name": "Mauro", "char": 0, "points": 1230, "damage": 123.0, "kills": 11, "assists": 3, "heads": 4, "deaths": 1},
			{"peer": 2, "name": "Matteo", "char": 3, "points": 980, "damage": 98.0, "kills": 7, "assists": 6, "heads": 2, "deaths": 1}],
			1, "Arrivati all'ondata 7  ·  punti di squadra 2210\n\nPremi INVIO per tornare al menu")
	if "--vola" in _extra:
		# in volo a un metro da terra sopra la rampa, verso ovest lungo il lato della porta
		aeroplanino.global_position = Vector3(0.25, 0.95, 1.4) * Config.S
		aeroplanino.reset_physics_interpolation()
		aeroplanino.launch(Config.PLANE_CRUISE)
		player.enter_vehicle(aeroplanino)
	var west := -Room.W / 2 + 0.022      # a filo della parete ovest
	match _pose:
		"--overview":
			var cam := Camera3D.new()
			cam.fov = 80.0
			add_child(cam)
			cam.global_position = Vector3(1.35, 2.5, 2.1) * Config.S
			cam.look_at(Vector3(-0.2, 0.5, -1.0) * Config.S)
			cam.current = true
		"--desk":       # sopra l'isola di scrivanie
			player.place(Vector3(-0.4, Room.T + 0.02, 0.0) * Config.S, PI * 0.1)
		"--door":       # davanti alla porta
			player.place(Vector3(0.3, 0.02, 1.9) * Config.S, PI * 0.05)
		"--ramp":       # a metà della rampa, guardando in salita
			player.place(Vector3(Room.RAMP_X, Room.T / 2 + 0.02, Room.IZ1 + Room.RAMP_RUN / 2) * Config.S, 0.0)
		"--wall":       # parete ovest di fianco, sul lato della spalla destra
			player.place(Vector3(west, 0.02, 1.0) * Config.S, PI)
		"--back":       # spalle alla parete ovest
			player.place(Vector3(west, 0.02, 1.0) * Config.S, -PI / 2)
		"--garage":     # di fronte alla macchinina parcheggiata, per vederla da fuori
			player.place((Room.CAR_SPOT + Vector3(0.42, 0.02, 0.42)) * Config.S, PI / 4)
