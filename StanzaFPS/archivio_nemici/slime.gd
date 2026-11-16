extends CharacterBody3D
## Nemico: slime che saltella verso il giocatore seguendo la mesh di navigazione.
## Le statistiche (vita, velocità, danno) le imposta game/waves.gd prima di aggiungerlo alla scena.

signal died(points: int)

const Config := preload("res://scripts/config.gd")
const GRAVITY := Config.GRAVITY

var player                      # riferimento al giocatore (impostato da game/waves.gd)
var hp := 3
var speed := 4.0
var damage := 10.0
var size := 1.0
var color := Config.SLIME_GREEN

var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _hop := 0.0
var _hit_cd := 0.0
var _flash := 0.0
var _dead := false
var _body: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = Config.LAYER_ENEMY
	collision_mask = Config.LAYER_WORLD | Config.LAYER_PLAYER | Config.LAYER_ENEMY
	var r := 0.6 * size

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	cs.position.y = r
	add_child(cs)

	_body = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r * 1.1
	m.height = r * 1.7
	_body.mesh = m
	_body.position.y = r * 0.85
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.82)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.15
	_mat.emission_enabled = true
	_mat.emission = color * 0.25
	_body.material_override = _mat
	add_child(_body)

	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	for s in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = r * 0.2
		em.height = r * 0.4
		eye.mesh = em
		eye.material_override = white
		eye.position = Vector3(s * r * 0.35, r * 0.25, -r * 0.85)
		_body.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = r * 0.1
		pm.height = r * 0.2
		pupil.mesh = pm
		pupil.material_override = black
		pupil.position = Vector3(0, 0, -r * 0.14)
		eye.add_child(pupil)

	_hop = randf() * 0.5
	_repath = randf() * 0.3


func _physics_process(delta: float) -> void:
	if _dead or player == null:
		return
	_hit_cd -= delta
	_repath -= delta
	var ppos: Vector3 = player.global_position

	if _repath <= 0.0:
		_repath = 0.35 + randf() * 0.2
		var map := get_world_3d().navigation_map
		_path = NavigationServer3D.map_get_path(map, global_position, ppos, true)
		_path_i = 0

	var target := ppos
	while _path_i < _path.size():
		var p := _path[_path_i]
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() < 0.8:
			_path_i += 1
		else:
			target = p
			break

	var to := target - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.05 else Vector3.ZERO

	if is_on_floor():
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_hop -= delta
		if _hop <= 0.0:
			velocity.y = 5.0
			_hop = 0.45 + randf() * 0.4
			if is_on_wall():
				velocity.y = 7.0  # prova a scavalcare l'ostacolo
	else:
		velocity.y -= GRAVITY * delta
		var k := clampf(3.0 * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * speed, k)
		velocity.z = lerpf(velocity.z, dir.z * speed, k)

	move_and_slide()

	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))

	# schiacciamento "gelatinoso" in base alla velocità verticale
	var sq := clampf(velocity.y * 0.04, -0.2, 0.25)
	_body.scale = _body.scale.lerp(Vector3(1.0 - sq, 1.0 + sq, 1.0 - sq), clampf(10.0 * delta, 0.0, 1.0))

	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_mat.emission = color * 0.25

	# danno a contatto
	if _hit_cd <= 0.0 and global_position.distance_to(ppos) < 0.75 * size + 0.9:
		player.take_damage(damage)
		_hit_cd = Config.SLIME_HIT_COOLDOWN

	if global_position.y < -40.0:
		_die()


## Chiamata dal giocatore quando il proiettile colpisce. Ritorna true se muore.
func take_hit(dmg: int, _pos: Vector3, dir: Vector3) -> bool:
	if _dead:
		return false
	hp -= dmg
	_flash = 0.07
	_mat.emission = Color(1, 1, 1) * 0.8
	velocity += Vector3(dir.x, 0.0, dir.z) * 3.0
	if hp <= 0:
		_die()
		return true
	return false


func _die() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	collision_mask = Config.LAYER_WORLD
	died.emit(int(100 * size))
	_spawn_splat()
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(1.7, 0.1, 1.7), 0.18)
	tw.tween_callback(queue_free)


func _spawn_splat() -> void:
	var splat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9 * size
	cm.bottom_radius = 0.9 * size
	cm.height = 0.02
	splat.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	splat.material_override = m
	get_parent().add_child(splat)
	splat.global_position = global_position + Vector3(0, 0.02, 0)
	var tw := splat.create_tween()
	tw.tween_interval(15.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(splat.queue_free)
