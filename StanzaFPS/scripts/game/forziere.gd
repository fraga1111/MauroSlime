extends Node3D
## FORZIERE DI FINE ONDATA: compare davanti al giocatore quando un'ondata è superata, si apre da solo
## e fa salire un'arma che gira, diversa da quelle che hai già. Passaci sopra per prenderla:
## se hai una sola arma diventa la seconda (1 / 2, rotellina o Q per cambiare), se ne hai già due
## sostituisce quella che hai in mano (player.gd give_weapon). Le graffette a terra ricaricano tutte e due.
## In co-op ognuno ha il suo forziere (solo sul proprio computer). Lo crea main.gd (wave_cleared).
## Numeri in config.gd, sezione "forziere". Misure del modello in metri di gioco.

signal taken(weapon: int, dropped: String)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const GunModels := preload("res://scripts/actors/gun_models.gd")

var player                       # actors/player.gd (impostato da main.gd)
var weapon := 0                  # indice in Weapons.LIST dell'arma dentro

var _lid: Node3D
var _gun: Node3D
var _light: OmniLight3D
var _label: Label3D
var _t := 0.0
var _open := false
var _done := false


## Un'arma a caso tra quelle che il giocatore non ha.
static func pick_weapon(owned: Array) -> int:
	var free := []
	for i in Weapons.LIST.size():
		if not owned.has(i):
			free.append(i)
	if free.is_empty():
		return randi() % Weapons.LIST.size()
	return int(free[randi() % free.size()])


## Dove metterlo: un po' davanti al giocatore se lì c'è pavimento libero e lo vede, altrimenti
## il punto delle graffette (room.gd PICKUP_SPOTS) più vicino a lui.
static func pick_spot(p: Node3D) -> Vector3:
	var space := p.get_world_3d().direct_space_state
	var fwd := -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var eye: Vector3 = p.global_position + Vector3(0, 1.2, 0)
	for d in [3.5, 2.5, 5.0]:
		var c: Vector3 = p.global_position + fwd * d
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 2.0, 0), c + Vector3(0, -2.5, 0), Config.LAYER_WORLD))
		if down.is_empty() or Vector3(down["normal"]).y < 0.9:
			continue
		var floor_p: Vector3 = down["position"]
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, floor_p + Vector3(0, 0.6, 0), Config.LAYER_WORLD)).is_empty():
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.7, 1.2, 1.2)
		q.shape = box
		q.collision_mask = Config.LAYER_WORLD
		q.transform = Transform3D(Basis(), floor_p + Vector3(0, 0.7, 0))
		if space.intersect_shape(q, 1).is_empty():
			return floor_p
	var best: Vector3 = Room.PLAYER_SPAWN * Config.S
	for s in Room.PICKUP_SPOTS:
		var c: Vector3 = s * Config.S
		if c.distance_to(p.global_position) < best.distance_to(p.global_position):
			best = c
	return best + Vector3(0, 0.02, 0)


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()
	scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(Config.CHEST_OPEN_DELAY)
	tw.tween_callback(_open_lid)


func _process(delta: float) -> void:
	_t += delta
	if _gun:
		_gun.rotation.y = _t * 2.2
	if not _open or _done or player == null or not is_instance_valid(player) or not player.alive:
		return
	if player.in_vehicle():
		return
	var d: Vector3 = player.global_position - global_position
	if Vector2(d.x, d.z).length() < Config.CHEST_PICK_RADIUS and absf(d.y) < 2.5:
		_done = true
		var dropped: String = player.give_weapon(weapon)
		taken.emit(weapon, dropped)
		close_and_free()


## Via il forziere (preso, oppure arriva quello dell'ondata dopo).
func close_and_free() -> void:
	_done = true
	if _label:
		_label.visible = false
	var tw := create_tween()
	if _gun:
		tw.tween_property(_gun, "scale", Vector3.ZERO, 0.25)
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _open_lid() -> void:
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", deg_to_rad(105.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "light_energy", 2.5, 0.5)
	tw.parallel().tween_property(_gun, "position:y", 1.75, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_gun, "scale", Vector3.ONE * 1.7, 0.9)
	tw.tween_callback(func() -> void:
		_open = true
		_label.visible = true)


## Cassa di legno con fasce scure, bordi e serratura dorati; dentro una luce calda.
func _build() -> void:
	var wood := _mat(Color(0.45, 0.26, 0.12), 0.75)
	var dark := _mat(Color(0.25, 0.14, 0.07), 0.8)
	var gold := _mat(Color(1.0, 0.78, 0.25), 0.3, 0.8)
	gold.emission_enabled = true
	gold.emission = Color(0.6, 0.42, 0.08)
	gold.emission_energy_multiplier = 0.4
	var inside := _mat(Color(1.0, 0.85, 0.4), 0.9)
	inside.emission_enabled = true
	inside.emission = Color(1.0, 0.7, 0.2)
	inside.emission_energy_multiplier = 1.2
	var w := 1.5
	var h := 0.75
	var dp := 0.95
	_box(self, Vector3(w, h, dp), Vector3(0, h / 2, 0), wood)
	_box(self, Vector3(w - 0.12, 0.02, dp - 0.12), Vector3(0, h + 0.005, 0), inside)        # interno luminoso
	for x in [-w / 2 + 0.12, w / 2 - 0.12]:                                                  # fasce scure
		_box(self, Vector3(0.12, h + 0.02, dp + 0.02), Vector3(x, h / 2, 0), dark)
	_box(self, Vector3(w + 0.03, 0.06, dp + 0.03), Vector3(0, 0.03, 0), gold)               # bordo in basso
	_box(self, Vector3(w + 0.03, 0.05, dp + 0.03), Vector3(0, h - 0.025, 0), gold)          # bordo in alto
	# coperchio: ruota intorno al bordo dietro (z = +dp/2)
	_lid = Node3D.new()
	_lid.position = Vector3(0, h, dp / 2)
	add_child(_lid)
	_box(_lid, Vector3(w, 0.22, dp), Vector3(0, 0.11, -dp / 2), wood)
	_box(_lid, Vector3(w + 0.03, 0.05, dp + 0.03), Vector3(0, 0.025, -dp / 2), gold)
	for x in [-w / 2 + 0.12, w / 2 - 0.12]:
		_box(_lid, Vector3(0.12, 0.24, dp + 0.02), Vector3(x, 0.12, -dp / 2), dark)
	_box(_lid, Vector3(0.18, 0.22, 0.05), Vector3(0, 0.0, -dp - 0.02), gold)                # serratura
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.35)
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position = Vector3(0, h + 0.6, 0)
	add_child(_light)
	_gun = GunModels.build(String(Weapons.LIST[weapon]["model"]))
	_gun.position = Vector3(0, h * 0.6, 0)
	_gun.scale = Vector3.ONE * 0.6
	add_child(_gun)
	_label = Label3D.new()
	_label.text = "%s\npassaci sopra per prenderla" % Weapons.LIST[weapon]["name"]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = Color(1.0, 0.85, 0.35)
	_label.position.y = 2.6
	_label.visible = false
	add_child(_label)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
