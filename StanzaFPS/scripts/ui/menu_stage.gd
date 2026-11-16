extends Node3D
## SCHERMATA INIZIALE: i personaggi "in vetrina" sul pavimento della stanza, una telecamera
## che li guarda e il menu a schede (ui/menu.gd). Quando si preme GIOCA emette start_game.

signal start_game(index: int, weapon: int, stile: String)
signal host_game(index: int, weapon: int, stile: String, player_name: String)
signal join_game(index: int, weapon: int, stile: String, player_name: String, ip: String)

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

# posizioni in metri reali (stessi assi di world/room.gd)
const MODELS_CENTER := Vector3(-0.55, 0.0, 1.05)   # omini in fila, centrati qui
const MODEL_SPACING := 0.15                        # si stringe da sola se gli omini sono tanti
const ROW_MAX_WIDTH := 0.44
const CAM_POS := Vector3(-0.55, 0.075, 1.4)
const CAM_LOOK := Vector3(-0.55, 0.03, 1.05)

# il menu ricorda l'ultima scelta quando si torna indietro
static var last_index := 0
static var last_weapon := 0
static var last_stili := {}

var _models: Array = []
var _spot: OmniLight3D
var _cam: Camera3D
var _menu: Menu
var _t := 0.0


func _ready() -> void:
	# omini e telecamera del menu si muovono a ogni fotogramma (_process), non nei passi della fisica
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var n := Characters.LIST.size()
	var gap := minf(MODEL_SPACING, ROW_MAX_WIDTH / maxf(n - 1, 1))
	for i in n:
		var m := _make_model(i, String(last_stili.get(i, "")))
		m.position = (MODELS_CENTER + Vector3((i - (n - 1) / 2.0) * gap, 0, 0)) * Config.S
		m.rotation.y = PI      # rivolti verso la telecamera
		_models.append(m)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.55, 0.2, 1.3) * Config.S
	fill.omni_range = 14.0
	fill.light_energy = 1.2
	add_child(fill)
	_spot = OmniLight3D.new()
	_spot.omni_range = 5.0
	_spot.light_energy = 4.0
	add_child(_spot)

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true

	_menu = Menu.new()
	_menu.index = last_index
	_menu.weapon = last_weapon
	_menu.stili = last_stili.duplicate()
	add_child(_menu)
	_menu.selected.connect(_on_selected)
	_menu.weapon_selected.connect(_on_weapon_selected)
	_menu.style_changed.connect(_on_style_changed)
	_menu.start_game.connect(_on_start)
	_menu.host_game.connect(func(i: int, w: int, st: String, n: String) -> void:
		_remember(i, w)
		host_game.emit(i, w, st, n))
	_menu.join_game.connect(func(i: int, w: int, st: String, n: String, ip: String) -> void:
		_remember(i, w)
		join_game.emit(i, w, st, n, ip))
	_on_selected(last_index)
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	for i in _models.size():
		var m: CharacterModel = _models[i]
		if i == _menu.index:
			m.rotation.y += delta * 1.4
			m.animate(delta, 3.0 + sin(_t) * 2.0, false, sin(_t * 0.7) * 0.3, true, false)
		else:
			m.rotation.y = lerp_angle(m.rotation.y, PI, clampf(delta * 5.0, 0.0, 1.0))
			m.animate(delta, 0.0, false, 0.0, true, false)
	_cam.global_position = (CAM_POS + Vector3(sin(_t * 0.3) * 0.02, 0, 0)) * Config.S
	_cam.look_at(CAM_LOOK * Config.S)


func _on_selected(i: int) -> void:
	var m: CharacterModel = _models[i]
	_spot.light_color = Characters.LIST[i]["accent"]
	_spot.global_position = m.global_position + Vector3(0, 2.6, 0.8)


func _make_model(i: int, stile: String) -> CharacterModel:
	var m := CharacterModel.new()
	var d: Dictionary = Characters.LIST[i].duplicate()
	d["gun"] = Weapons.LIST[_menu.weapon if _menu else last_weapon]["model"]   # tutti con l'arma scelta
	if stile != "":
		d["stile"] = stile
	m.setup(d)
	add_child(m)
	return m


## Cambio di aspetto (BLENDER / MINECRAFT): il modello di quel personaggio si rifà al suo posto.
func _on_style_changed(i: int, stile: String) -> void:
	var old: CharacterModel = _models[i]
	var m := _make_model(i, stile)
	m.transform = old.transform
	_models[i] = m
	old.queue_free()


func _on_weapon_selected(w: int) -> void:
	for m in _models:
		(m as CharacterModel).set_gun(String(Weapons.LIST[w]["model"]))


func _on_start(index: int, w: int, stile: String) -> void:
	_remember(index, w)
	start_game.emit(index, w, stile)


func _remember(index: int, w: int) -> void:
	last_index = index
	last_weapon = w
	last_stili = _menu.stili.duplicate()


## Messaggio nel pannello multiplayer del menu (es. "non riesco a collegarmi").
func set_net_status(text: String) -> void:
	_menu.set_net_status(text)
