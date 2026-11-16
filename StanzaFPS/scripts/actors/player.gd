extends CharacterBody3D
## Giocatore, sempre in TERZA PERSONA. Le statistiche arrivano dal personaggio scelto.
## Comandi (tasti in game/input_setup.gd): WASD, Shift o tasto laterale del mouse corri, Spazio salta,
## B super salto, Ctrl/C accovacciati (premuto mentre corri = scivolata), Z a terra a strisciare,
## V visuale frontale, click sinistro spara, click destro mira, R ricarica, Esc libera il mouse,
## 1-4 · rotellina · Q cambia arma, E sali/scendi dalla macchinina o dall'aeroplanino (actors/veicolo.gd).
## Tutti i personaggi hanno le stesse abilità (config.gd) e le stesse armi (data/weapons.gd).
## Sul veicolo l'omino diventa figlio del veicolo, seduto; guida il veicolo (i comandi li legge lui).
##
## La telecamera è in actors/follow_camera.gd (segue l'omino ed evita muri e oggetti).
## Qui si decide solo dove guarda (_yaw, _pitch); il corpo viene girato nei passi della fisica.

signal health_changed(hp: float)
signal ammo_changed(mag: int, reserve: int, reloading: bool)
signal hit_target(killed: bool)
signal died
signal front_view_changed(front: bool)
signal weapon_changed(weapon_name: String)
## Ha sparato (per il multiplayer): dove è arrivato il colpo e se ha preso la stanza
signal fired(to: Vector3, normal: Vector3, world: bool)
## Scritta in basso: "E sali sulla macchinina" vicino a un veicolo, i comandi mentre guidi, "" = niente
signal vehicle_hint(text: String)
signal driving_changed(on: bool)

const Config := preload("res://scripts/config.gd")
const Veicolo := preload("res://scripts/actors/veicolo.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")
const FollowCamera := preload("res://scripts/actors/follow_camera.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const Effetti := preload("res://scripts/actors/effetti.gd")

# valori di bilanciamento: si cambiano in config.gd
const BASE_WALK := Config.PLAYER_WALK
const BASE_SPRINT := Config.PLAYER_SPRINT
const BASE_CROUCH := Config.PLAYER_CROUCH
const BASE_JUMP := Config.PLAYER_JUMP
const GRAVITY := Config.GRAVITY
const STAND_HEIGHT := Config.PLAYER_HEIGHT
const CROUCH_HEIGHT := Config.PLAYER_CROUCH_HEIGHT
const STEP_HEIGHT := Config.STEP_HEIGHT
const RELOAD_TIME := Config.RELOAD_TIME
const PITCH_LIMIT := Config.TP_PITCH_LIMIT

## Impostato da main.gd prima di aggiungere il giocatore alla scena
var char_data: Dictionary = {}
## Solo per i test automatici: accetta i comandi anche senza mouse catturato
var auto_test := false

var mouse_sensitivity := Config.MOUSE_SENSITIVITY
var max_hp := 100.0
var hp := 100.0
var alive := true
var mag_size := 30
var mag := 30
var reserve := 180
var damage := 1
var fire_delay := 0.09
var spread_mult := 1.0
var kick_mult := 1.0
var auto_fire := true
var weapon := 0                  # indice in Weapons.LIST
## Arma con cui si parte (scelta nel menu): impostata da main.gd prima di aggiungere il giocatore
var start_weapon := 0
var speed_mult := 1.0
var jump_mult := 1.0
var spawn_point := Vector3.ZERO
var aiming := false
var current_spread := 0.0

var _rig: FollowCamera
var _model: CharacterModel
var _flash_mesh: MeshInstance3D
var _flash_light: OmniLight3D
var _capsule: CapsuleShape3D
var _col: CollisionShape3D
var _step_hit := KinematicCollision3D.new()
var _yaw := 0.0
var _pitch := 0.0
var _recoil := 0.0
var _height := STAND_HEIGHT
var _crouching := false
var _fire_cd := 0.0
var _reload_t := 0.0
var _flash_t := 0.0
var _step_offset := 0.0
var _prone := false              # sdraiato a terra (Z)
var _prone_k := 0.0              # 0 = in piedi, 1 = sdraiato (per l'animazione)
var _slide_t := 0.0              # tempo di scivolata rimasto
var _slide_dir := Vector3.ZERO
var _slide_speed := 0.0
var _slide_k := 0.0
var _sprint_grace := 0.0         # >0 se stavi correndo da poco: Ctrl entro questo tempo = scivolata
var _front_view := false
var _spark_mat: StandardMaterial3D
var _w_mag: Array[int] = []      # colpi nel caricatore di ogni arma (restano quando la cambi)
var _w_reserve: Array[int] = []
var _vehicle: Veicolo = null     # veicolo su cui sei seduto (null = a piedi)
var _home_parent: Node           # dove torna l'omino quando scende
var _hint := ""
var _hint_t := 0.0


func _ready() -> void:
	max_hp = Config.PLAYER_HP
	hp = max_hp
	for w in Weapons.LIST:
		_w_mag.append(int(w["mag"]))
		_w_reserve.append(int(w["reserve"]))
	_load_weapon(start_weapon)

	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD | Config.LAYER_ENEMY | Config.LAYER_VEHICLE
	floor_snap_length = 0.7
	floor_max_angle = deg_to_rad(Config.MAX_SLOPE_DEG)
	floor_constant_speed = true      # stessa velocità in piano e sulla rampa
	spawn_point = global_position
	_yaw = rotation.y

	_capsule = CapsuleShape3D.new()
	_capsule.radius = Config.PLAYER_RADIUS
	_capsule.height = STAND_HEIGHT
	_col = CollisionShape3D.new()
	_col.shape = _capsule
	_col.position.y = STAND_HEIGHT / 2.0
	add_child(_col)

	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1.0, 0.8, 0.4)

	_model = CharacterModel.new()
	var look := char_data.duplicate()
	look["gun"] = Weapons.LIST[weapon]["model"]
	_model.setup(look)
	add_child(_model)
	_make_flash(_model.muzzle)
	_set_flash_color()

	_rig = FollowCamera.new()
	_rig.target = self
	_rig.yaw = _yaw
	_rig.anchor_height = _anchor_height()
	add_child(_rig)


func get_camera() -> Camera3D:
	return _rig.camera


## Sposta di colpo l'omino (comparsa, test): niente scia di interpolazione, telecamera subito a posto.
func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = yaw
	rotation.y = yaw
	_step_offset = 0.0
	reset_physics_interpolation()
	_rig.yaw = yaw
	_rig.snap()


## Centro della semisfera in cima alla capsula: da lì parte la telecamera (è sempre in un punto libero).
func _anchor_height() -> float:
	if _prone:
		return Config.PLAYER_RADIUS       # centro della capsula sdraiata
	return _height - Config.PLAYER_RADIUS


## C'è posto per una capsula alta h (in piedi) o sdraiata (lying) qui dove sta l'omino?
func _space_free(h: float, lying := false) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = Config.PLAYER_RADIUS - 0.02
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Config.LAYER_WORLD
	q.exclude = [get_rid()]
	var up := Vector3.UP * 0.04          # appena sollevata: il pavimento non conta
	if lying:
		shape.height = Config.PLAYER_PRONE_LENGTH
		q.transform = Transform3D(Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, PI / 2),
				global_position + Vector3.UP * Config.PLAYER_RADIUS + up)
	else:
		shape.height = h
		q.transform = Transform3D(Basis(), global_position + Vector3.UP * h / 2.0 + up)
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Capsula di collisione: in piedi/accovacciata (verticale, alta _height) oppure sdraiata (orizzontale).
func _update_shape() -> void:
	if _prone:
		_capsule.height = Config.PLAYER_PRONE_LENGTH
		_col.rotation.x = PI / 2
		_col.position = Vector3(0, Config.PLAYER_RADIUS, 0)
	else:
		_capsule.height = _height
		_col.rotation.x = 0.0
		_col.position = Vector3(0, _height / 2.0, 0)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event.is_action_pressed("interact") and (captured or auto_test):
		if _vehicle:
			exit_vehicle()
		else:
			var v := _near_vehicle()
			if v:
				enter_vehicle(v)
		return
	if _vehicle:
		# sul veicolo il mouse lo usa il veicolo (guardarsi intorno, o dirigere l'aeroplanino); niente armi
		if event is InputEventMouseMotion and captured:
			var r: Vector2 = event.relative
			_vehicle.mouse_look(r * mouse_sensitivity)
		return
	if event.is_action_pressed("front_view"):
		set_front_view(not _front_view)
		return
	if captured or auto_test:
		var n := Weapons.LIST.size()
		if event.is_action_pressed("weapon_next"):
			switch_weapon((weapon + 1) % n)
			return
		for i in n:
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				switch_weapon(i)
				return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				switch_weapon((weapon + 1) % n)
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				switch_weapon((weapon + n - 1) % n)
				return
	if event is InputEventMouseMotion and captured:
		var sens := mouse_sensitivity * (0.6 if aiming else 1.0)
		var rel: Vector2 = event.relative
		_yaw = wrapf(_yaw - rel.x * sens, -PI, PI)
		_pitch = clampf(_pitch - rel.y * sens, -PITCH_LIMIT, PITCH_LIMIT)
		_aim_camera()


## Visuale frontale: la telecamera gira davanti all'omino e lo guarda in faccia (tasto V).
func set_front_view(on: bool) -> void:
	_front_view = on
	_rig.front = on
	front_view_changed.emit(on)


## La telecamera gira subito col mouse (a ogni fotogramma), senza aspettare il passo della fisica.
func _aim_camera() -> void:
	_rig.yaw = _yaw
	_rig.pitch = clampf(_pitch + _recoil, -PITCH_LIMIT, PITCH_LIMIT)


func _process(_delta: float) -> void:
	_model.set_fade(_rig.fade)


# ---------------------------------------------------------------- movimento

func _physics_process(delta: float) -> void:
	if _vehicle:
		_ride(delta)
		return
	rotation.y = _yaw
	if not alive:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var captured := auto_test or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Vector2.ZERO
	if captured:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var crouch := captured and Input.is_action_pressed("crouch")
	aiming = captured and Input.is_action_pressed("aim") and _reload_t <= 0.0
	var on_floor := is_on_floor()

	# a terra / in piedi (Z): ti sdrai solo se c'è posto, e ti rialzi solo se sopra è libero
	if captured and Input.is_action_just_pressed("prone") and on_floor:
		if _prone:
			if _space_free(CROUCH_HEIGHT):
				_prone = false
				_height = CROUCH_HEIGHT
		elif _space_free(0.0, true):
			_prone = true
			_slide_t = 0.0
	# scivolata: Ctrl premuto mentre corri
	if captured and Input.is_action_just_pressed("crouch") and _sprint_grace > 0.0 and on_floor and not _prone:
		var hv0 := Vector3(velocity.x, 0.0, velocity.z)
		_slide_dir = hv0.normalized() if hv0.length() > 0.5 else Basis(Vector3.UP, _yaw) * Vector3.FORWARD
		_slide_speed = maxf(hv0.length(), BASE_SPRINT * speed_mult) * Config.SLIDE_BOOST
		_slide_t = Config.SLIDE_TIME
	var sliding := _slide_t > 0.0
	if sliding:
		_slide_t -= delta
		crouch = true
	if _prone:
		crouch = false

	# accovacciamento (non ti alzi se sopra c'è qualcosa)
	var target_h := CROUCH_HEIGHT if crouch else STAND_HEIGHT
	if not crouch and not _prone and _height < STAND_HEIGHT - 0.01:
		if test_move(global_transform, Vector3.UP * (STAND_HEIGHT - _height)):
			target_h = _height
			crouch = true
	_crouching = crouch
	_height = move_toward(_height, target_h, delta * (8.0 if sliding else 5.0))
	_update_shape()

	var sprint := captured and Input.is_action_pressed("sprint") and input.y < -0.1 \
			and not crouch and not aiming and not _prone
	var speed := BASE_WALK
	if _prone:
		speed = Config.PLAYER_PRONE
	elif crouch:
		speed = BASE_CROUCH
	elif sprint:
		speed = BASE_SPRINT
	if aiming:
		speed *= 0.6
	speed *= speed_mult

	var dir := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	if sliding:
		# scivolata: va dritta e rallenta da sola (un filo di sterzo con A/D)
		var v := _slide_speed * clampf(_slide_t / Config.SLIDE_TIME, 0.0, 1.0)
		_slide_dir = _slide_dir.rotated(Vector3.UP, -input.x * delta * 1.2)
		velocity.x = _slide_dir.x * v
		velocity.z = _slide_dir.z * v
	else:
		var accel := 14.0 if on_floor else 3.0
		var k := clampf(accel * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * speed, k)
		velocity.z = lerpf(velocity.z, dir.z * speed, k)

	if not on_floor:
		velocity.y -= GRAVITY * delta
		_slide_t = 0.0
	elif captured and not _prone and Input.is_action_just_pressed("super_jump"):
		# super salto: altezza fissa (config.gd) x il salto del personaggio
		velocity.y = sqrt(2.0 * GRAVITY * Config.PLAYER_SUPER_JUMP * jump_mult)
		_slide_t = 0.0
	elif captured and not _prone and Input.is_action_just_pressed("jump") and (not crouch or sliding):
		velocity.y = BASE_JUMP * jump_mult
		_slide_t = 0.0
	_sprint_grace = 0.2 if sprint else maxf(_sprint_grace - delta, 0.0)

	_try_step()
	move_and_slide()

	if global_position.y < -40.0:
		place(spawn_point, _yaw)

	_update_weapon(delta, sprint, captured)

	_recoil = lerpf(_recoil, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	_step_offset = lerpf(_step_offset, 0.0, clampf(delta * 12.0, 0.0, 1.0))
	# posa del corpo: sdraiato (ruota in avanti a pancia in giù) o inclinato indietro in scivolata
	var pk := clampf(delta * 8.0, 0.0, 1.0)
	_prone_k = lerpf(_prone_k, 1.0 if _prone else 0.0, pk)
	_slide_k = lerpf(_slide_k, 1.0 if _slide_t > 0.0 else 0.0, clampf(delta * 12.0, 0.0, 1.0))
	_model.rotation.x = -PI / 2 * _prone_k + 0.4 * _slide_k
	_model.position = Vector3(0.0, _step_offset + 0.13 * _prone_k, Config.PLAYER_PRONE_LENGTH / 2.0 * _prone_k)
	_rig.aiming = aiming
	_rig.sprinting = sprint and Vector2(velocity.x, velocity.z).length() > BASE_WALK * speed_mult
	_rig.anchor_height = _anchor_height()
	_aim_camera()
	var hv := Vector2(velocity.x, velocity.z).length()
	_model.animate(delta, hv, _crouching, _pitch, is_on_floor(), _reload_t > 0.0, _prone_k)
	_update_hint(delta)


# ---------------------------------------------------------------- veicoli

## Seduto sul veicolo: si muove insieme a lui (è suo figlio); la telecamera guarda dove dice il veicolo.
func _ride(delta: float) -> void:
	_rig.yaw = _vehicle.cam_yaw()
	_rig.pitch = _vehicle.cam_pitch()
	_model.animate(delta, 0.0, false, -0.25, true, false, 0.0)


## Il veicolo libero più vicino entro Config.ENTER_DISTANCE (null se non ce n'è).
func _near_vehicle() -> Veicolo:
	var best: Veicolo = null
	var best_d := Config.ENTER_DISTANCE
	for n in get_tree().get_nodes_in_group("veicoli"):
		var v := n as Veicolo
		if v == null or v.driver != null:
			continue
		var d := global_position.distance_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


## Sale sul veicolo v: si siede al suo posto e da lì in poi i tasti guidano il veicolo.
func enter_vehicle(v: Veicolo) -> void:
	if _vehicle or not alive or v.driver != null:
		return
	_vehicle = v
	_home_parent = get_parent()
	set_front_view(false)
	_prone = false
	_prone_k = 0.0
	_slide_t = 0.0
	_slide_k = 0.0
	_reload_t = 0.0
	aiming = false
	_height = STAND_HEIGHT
	_update_shape()
	_col.disabled = true
	velocity = Vector3.ZERO
	reparent(v, false)
	transform = v.seat_local(0.85 * _model.scale.y)
	_model.position = Vector3.ZERO
	_model.rotation = Vector3.ZERO
	_model.seated = true
	reset_physics_interpolation()
	v.driver = self
	v.got_in()
	_rig.yaw = v.cam_yaw()
	_rig.pitch = v.cam_pitch()
	_rig.follow(v, v.cam_reach, v.cam_height)
	_set_hint(v.aiuto)
	driving_changed.emit(true)


## Scende: accanto al veicolo nel primo posto libero (exit_spots del veicolo), girato come il veicolo.
func exit_vehicle() -> void:
	if _vehicle == null:
		return
	var v := _vehicle
	var spots := v.exit_spots()
	var spot: Vector3 = v.global_transform * spots[0]
	for s: Vector3 in spots:
		var p: Vector3 = v.global_transform * s
		if _fits_at(p):
			spot = p
			break
	v.driver = null
	v.got_out()
	_vehicle = null
	reparent(_home_parent, false)
	_col.disabled = false
	_model.seated = false
	_rig.follow(self, 0.0, _anchor_height())
	place(spot, v.heading())
	_pitch = 0.0
	_set_hint("")
	driving_changed.emit(false)


## C'è posto per l'omino in piedi coi piedi in p? (contro stanza e veicoli)
func _fits_at(p: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = Config.PLAYER_RADIUS
	shape.height = STAND_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Config.LAYER_WORLD | Config.LAYER_VEHICLE
	q.transform = Transform3D(Basis(), p + Vector3.UP * (STAND_HEIGHT / 2.0 + 0.04))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func in_vehicle() -> bool:
	return _vehicle != null


## A piedi: vicino a un veicolo libero compare "E  sali su ..." (controllato poche volte al secondo).
func _update_hint(delta: float) -> void:
	_hint_t -= delta
	if _hint_t > 0.0:
		return
	_hint_t = 0.15
	var v := _near_vehicle()
	_set_hint("E    sali %s" % v.nome if v else "")


func _set_hint(text: String) -> void:
	if text != _hint:
		_hint = text
		vehicle_hint.emit(text)


## Sale automaticamente i gradini bassi (tastiere, libri) senza saltare.
## Vale solo per ostacoli "a muretto": i pendii percorribili (la rampa) li sale move_and_slide da solo.
## Prima questa funzione scattava anche sulla rampa e l'omino la saliva a saltelli.
func _try_step() -> void:
	if not is_on_floor() or velocity.y > 0.1:
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() < 0.5:
		return
	var probe := hv.normalized() * 0.2
	if not test_move(global_transform, probe, _step_hit):
		return
	if _step_hit.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		return                                    # è un pendio, non un gradino
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT):
		return                                    # non c'è spazio sopra la testa
	var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	if test_move(raised, probe):
		return                                    # ostacolo troppo alto
	# si appoggia esattamente sul gradino (senza restare a mezz'aria)
	var over := raised.translated(probe)
	if not test_move(over, Vector3.DOWN * STEP_HEIGHT, _step_hit):
		return
	if _step_hit.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	var landing := over.origin + _step_hit.get_travel()
	var rise := landing.y - global_position.y
	if rise < 0.03:
		return
	global_position = landing
	_step_offset -= rise                          # l'omino "sale" in modo morbido invece di scattare


# ---------------------------------------------------------------- arma

func _update_weapon(delta: float, sprint: bool, captured: bool) -> void:
	_fire_cd -= delta
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()

	var hv := Vector2(velocity.x, velocity.z).length()
	current_spread = ((0.002 if aiming else 0.02) + hv * 0.002 + (0.0 if is_on_floor() else 0.03)) * spread_mult

	if captured:
		if Input.is_action_just_pressed("reload"):
			_start_reload()
		var trigger := Input.is_action_pressed("fire") if auto_fire else Input.is_action_just_pressed("fire")
		if trigger and not sprint and _reload_t <= 0.0 and _fire_cd <= 0.0:
			if mag > 0:
				_shoot()
			else:
				_start_reload()

	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_mesh.visible = false
			_flash_light.light_energy = 0.0


func _shoot() -> void:
	mag -= 1
	_fire_cd = fire_delay
	ammo_changed.emit(mag, reserve, false)

	# il colpo va dove punta il mirino (centro dello schermo)...
	var cam := _rig.camera.global_transform
	if _front_view:
		# visuale frontale: la telecamera guarda l'omino, quindi si spara dove guarda lui, dal petto
		var chest0 := global_position + Vector3(0, _anchor_height(), 0)
		cam = Transform3D(Basis.from_euler(Vector3(clampf(_pitch + _recoil, -PITCH_LIMIT, PITCH_LIMIT), _yaw, 0.0)), chest0)
	var s := current_spread
	var dir := (-cam.basis.z + cam.basis.x * randf_range(-s, s) + cam.basis.y * randf_range(-s, s)).normalized()
	# ...ma parte all'altezza dell'omino, così non colpisce ciò che sta tra telecamera e personaggio
	var from := cam.origin
	var chest := global_position + Vector3(0, _height * 0.8, 0)
	from += dir * maxf(0.0, (chest - from).dot(dir))
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0,
			Config.LAYER_WORLD | Config.LAYER_ENEMY | Config.LAYER_VEHICLE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var w: Dictionary = Weapons.LIST[weapon]
	var end := from + dir * 400.0
	if not hit.is_empty():
		end = hit["position"]
		var c: Object = hit["collider"]
		if c and c.has_method("take_hit"):
			# take_hit ritorna true se il colpo è "speciale" (nemico ucciso, colpo in testa): X rossa
			var killed: bool = c.take_hit(damage, hit["position"], dir)
			hit_target.emit(killed)
			fired.emit(hit["position"], hit["normal"], false)
		else:
			# sui veicoli il segno resta attaccato alla carrozzeria (si muove con loro)
			_spawn_impact(hit["position"], hit["normal"], c as Veicolo)
			fired.emit(hit["position"], hit["normal"], true)
	else:
		fired.emit(end, Vector3.UP, false)
	if w.has("tracer"):
		Effetti.tracer(get_parent(), _model.muzzle.global_position, end, w["tracer"])

	_recoil += (0.008 if aiming else 0.014) * kick_mult
	_pitch = clampf(_pitch + 0.003, -PITCH_LIMIT, PITCH_LIMIT)
	_yaw += randf_range(-0.003, 0.003)
	_model.recoil()
	_flash_mesh.visible = true
	_flash_mesh.rotation.y = randf() * TAU
	_flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_flash_light.light_energy = 3.0
	_flash_t = 0.045


## Cambia arma (i colpi rimasti in quella vecchia restano lì per quando la riprendi).
func switch_weapon(i: int) -> void:
	if i == weapon or not alive:
		return
	_w_mag[weapon] = mag
	_w_reserve[weapon] = reserve
	_reload_t = 0.0
	_load_weapon(i)
	_fire_cd = maxf(_fire_cd, Config.WEAPON_SWITCH_TIME)
	if _model:
		_model.set_gun(String(Weapons.LIST[i]["model"]))
		_make_flash(_model.muzzle)       # la fiammata vecchia se n'è andata con la vecchia arma
		_set_flash_color()
		_model.recoil()
	ammo_changed.emit(mag, reserve, false)


func _load_weapon(i: int) -> void:
	weapon = i
	var w: Dictionary = Weapons.LIST[i]
	damage = w["damage"]
	fire_delay = w["fire_delay"]
	auto_fire = w["auto"]
	mag_size = w["mag"]
	spread_mult = w["spread"]
	kick_mult = w["kick"]
	mag = _w_mag[i]
	reserve = _w_reserve[i]
	weapon_changed.emit(String(w["name"]))


func _set_flash_color() -> void:
	var c: Color = Weapons.LIST[weapon].get("flash", Color(1.0, 0.7, 0.25))
	(_flash_mesh.material_override as StandardMaterial3D).albedo_color = c
	_flash_light.light_color = c


func _start_reload() -> void:
	if _reload_t > 0.0 or mag >= mag_size or reserve <= 0:
		return
	_reload_t = RELOAD_TIME
	ammo_changed.emit(mag, reserve, true)


func _finish_reload() -> void:
	var take := mini(mag_size - mag, reserve)
	mag += take
	reserve -= take
	ammo_changed.emit(mag, reserve, false)


## Fiammata e lampo di luce sulla bocca dell'arma dell'omino.
func _make_flash(muzzle: Node3D) -> void:
	var holder := Node3D.new()
	holder.rotation.x = -PI / 2
	muzzle.add_child(holder)
	_flash_mesh = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.05
	fm.height = 0.18
	_flash_mesh.mesh = fm
	_flash_mesh.position.y = 0.09
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(1.0, 0.7, 0.25)
	_flash_mesh.material_override = flash_mat
	_flash_mesh.visible = false
	holder.add_child(_flash_mesh)
	_flash_light = OmniLight3D.new()
	_flash_light.position = Vector3(0, 0, -0.1)
	_flash_light.omni_range = 8.0
	_flash_light.light_energy = 0.0
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	muzzle.add_child(_flash_light)


func _spawn_impact(pos: Vector3, normal: Vector3, onto: Node3D = null) -> void:
	Effetti.impact(onto if onto else get_parent(), pos, normal, Weapons.LIST[weapon].get("splat"))

	var spark := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.08
	sp.height = 0.16
	spark.mesh = sp
	spark.material_override = _spark_mat
	spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_parent().add_child(spark)
	spark.global_position = pos + normal * 0.05
	var tw := spark.create_tween()
	tw.tween_property(spark, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(spark.queue_free)


# ---------------------------------------------------------------- vita

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp)
	_recoil -= 0.04
	if hp <= 0.0:
		exit_vehicle()
		alive = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_property(_model, "rotation:x", PI / 2, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_model, "position:y", 0.3, 0.6)
		died.emit()


## Rientra in partita dopo essere stato steso (multiplayer): vita piena, in piedi, al punto di comparsa.
func respawn() -> void:
	hp = max_hp
	alive = true
	_prone = false
	_slide_t = 0.0
	_height = STAND_HEIGHT
	_update_shape()
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	health_changed.emit(hp)
	place(spawn_point, _yaw)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Posa da mandare agli altri giocatori (letta da actors/avatar.gd apply_state).
func net_state() -> Array:
	return [global_position, _yaw, _pitch, Vector2(velocity.x, velocity.z).length(), _crouching,
			is_on_floor(), _reload_t > 0.0, _prone_k, _slide_k, weapon, alive]


## Scatola di graffette presa (game/munizioni.gd): n caricatori in più per ogni arma.
func add_clips(n: int) -> void:
	for i in Weapons.LIST.size():
		var extra := int(Weapons.LIST[i]["mag"]) * n
		if i == weapon:
			reserve += extra
		else:
			_w_reserve[i] += extra
	ammo_changed.emit(mag, reserve, _reload_t > 0.0)


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	health_changed.emit(hp)


func add_ammo(amount: int) -> void:
	reserve += amount
	ammo_changed.emit(mag, reserve, _reload_t > 0.0)
