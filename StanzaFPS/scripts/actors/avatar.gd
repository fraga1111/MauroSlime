extends StaticBody3D
## OMINO DI UN ALTRO GIOCATORE in multiplayer (game/rete.gd): stesso modello di character_model.gd,
## mosso dai messaggi che arrivano dalla rete (apply_state) e ammorbidito tra un messaggio e l'altro.
## Ha una capsula sul livello dei nemici, così i colpi lo prendono: take_hit avvisa la rete, che manda
## il danno al suo proprietario (in testa vale Config.HEADSHOT_MULT volte). Sopra la testa c'è il nome.

signal hit(peer_id: int, amount: float)

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const Effetti := preload("res://scripts/actors/effetti.gd")

var peer_id := 0

var _model: CharacterModel
var _col: CollisionShape3D
var _capsule: CapsuleShape3D
var _label: Label3D
var _has_state := false
var _pos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _hspeed := 0.0
var _crouch := false
var _on_floor := true
var _reloading := false
var _prone_k := 0.0
var _slide_k := 0.0
var _weapon := -1
var _alive := true
var _dead_k := 0.0
var _flash: OmniLight3D
var _flash_t := 0.0
var _scale := 1.0


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	collision_layer = Config.LAYER_ENEMY
	collision_mask = 0
	visible = false                         # finché non arriva la prima posizione
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var ci := clampi(int(info.get("char", 0)), 0, Characters.LIST.size() - 1)
	var d: Dictionary = Characters.LIST[ci].duplicate()
	if String(info.get("stile", "")) != "":
		d["stile"] = info["stile"]
	_weapon = clampi(int(info.get("weapon", 0)), 0, Weapons.LIST.size() - 1)
	d["gun"] = Weapons.LIST[_weapon]["model"]
	_scale = float(d.get("scale", 1.0))
	_model = CharacterModel.new()
	_model.setup(d)
	add_child(_model)

	_capsule = CapsuleShape3D.new()
	_capsule.radius = Config.PLAYER_RADIUS
	_capsule.height = Config.PLAYER_HEIGHT
	_col = CollisionShape3D.new()
	_col.shape = _capsule
	_col.position.y = Config.PLAYER_HEIGHT / 2.0
	add_child(_col)

	_label = Label3D.new()
	_label.text = String(info.get("name", "?"))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = Characters.LIST[ci]["accent"]
	_label.position.y = Config.PLAYER_HEIGHT * float(d.get("scale", 1.0)) + 0.45
	add_child(_label)

	_flash = OmniLight3D.new()
	_flash.omni_range = 8.0
	_flash.light_energy = 0.0
	_flash.light_color = Weapons.LIST[_weapon].get("flash", Color(1.0, 0.7, 0.25))
	_model.muzzle.add_child(_flash)


## s = player.gd net_state(): [posizione, yaw, pitch, velocità, accovacciato, a terra, ricarica,
##     sdraiato 0..1, scivolata 0..1, arma, vivo]
func apply_state(s: Array) -> void:
	if s.size() < 11:
		return
	_pos = s[0]
	_yaw = s[1]
	_pitch = s[2]
	_hspeed = s[3]
	_crouch = s[4]
	_on_floor = s[5]
	_reloading = s[6]
	_prone_k = s[7]
	_slide_k = s[8]
	var w := int(s[9])
	_alive = s[10]
	if w != _weapon and w >= 0 and w < Weapons.LIST.size():
		_weapon = w
		_model.set_gun(String(Weapons.LIST[w]["model"]))
		_flash = OmniLight3D.new()
		_flash.omni_range = 8.0
		_flash.light_energy = 0.0
		_flash.light_color = Weapons.LIST[w].get("flash", Color(1.0, 0.7, 0.25))
		_model.muzzle.add_child(_flash)
	if not _has_state:
		_has_state = true
		global_position = _pos
		rotation.y = _yaw
		visible = true


func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	var k := clampf(delta * 15.0, 0.0, 1.0)
	if global_position.distance_to(_pos) > 8.0:
		global_position = _pos              # salto grande (rientro dopo essere stato steso)
	else:
		global_position = global_position.lerp(_pos, k)
	rotation.y = lerp_angle(rotation.y, _yaw, k)
	_dead_k = move_toward(_dead_k, 0.0 if _alive else 1.0, delta * 3.0)
	_model.animate(delta, _hspeed, _crouch, _pitch, _on_floor, _reloading, _prone_k)
	_model.rotation.x = -PI / 2 * _prone_k + 0.4 * _slide_k + PI / 2 * _dead_k
	_model.position = Vector3(0.0, 0.13 * _prone_k + 0.3 * _dead_k, Config.PLAYER_PRONE_LENGTH / 2.0 * _prone_k)
	# capsula: più bassa se accovacciato, a terra o steso (i colpi passano sopra)
	var h := Config.PLAYER_HEIGHT
	if _crouch:
		h = Config.PLAYER_CROUCH_HEIGHT
	if _prone_k > 0.5 or not _alive:
		h = Config.PLAYER_RADIUS * 2.0 + 0.1
	_capsule.height = h
	_col.position.y = h / 2.0
	_col.disabled = not _alive
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.light_energy = 0.0


## L'altro giocatore ha sparato: rinculo, lampo, colpo luminoso (se l'arma lo ha) e segno sul muro.
func show_shot(to: Vector3, normal: Vector3, world: bool) -> void:
	_model.recoil()
	_flash.light_energy = 3.0
	_flash_t = 0.05
	var w: Dictionary = Weapons.LIST[_weapon]
	if w.has("tracer"):
		Effetti.tracer(get_parent(), _model.muzzle.global_position, to, w["tracer"])
	if world:
		Effetti.impact(get_parent(), to, normal, w.get("splat"))


## Colpito dal giocatore locale (player.gd _shoot): il danno lo applica il proprietario di questo omino.
## Ritorna true per un colpo in testa (il mirino mostra la X rossa).
func take_hit(damage: float, pos_hit: Vector3, _dir: Vector3) -> bool:
	if not _alive:
		return false
	# la testa parte dal collo: 1,48 m in piedi, 0,4 più in basso accovacciato; sdraiati non conta
	var neck := (1.48 - (0.4 if _crouch else 0.0)) * _scale
	var head := _prone_k < 0.5 and pos_hit.y - global_position.y > neck
	hit.emit(peer_id, damage * (Config.HEADSHOT_MULT if head else 1.0))
	return head


# ---------------------------------------------------------------- per i nemici in co-op (game/ondate.gd)

func is_alive() -> bool:
	return _alive and _has_state


## Altezza del petto da terra (dove mirano i nemici).
func chest_height() -> float:
	var h := Config.PLAYER_HEIGHT
	if _crouch:
		h = Config.PLAYER_CROUCH_HEIGHT
	if _prone_k > 0.5:
		h = Config.PLAYER_RADIUS * 2.0
	return h * 0.65 * _scale
