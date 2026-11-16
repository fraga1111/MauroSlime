extends "res://scripts/actors/veicolo.gd"
## AEROPLANINO DI CARTA: un foglio A4 a quadretti piegato a freccia, lungo 28 cm veri (5 m di gioco).
## Si sale con E e ci si siede a cavalcioni sulla piega. Comandi:
##   mouse = dove andare (l'aeroplanino gira piano piano verso dove guardi)
##   W più veloce · S più piano · A/D gira · Spazio sali · Ctrl scendi · E scendi (anche in volo: cadi giù)
## Per decollare: W per prendere velocità sul pavimento, poi mouse in su (o Spazio).
## Volo "da sala giochi": va dove punti; in picchiata accelera, in salita rallenta; sotto
## Config.PLANE_MIN_FLY non regge più e scende col muso giù. Contro i muri rimbalza.
## Senza nessuno sopra plana dritto fino a terra e si ferma. Numeri in config.gd, sezione "aeroplanino".

const LEN := 5.0      # lunghezza (metri di gioco)
const SPAN := 3.6     # apertura delle ali
const KEEL := 0.55    # altezza della chiglia sotto le ali: è quella che tocca terra

var speed := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _aim_yaw := 0.0      # dove vuole andare chi pilota (mouse, A/D)
var _aim_pitch := 0.0
var _fall := 0.0


func _init() -> void:
	nome = "sull'aeroplanino"
	aiuto = "MOUSE dirige    W più veloce    S più piano    A D gira    SPAZIO sali    CTRL scendi    E scendi"
	cam_reach = Config.PLANE_CAM_DISTANCE
	cam_height = KEEL + 1.7
	seat = Vector3(0.0, KEEL + 0.06, 0.7)    # a cavalcioni sulla piega, un po' dietro il centro


func _ready() -> void:
	super()
	floor_snap_length = 0.2
	_yaw = rotation.y
	_aim_yaw = _yaw
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.5, 3.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.25, 0.3)
	add_child(col)
	_build()


## Fa partire l'aeroplanino già in volo a velocità v (screenshot e test).
func launch(v: float) -> void:
	speed = v
	_fall = 0.0


# ---------------------------------------------------------------- volo

func _physics_process(delta: float) -> void:
	if check_fallen():
		_yaw = rotation.y
		_aim_yaw = _yaw
		_pitch = 0.0
		_roll = 0.0
		speed = 0.0
		return
	var pilot := controls()
	var thrust := 0.0
	if pilot:
		thrust = Input.get_axis("move_back", "move_forward")
		var turn := Input.get_axis("move_left", "move_right")
		var climb := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
		_aim_yaw -= turn * Config.PLANE_TURN * delta
		_aim_pitch = clampf(_aim_pitch + climb * 0.9 * delta, -1.0, 0.9)
	var on_floor := is_on_floor()

	# velocità: W/S; senza tasti in aria torna alla velocità di crociera, a terra si ferma
	if thrust > 0.0:
		speed = move_toward(speed, Config.PLANE_MAX_SPEED, Config.PLANE_ACCEL * delta)
	elif thrust < 0.0:
		speed = move_toward(speed, 0.0, Config.PLANE_ACCEL * 1.5 * delta)
	elif on_floor:
		speed = move_toward(speed, 0.0, Config.PLANE_ACCEL * 0.6 * delta)
	else:
		speed = move_toward(speed, Config.PLANE_CRUISE, Config.PLANE_ACCEL * 0.25 * delta)
	if not on_floor:
		# in picchiata accelera, in salita rallenta
		speed = clampf(speed - sin(_pitch) * Config.GRAVITY * 0.5 * delta, 0.0, Config.PLANE_MAX_SPEED * 1.25)
	var lift := clampf(inverse_lerp(Config.PLANE_MIN_FLY * 0.5, Config.PLANE_MIN_FLY, speed), 0.0, 1.0)

	if not pilot:
		# nessuno pilota: plana dritto, un po' in giù, fino a terra
		_aim_yaw = _yaw
		_aim_pitch = lerpf(_aim_pitch, -0.2, clampf(delta, 0.0, 1.0))
	var want_pitch := _aim_pitch
	if not on_floor and lift < 1.0:
		want_pitch = minf(want_pitch, lerpf(-0.6, 0.3, lift))   # troppo piano: muso giù
	if on_floor and speed < Config.PLANE_MIN_FLY:
		want_pitch = 0.0                                         # rullaggio: ancora niente decollo
	var rate := Config.PLANE_TURN * delta
	var dyaw := clampf(angle_difference(_yaw, _aim_yaw), -rate, rate)
	_yaw += dyaw
	_pitch = move_toward(_pitch, want_pitch, rate)
	if on_floor:
		_pitch = maxf(_pitch, 0.0)
	# in curva si inclina sull'ala (a terra no)
	var want_roll := 0.0 if on_floor else clampf(dyaw / maxf(delta, 0.001) * 0.45, -0.9, 0.9)
	_roll = lerpf(_roll, want_roll, clampf(delta * 4.0, 0.0, 1.0))
	global_basis = Basis.from_euler(Vector3(_pitch, _yaw, _roll))

	var fwd := Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3.FORWARD
	if on_floor or lift >= 1.0:
		_fall = move_toward(_fall, 0.0, Config.GRAVITY * delta)
	else:
		_fall = maxf(_fall - Config.GRAVITY * (1.0 - lift) * delta, -12.0)
	velocity = fwd * speed + Vector3.UP * _fall
	if on_floor and velocity.y <= 0.0:
		velocity.y = -1.0
	move_and_slide()

	# botta contro un muro (o il soffitto): rimbalza e perde velocità
	for i in get_slide_collision_count():
		var nrm := get_slide_collision(i).get_normal()
		if nrm.angle_to(Vector3.UP) <= floor_max_angle:
			continue
		if -fwd.dot(nrm) > 0.35 and speed > 4.0:
			var out := fwd.bounce(nrm)
			_yaw = atan2(-out.x, -out.z)
			_aim_yaw = _yaw
			_pitch = clampf(asin(clampf(out.y, -1.0, 1.0)), -0.4, 0.4)
			_aim_pitch = _pitch
			speed *= 0.35
		break


func mouse_look(rel: Vector2) -> void:
	_aim_yaw -= rel.x
	_aim_pitch = clampf(_aim_pitch - rel.y, -1.0, 0.9)


func cam_yaw() -> float:
	return _aim_yaw


func cam_pitch() -> float:
	return clampf(_aim_pitch * 0.8 - 0.18, -1.1, 0.7)


func heading() -> float:
	return _yaw


func got_in() -> void:
	_aim_yaw = _yaw
	_aim_pitch = _pitch


func exit_spots() -> Array[Vector3]:
	return [
		Vector3(-SPAN / 2 - 0.7, 0.05, 0.6),
		Vector3(SPAN / 2 + 0.7, 0.05, 0.6),
		Vector3(0.0, 0.05, LEN / 2 + 0.8),
		Vector3(0.0, KEEL + 0.1, 0.6),          # in piedi sopra, se intorno è tutto pieno
	]


# ---------------------------------------------------------------- modello

func _build() -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = _quadretti()
	paper.roughness = 0.95
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := LEN / 2.0
	var nose := Vector3(0.0, KEEL, -hl)
	var tail := Vector3(0.0, KEEL, hl)
	for side in [-1.0, 1.0]:
		var tip := Vector3(side * SPAN / 2.0, KEEL + 0.28, hl - 0.25)
		_tri(st, nose, tail, tip)                                       # ala
		_tri(st, tip, tip + (nose - tip) * 0.25, tip + Vector3(0.0, 0.4, 0.05))   # aletta alzata in punta
		# chiglia: due fogli piegati sotto la piega centrale
		var o := Vector3(side * 0.015, 0.0, 0.0)
		var back_bottom := Vector3(0.0, 0.0, hl - 0.35)
		var front_bottom := Vector3(0.0, 0.0, -0.4)
		_tri(st, nose + o, tail + o, back_bottom + o)
		_tri(st, nose + o, back_bottom + o, front_bottom + o)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = paper
	add_child(mi)
	# scritta a penna sull'ala sinistra
	var l := Label3D.new()
	l.text = "MAURO AIR"
	l.font_size = 64
	l.pixel_size = 0.004
	l.outline_size = 0
	l.modulate = Color(0.1, 0.2, 0.75)
	l.position = Vector3(-0.75, KEEL + 0.14, 1.2)
	l.rotation_degrees = Vector3(-90.0, 90.0, 0.0)
	add_child(l)


## Triangolo di carta (normale piatta; quadretti presi dalla posizione).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.z, v.y) * 1.5 if absf(n.x) > 0.7 else Vector2(v.x, v.z) * 1.5)
		st.add_vertex(v)


## Foglio a quadretti: bianco con le righe azzurrine (8 quadretti per lato della texture).
static func _quadretti() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.95))
	var line := Color(0.7, 0.79, 0.95)
	for i in 64:
		for j in 8:
			img.set_pixel(i, j * 8, line)
			img.set_pixel(j * 8, i, line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
