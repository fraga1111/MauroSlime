extends Node3D
## REGIA DEL GIOCO: costruisce la stanza, mostra il menu, avvia la partita e collega i pezzi.
## Qui non ci sono numeri da bilanciare (stanno in config.gd) né oggetti della stanza (world/room.gd).
## Mappa completa del progetto: CLAUDE.md nella cartella principale.
##
## Per ora è una bozza senza nemici (il vecchio codice degli slime è in archivio_nemici/):
## si entra nella stanza con un omino, in terza persona, e ci si muove e si spara liberamente.

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

var player: Player
var macchinina: Macchinina        # Opel Agila bianca a terra (E per guidarla)
var aeroplanino: Aeroplanino      # aeroplanino di carta (E per pilotarlo)
var hud: Hud
var game_over := false
var _stage: MenuStage
var rete: Rete                    # multiplayer (game/rete.gd)
var munizioni: Munizioni          # scatole di graffette a terra
var _pending := []               # client: partita da avviare quando il collegamento riesce

# opzioni da riga di comando, solo per test automatici (vedi CLAUDE.md):
#   --autostart  --char=N  --weapon=N  --minecraft  --host  --join=IP  --name=NOME  --shot=file.png  --overview | --desk | --door | --ramp | --wall | --back
#   --guida (seduto in macchinina)  --vola (sull'aeroplanino, già in volo)
var _shot_path := ""
var _shot_frames := 0
var _shot_at := 90               # --shotframe=N: fotogramma dello screenshot
var _auto := false
var _auto_char := 0
var _auto_weapon := 0
var _auto_style := ""
var _auto_net := ""              # "host" oppure l'IP a cui unirsi
var _auto_name := ""
var _pose := ""
var _extra: Array[String] = []


func _ready() -> void:
	InputSetup.setup()
	WorldSetup.add_environment(self)
	var room := Node3D.new()                 # stanza e mobili (tutto ciò che ha una collisione)
	room.name = "Stanza"
	add_child(room)
	Room.new().build(room, self)

	rete = Rete.new()
	rete.name = "Rete"
	add_child(rete)
	rete.joined.connect(_on_joined)
	rete.join_failed.connect(_on_join_failed)
	rete.host_closed.connect(_on_host_closed)
	rete.message.connect(func(t: String) -> void:
		if hud:
			hud.show_message(t, 3.0))
	munizioni = Munizioni.new()
	munizioni.name = "Munizioni"
	add_child(munizioni)
	munizioni.picked.connect(func(t: String) -> void:
		if hud:
			hud.show_message(t, 1.5))

	_parse_debug_args()
	var nm := _auto_name if _auto_name != "" else "Giocatore"
	if _auto_net == "host":
		host_game(_auto_char, _auto_weapon, _auto_style, nm)
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
func host_game(index: int, weapon: int, stile: String, player_name: String) -> void:
	rete.my_info = _net_info(index, weapon, stile, player_name)
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
	hud.set_weapon(String(player.Weapons.LIST[player.weapon]["name"]))
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


func _process(_delta: float) -> void:
	if _shot_path != "":
		_shot_frames += 1
		if _shot_frames == _shot_at:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()
	if player:
		hud.update_crosshair(player.current_spread)


func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_tree().reload_current_scene()


# ---------------------------------------------------------------- eventi di gioco

func _on_health_changed(hp: float) -> void:
	hud.set_health(hp)
	hud.damage_flash()


func _on_player_died() -> void:
	if rete.online:
		# in multiplayer non si perde: si resta a terra qualche secondo e si rientra
		hud.show_message("SEI STATO STESO!

Rientri tra %d secondi" % int(Config.RESPAWN_TIME), Config.RESPAWN_TIME)
		await get_tree().create_timer(Config.RESPAWN_TIME).timeout
		if is_instance_valid(player):
			player.respawn()
		return
	game_over = true
	hud.show_message("SEI FUORI GIOCO!\n\nPremi INVIO per tornare al menu")


# ---------------------------------------------------------------- test automatici

func _parse_debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
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
		elif a in ["--front", "--prone", "--guida", "--vola"]:   # visuale frontale / sdraiato / veicoli
			_extra.append(a)


## Posizioni di prova (metri reali). Se cambi la stanza, controlla che siano ancora in punti liberi.
func _apply_pose() -> void:
	if "--front" in _extra:
		player.set_front_view(true)
	if "--prone" in _extra:
		player._prone = true
	if "--guida" in _extra:
		player.enter_vehicle(macchinina)
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
