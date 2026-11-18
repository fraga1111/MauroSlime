extends Node3D
## TELECAMERA IN TERZA PERSONA, da sopra la spalla destra dell'omino.
##
## Come evita muri e oggetti (due "spinte" con una sfera, a ogni fotogramma):
##   1) dal centro della testa (che è dentro la capsula dell'omino, quindi sempre libero) verso la spalla:
##      se a destra c'è un muro, la telecamera si sposta meno di lato invece di finirci dentro;
##   2) dalla spalla all'indietro: se dietro c'è qualcosa, la telecamera si avvicina.
## Si avvicina subito (mai dentro un muro) e si riallontana piano (niente scatti).
## Di norma sta sulla spalla destra; se da quel lato c'è un muro e dall'altro no, passa da sola
## alla spalla sinistra (e torna a destra quando il muro finisce), così l'omino non copre il mirino.
## Quando è troppo vicina all'omino, "fade" sale verso 1 e il giocatore lo rende trasparente.
##
## Gira nei fotogrammi di disegno (_process) e non in quelli della fisica, usando la posizione
## interpolata dell'omino: così il movimento è fluido anche su schermi oltre i 60 Hz.
## I numeri (distanza, spalla, FOV...) sono in config.gd, sezione "telecamera".

const Config := preload("res://scripts/config.gd")

## Impostati dal giocatore
var target: CharacterBody3D      # l'omino da seguire
var yaw := 0.0                   # dove guarda (radianti)
var pitch := 0.0
var aiming := false
var zoom := 2                    # mirando: 2 = zoom forte, 1 = zoom leggero (player.gd)
var sprinting := false           # correndo: FOV un po' più largo
var front := false               # visuale frontale: la telecamera gira davanti all'omino e lo guarda
var anchor_height := 1.45        # altezza sopra i piedi del punto sicuro (centro della "testa" della capsula)
## Guidando (macchinina, aeroplanino): distanza fissa dietro il veicolo, niente spalla; 0 = a piedi.
## Si imposta con follow().
var drive_reach := 0.0

var camera: Camera3D
var fade := 0.0                  # 0 = omino ben visibile, 1 = telecamera addosso all'omino

var _side_query: PhysicsShapeQueryParameters3D
var _back_query: PhysicsShapeQueryParameters3D
var _feet_y := 0.0
var _anchor := 1.45
var _reach := Config.TP_DISTANCE
var _side := 1.0                 # +1 = spalla destra, -1 = spalla sinistra
var _shoulder := Config.TP_SHOULDER    # spostamento laterale attuale (negativo = a sinistra)
var _side_k := 1.0
var _dist := Config.TP_DISTANCE
var _snap := true
var _front_k := 0.0              # 0 = dietro, 1 = davanti (gira intorno all'omino in modo morbido)
var _drive_yaw := 0.0            # guidando: la telecamera insegue la direzione con un filo di ritardo


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.fov = Config.TP_FOV
	camera.near = 0.05
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	# la prima sfera è un po' più grande: così la seconda parte già staccata dal muro di fianco
	_side_query = _make_query(Config.TP_CAM_RADIUS + 0.07)
	_back_query = _make_query(Config.TP_CAM_RADIUS)


## Da chiamare dopo un teletrasporto: la telecamera salta subito al posto giusto.
func snap() -> void:
	_snap = true


## Segue t: un veicolo (reach > 0, telecamera dietro a distanza reach) oppure l'omino (reach = 0).
## height = altezza sopra l'origine di t del punto da cui parte la telecamera (deve essere libero).
func follow(t: CharacterBody3D, reach: float, height: float) -> void:
	target = t
	drive_reach = reach
	anchor_height = height
	_drive_yaw = yaw
	_side_query.exclude = [t.get_rid()]
	_back_query.exclude = [t.get_rid()]


func _process(delta: float) -> void:
	if target == null:
		return
	var feet := target.get_global_transform_interpolated().origin
	var k := 1.0 - exp(-delta * 12.0)
	if _snap:
		_snap = false
		k = 1.0
		_feet_y = feet.y
		_side_k = 1.0
		_dist = 1000.0
		_side = 1.0
		_shoulder = Config.TP_SHOULDER

	# l'altezza segue l'omino con un filo di ritardo: gradini e atterraggi non danno scossoni
	_feet_y = clampf(lerpf(_feet_y, feet.y, 1.0 - exp(-delta * 20.0)), feet.y - 0.8, feet.y + 0.8)
	_anchor = lerpf(_anchor, anchor_height, k)
	_front_k = move_toward(_front_k, 1.0 if front else 0.0, delta * 3.0)
	var fk := smoothstep(0.0, 1.0, _front_k)
	var driving := drive_reach > 0.0
	var want_reach := Config.TP_ADS_DISTANCE if aiming else Config.TP_DISTANCE
	if driving:
		want_reach = drive_reach
	_reach = lerpf(_reach, lerpf(want_reach, Config.TP_FRONT_DISTANCE, fk), k)
	var ads_fov := Config.TP_ADS_LIGHT_FOV if zoom == 1 else Config.TP_ADS_FOV
	var want_fov := ads_fov if aiming else (Config.TP_SPRINT_FOV if sprinting else Config.TP_FOV)
	camera.fov = lerpf(camera.fov, lerpf(want_fov, Config.TP_FOV, fk), 1.0 - exp(-delta * 9.0))
	# visuale frontale: la telecamera ruota di mezzo giro intorno all'omino, senza spalla, poco dall'alto
	var cyaw := yaw + PI * fk
	var cpitch := lerpf(pitch, -0.18 - pitch * 0.25, fk)
	if driving:
		# guidando la telecamera insegue la direzione del veicolo con un filo di ritardo (niente scatti in curva)
		_drive_yaw = yaw if k >= 1.0 else lerp_angle(_drive_yaw, yaw, 1.0 - exp(-delta * 5.0))
		cyaw = _drive_yaw

	# 1) dal punto sicuro verso la spalla (scegliendo prima quale spalla)
	var safe := feet + Vector3(0.0, anchor_height, 0.0)
	var right := Basis(Vector3.UP, cyaw).x
	var lift := Vector3(0.0, _feet_y + _anchor + Config.TP_LIFT - safe.y, 0.0)
	var reach_side := (Config.TP_ADS_SHOULDER if aiming else Config.TP_SHOULDER) * (1.0 - fk) + 0.001
	if driving:
		reach_side = 0.001
	var free_right := _free_fraction(_side_query, safe, lift + right * reach_side)
	var free_left := _free_fraction(_side_query, safe, lift - right * reach_side)
	if _side > 0.0 and free_right < 0.7 and free_left > free_right + 0.25:
		_side = -1.0
	elif _side < 0.0 and (free_right > 0.95 or free_right > free_left + 0.25):
		_side = 1.0
	_shoulder = lerpf(_shoulder, _side * reach_side, 1.0 - exp(-delta * 7.0))
	var to_pivot := lift + right * _shoulder
	var side_free := _free_fraction(_side_query, safe, to_pivot)
	_side_k = side_free if side_free < _side_k else lerpf(_side_k, side_free, 1.0 - exp(-delta * 8.0))
	var pivot := safe + to_pivot * _side_k

	# 2) dalla spalla all'indietro
	var b := Basis.from_euler(Vector3(cpitch, cyaw, 0.0))
	var back_free := _reach * _free_fraction(_back_query, pivot, b.z * _reach)
	_dist = back_free if back_free < _dist else lerpf(_dist, back_free, 1.0 - exp(-delta * 6.0))
	global_transform = Transform3D(b, pivot + b.z * _dist)

	var d := global_position.distance_to(safe)
	fade = clampf(inverse_lerp(Config.TP_FADE_START, Config.TP_FADE_END, d), 0.0, 1.0)


## Quanta parte dello spostamento "motion" è libera partendo da "from" (1 = tutta).
func _free_fraction(query: PhysicsShapeQueryParameters3D, from: Vector3, motion: Vector3) -> float:
	if motion.length_squared() < 0.000001:
		return 1.0
	query.transform = Transform3D(Basis(), from)
	query.motion = motion
	var res := get_world_3d().direct_space_state.cast_motion(query)
	if res.is_empty():
		return 1.0
	var safe_fraction: float = res[0]
	return safe_fraction


func _make_query(radius: float) -> PhysicsShapeQueryParameters3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Config.LAYER_WORLD
	q.margin = 0.03
	if target:
		q.exclude = [target.get_rid()]
	return q
