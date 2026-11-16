extends "res://scripts/actors/veicolo.gd"
## MACCHININA: Opel Agila del 2010, bianca. È un modellino in scala 1:18 (come quelli da collezione):
## lungo 21 cm veri, quindi nel gioco ha le misure di un'Agila vera (3,74 × 1,62 × 1,59 m di gioco)
## e l'omino ci sta seduto dentro, al posto di guida (a sinistra).
## Comandi (E per salire e scendere): W gas · S freno e retromarcia · A/D sterza · Spazio freno a mano ·
## Shift turbo · L fari · mouse = guardati intorno (la telecamera torna dietro da sola).
## Guida "da sala giochi": velocità lungo il muso + sterzo a bicicletta, niente motore fisico vero.
## Sulla rampa la macchinina (e la sua collisione) si inclina come il pavimento: si sale sulle scrivanie.
## Numeri (velocità, sterzo, telecamera) in config.gd, sezione "macchinina".

const LEN := 3.74          # lunghezza (metri di gioco)
const WID := 1.62          # larghezza della carrozzeria (specchietti esclusi)
const WHEELBASE := 2.36    # passo: distanza tra le ruote davanti e dietro
const WHEEL_R := 0.31
const ROOF := 1.59

## Profilo della carrozzeria vista di fianco, sotto i finestrini: punti (z, y), muso verso -z.
## Il tratto dal punto OPEN_EDGE al successivo (linea di cintura) resta aperto: è l'abitacolo, si vede dentro.
const PROFILE := [
	Vector2(-1.78, 0.22), Vector2(-1.87, 0.34), Vector2(-1.87, 0.6), Vector2(-1.82, 0.75),
	Vector2(-1.66, 0.87), Vector2(-1.06, 0.99), Vector2(1.72, 1.03), Vector2(1.86, 0.98),
	Vector2(1.87, 0.4), Vector2(1.8, 0.22),
]
const OPEN_EDGE := 5

var speed := 0.0                 # lungo il muso, metri di gioco al secondo (negativa = retromarcia)
var _heading := 0.0              # direzione del muso (radianti)
var _steer := 0.0                # sterzata delle ruote davanti (positiva = a destra)
var _fall := 0.0
var _up := Vector3.UP            # verso dell'"alto" della macchinina (segue il pavimento)
var _spin := 0.0
var _look_yaw := 0.0             # sguardo col mouse rispetto al muso
var _look_pitch := -0.22
var _look_idle := 0.0
var _lights_on := false
var _wheels: Array[Node3D] = []
var _steer_pivots: Array[Node3D] = []
var _lights: Array[SpotLight3D] = []
var _head_mat: StandardMaterial3D
var _brake_mat: StandardMaterial3D


func _init() -> void:
	nome = "sulla macchinina"
	aiuto = "W gas    S freno / retro    A D sterza    SPAZIO freno a mano    SHIFT turbo    L fari    E scendi"
	cam_reach = Config.CAR_CAM_DISTANCE
	cam_height = 2.3
	seat = Vector3(-0.36, 0.5, 0.05)       # anca di chi guida: posto di guida a sinistra


func _ready() -> void:
	super()
	floor_snap_length = 0.6
	floor_constant_speed = true
	_heading = rotation.y
	var shape := BoxShape3D.new()
	shape.size = Vector3(WID, 1.45, LEN - 0.06)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.725
	add_child(col)
	_build()


# ---------------------------------------------------------------- guida

func _physics_process(delta: float) -> void:
	if check_fallen():
		_heading = rotation.y
		speed = 0.0
		return
	var gas := 0.0
	var turn := 0.0
	var hand := false
	var turbo := false
	if controls():
		gas = Input.get_axis("move_back", "move_forward")
		turn = Input.get_axis("move_left", "move_right")
		hand = Input.is_action_pressed("jump")
		turbo = Input.is_action_pressed("sprint")

	# velocità: gas, freno (S mentre vai avanti), retromarcia (S da fermo), rallenta da sola
	var top := Config.CAR_TURBO_SPEED if turbo else Config.CAR_MAX_SPEED
	if gas > 0.0:
		speed = move_toward(speed, top * gas, (Config.CAR_BRAKE if speed < 0.0 else Config.CAR_ACCEL) * delta)
	elif gas < 0.0:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, Config.CAR_BRAKE * delta)
		else:
			speed = move_toward(speed, -Config.CAR_REVERSE, Config.CAR_ACCEL * delta)
	else:
		speed = move_toward(speed, 0.0, Config.CAR_DRAG * delta)
	if hand:
		speed = move_toward(speed, 0.0, Config.CAR_BRAKE * 0.8 * delta)

	# sterzo: alle alte velocità le ruote girano meno (si guida meglio)
	var fast := clampf(absf(speed) / Config.CAR_TURBO_SPEED, 0.0, 1.0)
	_steer = move_toward(_steer, turn * Config.CAR_STEER * lerpf(1.0, 0.45, fast), delta * 2.5)
	var on_floor := is_on_floor()
	if on_floor:
		# sterzo "a bicicletta"; col freno a mano gira di più (derapata)
		_heading -= speed / WHEELBASE * tan(_steer) * delta * (1.7 if hand else 1.0)

	# si inclina come il pavimento (rampa); in aria torna dritta piano piano
	var n := get_floor_normal() if on_floor else Vector3.UP
	_up = _up.slerp(n, clampf(delta * (10.0 if on_floor else 2.0), 0.0, 1.0)).normalized()
	var flat := Vector3(-sin(_heading), 0.0, -cos(_heading))
	var right := flat.cross(_up).normalized()
	var fwd := _up.cross(right).normalized()
	global_basis = Basis(right, _up, -fwd)

	if on_floor:
		_fall = 0.0
		velocity = fwd * speed
	else:
		_fall -= Config.GRAVITY * delta
		velocity = flat * speed + Vector3.UP * _fall
	move_and_slide()
	# contro un muro si ferma (o rallenta se lo struscia)
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().angle_to(Vector3.UP) > floor_max_angle:
			var along := velocity.dot(fwd)
			if absf(along) < absf(speed):
				speed = along * 0.7
			break

	# ruote che girano e sterzano, luci dei freni, telecamera che torna dietro
	_spin -= speed / WHEEL_R * delta
	for w in _wheels:
		w.rotation.x = _spin
	for p in _steer_pivots:
		p.rotation.y = -_steer
	_brake_mat.emission_energy_multiplier = 3.0 if hand or (gas < 0.0 and speed > 0.5) else 0.6
	_look_idle += delta
	if _look_idle > 1.5:
		var k := clampf(delta * 2.0, 0.0, 1.0)
		_look_yaw = lerpf(_look_yaw, 0.0, k)
		_look_pitch = lerpf(_look_pitch, -0.22, k)


func _unhandled_input(event: InputEvent) -> void:
	if controls() and event.is_action_pressed("lights"):
		_lights_on = not _lights_on
		for l in _lights:
			l.visible = _lights_on
		_head_mat.emission_energy_multiplier = 3.0 if _lights_on else 0.4


func mouse_look(rel: Vector2) -> void:
	_look_yaw = clampf(_look_yaw - rel.x, -2.8, 2.8)
	_look_pitch = clampf(_look_pitch - rel.y, -1.0, 0.45)
	_look_idle = 0.0


func cam_yaw() -> float:
	return _heading + _look_yaw


func cam_pitch() -> float:
	return _look_pitch


func heading() -> float:
	return _heading


func got_in() -> void:
	_look_yaw = 0.0
	_look_pitch = -0.22


func exit_spots() -> Array[Vector3]:
	return [
		Vector3(-WID / 2 - 0.75, 0.05, 0.0),     # dalla portiera del guidatore
		Vector3(WID / 2 + 0.75, 0.05, 0.0),
		Vector3(0.0, 0.05, LEN / 2 + 0.8),
		Vector3(0.0, 0.05, -LEN / 2 - 0.8),
		Vector3(0.0, ROOF + 0.05, 0.4),          # sul tetto, se intorno è tutto pieno
	]


# ---------------------------------------------------------------- modello

func _build() -> void:
	var hw := WID / 2.0
	var white := mat(Color(0.93, 0.93, 0.92), 0.22, 0.15)
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var black := mat(Color(0.03, 0.03, 0.035), 0.9)
	var plastic := mat(Color(0.12, 0.12, 0.13), 0.75)
	var chrome := mat(Color(0.82, 0.82, 0.85), 0.2, 0.8)
	var silver := mat(Color(0.7, 0.71, 0.74), 0.35, 0.6)
	var glass := mat(Color(0.1, 0.14, 0.18, 0.3), 0.05, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark_glass := mat(Color(0.06, 0.08, 0.1), 0.08, 0.4)
	var inside := mat(Color(0.15, 0.15, 0.16), 0.9)
	var cloth := mat(Color(0.22, 0.22, 0.25), 0.95)
	_head_mat = lamp(Color(1.0, 0.97, 0.88), 0.4)
	_brake_mat = lamp(Color(0.85, 0.04, 0.04), 0.6)
	var orange := lamp(Color(1.0, 0.55, 0.1), 0.4)

	# carrozzeria sotto i finestrini (fianchi + fascia lungo il contorno)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh(hw)
	body.material_override = white
	add_child(body)

	# passaruota (dischi neri dietro le ruote), ruote con copricerchio
	for i in 4:
		var front := i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := -WHEELBASE / 2 if front else WHEELBASE / 2
		var arch := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.39
		am.bottom_radius = 0.39
		am.height = 0.01
		arch.mesh = am
		arch.material_override = black
		arch.rotation.z = PI / 2
		arch.position = Vector3(side * (hw + 0.004), WHEEL_R + 0.02, z)
		add_child(arch)
		var pivot := Node3D.new()
		pivot.position = Vector3(side * (hw - 0.05), WHEEL_R, z)
		add_child(pivot)
		var w := Node3D.new()
		pivot.add_child(w)
		_cyl(w, WHEEL_R, 0.24, black)
		_cyl(w, 0.2, 0.25, silver)
		box(w, Vector3(0.01, 0.34, 0.05), Vector3(side * 0.127, 0, 0), plastic)
		box(w, Vector3(0.01, 0.05, 0.34), Vector3(side * 0.127, 0, 0), plastic)
		_wheels.append(w)
		if front:
			_steer_pivots.append(pivot)

	# abitacolo: montanti, tetto, vetri (trasparenti: si vede l'omino che guida)
	var a_bot := Vector2(-1.06, 0.99)          # base del parabrezza
	var a_top := Vector2(-0.36, 1.53)          # cima del parabrezza
	for side in [-1.0, 1.0]:
		var x: float = side * (hw - 0.04)
		slab(self, a_bot, a_top, 0.07, 0.07, white, x)                                   # montante A
		box(self, Vector3(0.07, 0.54, 0.1), Vector3(x, 1.28, 0.42), white)                # montante B
		box(self, Vector3(0.07, 0.54, 0.5), Vector3(x, 1.28, 1.6), white)                 # montante C
		box(self, Vector3(0.015, 0.47, 0.77), Vector3(side * (hw - 0.035), 1.27, -0.02), glass)  # finestrino davanti
		box(self, Vector3(0.015, 0.47, 0.82), Vector3(side * (hw - 0.035), 1.27, 0.89), glass)   # finestrino dietro
		box(self, Vector3(0.16, 0.36, 0.05), Vector3(side * (hw - 0.1), 1.2, 1.86), _brake_mat) # fanali alti dietro
		box(self, Vector3(0.18, 0.05, 0.05), Vector3(side * (hw - 0.12), 0.98, 1.88), orange)  # frecce dietro
		box(self, Vector3(0.44, 0.14, 0.3), Vector3(side * 0.52, 0.75, -1.72), _head_mat, Vector3(-25, 0, 0))  # fari
		box(self, Vector3(0.12, 0.05, 0.06), Vector3(side * 0.66, 0.72, -1.82), orange)           # frecce davanti
		box(self, Vector3(0.18, 0.11, 0.09), Vector3(side * (hw + 0.08), 1.06, -0.86), white)     # specchietti
		box(self, Vector3(0.16, 0.09, 0.01), Vector3(side * (hw + 0.08), 1.06, -0.81), dark_glass)
		box(self, Vector3(0.03, 0.1, 1.66), Vector3(side * (hw + 0.006), 0.28, 0.0), plastic)     # minigonne
		for dz in [-0.55, 0.42, 1.3]:                                                           # linee delle portiere
			box(self, Vector3(0.006, 0.66, 0.012), Vector3(side * (hw + 0.002), 0.66, dz), black)
		for dz in [0.15, 1.05]:                                                                 # maniglie
			box(self, Vector3(0.02, 0.035, 0.14), Vector3(side * (hw + 0.01), 0.9, dz), plastic)
	box(self, Vector3(WID - 0.06, 0.08, 2.18), Vector3(0, ROOF - 0.04, 0.72), white)            # tetto
	slab(self, a_bot, a_top, WID - 0.16, 0.015, glass)                                         # parabrezza
	# portellone: cornice bianca e lunotto trasparente (da dietro si vede chi guida)
	box(self, Vector3(WID - 0.1, 0.12, 0.06), Vector3(0, 1.08, 1.84), white)
	box(self, Vector3(WID - 0.1, 0.07, 0.06), Vector3(0, 1.53, 1.81), white)
	box(self, Vector3(WID - 0.3, 0.38, 0.015), Vector3(0, 1.33, 1.83), glass, Vector3(-6, 0, 0))
	box(self, Vector3(0.015, 0.36, 0.015), Vector3(0, ROOF + 0.15, 1.5), black, Vector3(-30, 0, 0))  # antenna

	# davanti e dietro: paraurti, griglia, targhe
	box(self, Vector3(WID + 0.02, 0.2, 0.1), Vector3(0, 0.38, -1.84), plastic)
	box(self, Vector3(WID + 0.02, 0.22, 0.1), Vector3(0, 0.42, 1.84), plastic)
	box(self, Vector3(0.72, 0.12, 0.06), Vector3(0, 0.66, -1.85), black)
	box(self, Vector3(0.5, 0.025, 0.02), Vector3(0, 0.7, -1.885), chrome)
	_plate(Vector3(0, 0.46, -1.9), true)
	_plate(Vector3(0, 0.66, 1.88), false)

	# dentro: pavimento, cruscotto, volante, sedili
	box(self, Vector3(WID - 0.04, 0.05, LEN - 0.5), Vector3(0, 0.4, 0.1), inside)
	box(self, Vector3(WID - 0.06, 0.22, 0.42), Vector3(0, 0.9, -0.9), inside)
	slab(self, Vector2(-0.82, 0.88), Vector2(-0.62, 1.0), 0.05, 0.05, plastic, seat.x)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.18
	ring.mesh = tm
	ring.material_override = plastic
	ring.position = Vector3(seat.x, 1.0, -0.6)
	ring.rotation.x = deg_to_rad(65.0)
	add_child(ring)
	for side in [-1.0, 1.0]:
		box(self, Vector3(0.52, 0.1, 0.5), Vector3(side * 0.36, 0.44, 0.05), cloth)
		box(self, Vector3(0.52, 0.62, 0.12), Vector3(side * 0.36, 0.78, 0.36), cloth, Vector3(10, 0, 0))
		box(self, Vector3(0.28, 0.16, 0.1), Vector3(side * 0.36, 1.2, 0.44), cloth)
	box(self, Vector3(1.4, 0.1, 0.5), Vector3(0, 0.46, 1.0), cloth)
	box(self, Vector3(1.4, 0.6, 0.12), Vector3(0, 0.8, 1.3), cloth, Vector3(8, 0, 0))

	# fari veri (si accendono con L)
	for side in [-1.0, 1.0]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(side * 0.52, 0.8, -1.92)
		sl.rotation.x = -0.08
		sl.spot_range = 30.0
		sl.spot_angle = 28.0
		sl.light_energy = 4.0
		sl.light_color = Color(1.0, 0.96, 0.85)
		sl.visible = false
		add_child(sl)
		_lights.append(sl)


## Fianchi (il profilo PROFILE a x = ±hw) e fascia che li unisce lungo il contorno, tranne l'abitacolo.
func _body_mesh(hw: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector2Array(PROFILE)
	var tris := Geometry2D.triangulate_polygon(pts)
	for side in [-1.0, 1.0]:
		for i in tris.size():
			var p: Vector2 = pts[tris[i]]
			st.set_normal(Vector3(side, 0.0, 0.0))
			st.add_vertex(Vector3(side * hw, p.y, p.x))
	var count := pts.size()
	for i in count:
		if i == OPEN_EDGE:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		var d := b - a
		var n := Vector3(0.0, d.x, -d.y).normalized()       # verso l'esterno (il contorno gira in senso orario)
		for q in [[a, -hw], [a, hw], [b, hw], [a, -hw], [b, hw], [b, -hw]]:
			var p: Vector2 = q[0]
			st.set_normal(n)
			st.add_vertex(Vector3(q[1], p.y, p.x))
	return st.commit()


## Cilindro con l'asse lungo x (ruote).
func _cyl(parent: Node3D, r: float, w: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = w
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = m
	mi.rotation.z = PI / 2
	parent.add_child(mi)


## Targa italiana: bianca con la fascia blu a sinistra (front = davanti, guarda verso -z).
func _plate(pos: Vector3, front: bool) -> void:
	var out := -1.0 if front else 1.0
	box(self, Vector3(0.52, 0.12, 0.012), pos, mat(Color(0.95, 0.95, 0.95), 0.4))
	box(self, Vector3(0.05, 0.12, 0.014), pos + Vector3(0.235 * -out, 0, 0), mat(Color(0.05, 0.2, 0.7), 0.4))
	var l := Label3D.new()
	l.text = "MS 010 AG"
	l.font_size = 64
	l.pixel_size = 0.0011
	l.outline_size = 0
	l.modulate = Color(0.05, 0.05, 0.05)
	l.double_sided = false
	l.position = pos + Vector3(0.02 * out, 0, out * 0.008)
	l.rotation.y = PI if front else 0.0
	add_child(l)
