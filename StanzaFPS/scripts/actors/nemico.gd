extends CharacterBody3D
## NEMICO delle ondate (offline e co-op online): uno degli omini del menu (data/characters.gd) che va
## verso il giocatore più vicino seguendo la mesh di navigazione (world/world_setup.gd) e, quando lo vede,
## si ferma e gli spara a raffiche.
## Vita, velocità, danno e mira li imposta game/ondate.gd prima di aggiungerlo alla scena
## (crescono a ogni ondata; i numeri base sono in config.gd, sezione "partita OFFLINE").
## Il giocatore lo colpisce con take_hit (come gli omini in multiplayer): in testa vale HEADSHOT_MULT.
##
## CO-OP ONLINE: il nemico "vero" (che pensa, cammina e spara) esiste solo su chi ospita. Sugli altri
## computer c'è una COPIA (puppet = true) che si limita a seguire posizione e spari mandati dalla rete;
## se la colpisci, il danno viene mandato a chi ospita (game/ondate.gd).

signal died(points: int)

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const Effetti := preload("res://scripts/actors/effetti.gd")

var ondate                       # game/ondate.gd: bersagli (targets), danni, messaggi di rete
var net_id := 0                  # numero del nemico, uguale su tutti i computer
var puppet := false              # true = copia mossa dalla rete (co-op, su chi non ospita)
var char_index := 0
var weapon := 0
var boss := false
var hp := 6.0
var max_hp := 0.0                # 0 = uguale alla vita iniziale
var speed := 4.0
var damage := 3.0
var fire_delay := 0.5
var burst := 3
var burst_pause := 1.5
var spread := 0.08
var reaction := 0.8

var _model: CharacterModel
var _label: Label3D
var _scale := 1.0
var _target: Node3D = null
var _target_t := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _look_t := 0.0
var _sees := false
var _seen_for := 0.0
var _shot_cd := 0.0
var _burst_left := 0
var _strafe := 1.0
var _strafe_t := 0.0
var _pitch := 0.0
var _dead := false
# copia di rete: ultimo stato ricevuto
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_speed := 0.0


func _ready() -> void:
	collision_layer = Config.LAYER_ENEMY
	collision_mask = 0 if puppet else Config.LAYER_WORLD | Config.LAYER_PLAYER | Config.LAYER_ENEMY | Config.LAYER_VEHICLE
	floor_max_angle = deg_to_rad(Config.MAX_SLOPE_DEG)
	floor_snap_length = 0.4
	if max_hp <= 0.0:
		max_hp = hp
	if puppet:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_net_pos = position
		_net_yaw = rotation.y

	var d: Dictionary = Characters.LIST[char_index].duplicate()
	d["gun"] = Weapons.LIST[weapon]["model"]
	_scale = float(d.get("scale", 1.0)) * (Config.BOSS_SCALE if boss else 1.0)
	d["scale"] = _scale
	_model = CharacterModel.new()
	_model.setup(d)
	add_child(_model)

	var cap := CapsuleShape3D.new()
	cap.radius = Config.PLAYER_RADIUS * _scale
	cap.height = Config.PLAYER_HEIGHT * _scale
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = cap.height / 2.0
	add_child(col)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = Characters.LIST[char_index]["accent"]
	_label.position.y = Config.PLAYER_HEIGHT * _scale + 0.45
	add_child(_label)
	_update_label()

	_repath = randf() * 0.3
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_strafe_t = randf_range(1.0, 2.5)
	_shot_cd = reaction


func _update_label() -> void:
	var name_txt := String(Characters.LIST[char_index]["name"])
	if boss:
		name_txt = "CAPO " + name_txt
	var bars := int(ceil(10.0 * maxf(hp, 0.0) / max_hp))
	_label.text = "%s\n%s" % [name_txt, "|".repeat(bars)]


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if puppet:
		_follow_net(delta)
		return
	_target_t -= delta
	if _target_t <= 0.0 or _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_target_t = 0.5
		_target = _pick_target()
	var dir := Vector3.ZERO
	var target := global_position
	var chest := global_position
	var eye := global_position + Vector3(0, 1.45 * _scale, 0)
	var dist := 1e9
	if _target:
		target = _target.global_position
		chest = target + Vector3(0, _target.chest_height(), 0)
		dist = global_position.distance_to(target)

	# lo vede? (un raggio contro i muri e i mobili, non a ogni fotogramma)
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = 0.15
		_sees = _target != null and dist < Config.ENEMY_RANGE and not _blocked(eye, chest)
	_seen_for = _seen_for + delta if _sees else 0.0

	# dove andare: se lo vede ed è abbastanza vicino si sposta di lato, altrimenti lo insegue
	if _target == null:
		dir = Vector3.ZERO
	elif _sees and dist < Config.ENEMY_KEEP_DIST * _scale:
		_strafe_t -= delta
		if _strafe_t <= 0.0 or is_on_wall():
			_strafe = -_strafe
			_strafe_t = randf_range(1.0, 2.5)
		var to_p := target - global_position
		to_p.y = 0.0
		dir = to_p.normalized().cross(Vector3.UP) * _strafe * 0.45
	else:
		dir = _path_dir(target, delta)

	var spd := speed * (0.6 if _sees else 1.0)
	if is_on_floor():
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if is_on_wall() and dir.length() > 0.1 and not _sees:
			velocity.y = 6.0                 # ostacolo basso: prova a saltarlo
	else:
		velocity.y -= Config.GRAVITY * delta
		var k := clampf(3.0 * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * spd, k)
		velocity.z = lerpf(velocity.z, dir.z * spd, k)
	move_and_slide()

	# si gira verso il bersaglio se lo vede, altrimenti verso dove cammina
	var face := Vector3.ZERO
	if _sees:
		face = target - global_position
	elif dir.length() > 0.1:
		face = dir
	if Vector2(face.x, face.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), clampf(8.0 * delta, 0.0, 1.0))
	var aim_pitch := 0.0
	if _sees:
		var flat := Vector2(chest.x - eye.x, chest.z - eye.z).length()
		aim_pitch = atan2(chest.y - eye.y, maxf(flat, 0.1))
	_pitch = lerpf(_pitch, aim_pitch, clampf(delta * 8.0, 0.0, 1.0))
	_model.animate(delta, hspeed(), false, _pitch, is_on_floor(), false)

	# spara a raffiche quando lo vede da un po'
	_shot_cd -= delta
	if _sees and _seen_for >= reaction and _shot_cd <= 0.0:
		_shoot(chest)

	if global_position.y < -40.0:
		_die(false)


func hspeed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func pitch() -> float:
	return _pitch


## Il giocatore vivo più vicino (in co-op anche gli omini degli altri, actors/avatar.gd).
func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for t in ondate.targets():
		var d: float = global_position.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


func _blocked(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Config.LAYER_WORLD, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Direzione per raggiungere il bersaglio lungo la mesh di navigazione (se manca, va dritto).
func _path_dir(target: Vector3, delta: float) -> Vector3:
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.4 + randf() * 0.2
		var map := get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, global_position, target, true)
		_path_i = 0
	var goal := target
	while _path_i < _path.size():
		var p := _path[_path_i]
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() < 0.8:
			_path_i += 1
		else:
			goal = p
			break
	var to := goal - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


func _shoot(chest: Vector3) -> void:
	if _burst_left <= 0:
		_burst_left = burst
	_burst_left -= 1
	_shot_cd = fire_delay if _burst_left > 0 else burst_pause

	var from := _model.muzzle.global_position
	var aim := (chest - from).normalized()
	var side := aim.cross(Vector3.UP).normalized()
	var up := side.cross(aim).normalized()
	var dir := (aim + side * randf_range(-spread, spread) + up * randf_range(-spread, spread)).normalized()
	var far := from + dir * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, far, Config.LAYER_WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := far if hit.is_empty() else Vector3(hit["position"])
	var normal := Vector3.UP if hit.is_empty() else Vector3(hit["normal"])

	# lo prende se il colpo passa abbastanza vicino al suo petto prima di sbattere contro qualcosa
	var along := (chest - from).dot(dir)
	var miss := (from + dir * along).distance_to(chest)
	var wall := not hit.is_empty()
	if along > 0.0 and along < from.distance_to(end) and miss < Config.ENEMY_HIT_RADIUS:
		ondate.damage_target(_target, damage)
		end = from + dir * along
		wall = false
	show_shot(end, normal, wall)
	ondate.enemy_shot(self, end, normal, wall)


## Fiammata: colpo luminoso e, se ha preso un muro, il segno (anche sulle copie di rete).
func show_shot(end: Vector3, normal: Vector3, wall: bool) -> void:
	if wall:
		Effetti.impact(get_parent(), end, normal, Weapons.LIST[weapon].get("splat"))
	Effetti.tracer(get_parent(), _model.muzzle.global_position, end, Weapons.LIST[weapon].get("tracer", Config.ENEMY_TRACER))
	_model.recoil()


## Colpito dal giocatore (player.gd _shoot). Ritorna true se muore o se è un colpo in testa (X rossa).
func take_hit(dmg: float, pos_hit: Vector3, dir: Vector3) -> bool:
	if _dead:
		return false
	var head := pos_hit.y - global_position.y > 1.48 * _scale
	var amount := dmg * (Config.HEADSHOT_MULT if head else 1.0)
	if puppet:
		ondate.send_hit(net_id, amount, head)      # il danno lo applica chi ospita
		return head
	return apply_damage(amount, head, dir)


## Toglie vita (anche per i colpi degli altri giocatori in co-op). Ritorna true se muore.
func apply_damage(amount: float, head: bool, dir := Vector3.ZERO) -> bool:
	if _dead:
		return false
	hp -= amount
	velocity += Vector3(dir.x, 0.0, dir.z) * 2.0
	_seen_for = maxf(_seen_for, reaction * 0.5)     # colpito: si accorge di te
	_update_label()
	if hp <= 0.0:
		_die(head)
		return true
	return head


func _die(head: bool) -> void:
	if _dead:
		return
	var points := (500 if boss else 100) + (50 if head else 0)
	fall()
	died.emit(points)


## Cade a terra e sparisce dopo un po' (sulle copie di rete lo chiama game/ondate.gd).
func fall() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	collision_mask = Config.LAYER_WORLD
	_label.visible = false
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", PI / 2, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_model, "position:y", 0.3 * _scale, 0.5)
	tw.tween_interval(2.5)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- copia di rete (co-op)

## Ultimo stato mandato da chi ospita (game/ondate.gd).
func apply_state(pos: Vector3, yaw: float, p: float, spd: float, life: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	_net_pitch = p
	_net_speed = spd
	if not is_equal_approx(life, hp):
		hp = life
		_update_label()


func _follow_net(delta: float) -> void:
	var k := clampf(delta * 15.0, 0.0, 1.0)
	if global_position.distance_to(_net_pos) > 8.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, k)
	rotation.y = lerp_angle(rotation.y, _net_yaw, k)
	_model.animate(delta, _net_speed, false, _net_pitch, true, false)
