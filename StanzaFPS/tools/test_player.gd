extends SceneTree
## TEST AUTOMATICO (senza grafica) di movimento e telecamera in terza persona:
##   1) l'omino sale la rampa fino sopra l'isola camminando, senza staccarsi da terra, senza "falsi gradini"
##      (il salto automatico dei gradini non deve scattare sul pendio) e con la telecamera stabile;
##      poi la attraversa di sbieco, che era il caso peggiore: il falso gradino scattava a ogni frame;
##   2) vicino ai muri e sotto/sopra i mobili, girando la visuale in tutte le direzioni, la telecamera
##      non finisce mai dentro una parete o un oggetto e tra lei e l'omino non c'è mai niente in mezzo.
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: bash tools/check.sh   (oppure: Godot..._console.exe --headless --fixed-fps 60 --path . -s res://tools/test_player.gd)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")

const S := Config.S
const TURN_STEPS := 24          # direzioni provate in ogni punto
const FRAMES_PER_TURN := 6
const PITCHES := [0.0, 0.9, -0.9]   # dritto, guardando in su, guardando in giù

# punti in cui si prova la telecamera (metri reali): [nome, posizione]
var spots := [
	["parete ovest", Vector3(-Room.W / 2 + 0.022, 0.02, 1.0)],
	["parete est", Vector3(Room.W / 2 - 0.022, 0.02, 0.2)],
	["angolo nord-ovest", Vector3(-Room.W / 2 + 0.03, 0.02, Room.ZN + 0.45)],
	["vano della porta", Vector3((Room.DOOR_X0 + Room.DOOR_X1) / 2 - 0.15, 0.02, Room.ZS + 0.05)],
	["sotto l'isola", Vector3(Room.ICX + 0.3, 0.02, Room.ICZ + 0.4)],
	["sopra l'isola", Vector3(-0.4, Room.T + 0.02, 0.0)],
	["sotto la rampa", Vector3(Room.RAMP_X, 0.02, Room.IZ1 + 0.45)],
	["a metà rampa", Vector3(Room.RAMP_X, Room.T / 2 + 0.02, Room.IZ1 + Room.RAMP_RUN / 2)],
]

var main
var player
var frames := 0
var phase := "avvio"
var problems: Array[String] = []

# fase rampa
var ramp_start := 0
var ramp_air := 0
var ramp_drops := 0
var ramp_last_y := 0.0
var ramp_false_steps := 0
var cam_rel_min := 1000.0       # altezza della telecamera rispetto ai piedi, durante la salita
var cam_rel_max := -1000.0
var cross_start := 0

# fase telecamera
var spot_i := 0
var turn_i := 0
var pitch_i := 0
var turn_frames := 0
var cam_checks := 0
var cam_bad := 0
var cam_min_dist := 1000.0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	match phase:
		"avvio":
			if frames == 2:
				main.nemici = false      # niente ondate di nemici durante il test
				main.start_game(0)        # al primo frame la scena è pronta (menu visibile)
				player = main.player
				player.auto_test = true
			if frames == 20:
				_start_ramp()
		"rampa":
			_ramp_step()
		"sbieco":
			_cross_step()
		"telecamera":
			_camera_step()
	return false


# ---------------------------------------------------------------- 1) rampa

func _start_ramp() -> void:
	phase = "rampa"
	player.place(Vector3(Room.RAMP_X, 0.02, Room.IZ1 + Room.RAMP_RUN + 0.12) * S, 0.0)
	Input.action_press("move_forward")
	ramp_start = frames
	ramp_last_y = player.global_position.y


func _ramp_step() -> void:
	var n := frames - ramp_start
	var y: float = player.global_position.y
	if n > 15:
		if not player.is_on_floor():
			ramp_air += 1
		if y < ramp_last_y - 0.05:
			ramp_drops += 1
		if absf(player._step_offset) > 0.01:
			ramp_false_steps += 1
	if n > 60 and y < Room.T * S - 1.0:      # in piena salita
		var rel: float = player.get_camera().global_position.y - y
		cam_rel_min = minf(cam_rel_min, rel)
		cam_rel_max = maxf(cam_rel_max, rel)
	ramp_last_y = y
	var top := Room.T * S
	var arrived: bool = y > top - 0.1 and player.global_position.z < (Room.IZ1 - 0.05) * S
	if arrived or n > 900:
		Input.action_release("move_forward")
		print("  rampa: %s in %d frame, %d frame staccato da terra, %d ricadute, %d falsi gradini, telecamera stabile entro %.2f m" % ["salita" if arrived else "NON salita", n, ramp_air, ramp_drops, ramp_false_steps, cam_rel_max - cam_rel_min])
		if not arrived:
			problems.append("l'omino non arriva in cima alla rampa (y=%.2f, serve %.2f)" % [y, top])
		if ramp_air > 4:
			problems.append("sulla rampa l'omino si stacca da terra (%d frame): saltella" % ramp_air)
		if ramp_drops > 0:
			problems.append("sulla rampa l'omino ricade indietro %d volte" % ramp_drops)
		if ramp_false_steps > 0:
			problems.append("sulla rampa scatta il salto dei gradini (%d frame)" % ramp_false_steps)
		if cam_rel_max - cam_rel_min > 0.3:
			problems.append("salendo la rampa la telecamera balla in altezza di %.2f m" % (cam_rel_max - cam_rel_min))
		# seconda prova: a metà rampa, quasi di traverso (80° rispetto alla salita)
		phase = "sbieco"
		player.place(Vector3(Room.RAMP_X + Room.RAMP_W * 0.3, Room.T / 2 + 0.02, Room.IZ1 + Room.RAMP_RUN / 2) * S, deg_to_rad(80.0))
		ramp_false_steps = 0
		cross_start = frames


func _cross_step() -> void:
	var n := frames - cross_start
	if n == 15:
		Input.action_press("move_forward")
	if n > 15 and absf(player._step_offset) > 0.01:
		ramp_false_steps += 1
	if n >= 45:
		Input.action_release("move_forward")
		print("  rampa di sbieco: %d falsi gradini in 30 frame" % ramp_false_steps)
		if ramp_false_steps > 0:
			problems.append("attraversando la rampa di sbieco scatta il salto dei gradini (%d frame)" % ramp_false_steps)
		phase = "telecamera"
		_place_spot()


# ---------------------------------------------------------------- 2) telecamera

func _place_spot() -> void:
	var p: Vector3 = spots[spot_i][1]
	player.place(p * S, 0.0)
	turn_i = 0
	pitch_i = 0
	turn_frames = -20          # qualche frame per appoggiarsi a terra


func _camera_step() -> void:
	turn_frames += 1
	if turn_frames < FRAMES_PER_TURN:
		return
	turn_frames = 0
	_check_camera(spots[spot_i][0])
	turn_i += 1
	if turn_i >= TURN_STEPS:
		turn_i = 0
		pitch_i += 1
		if pitch_i >= PITCHES.size():
			spot_i += 1
			if spot_i >= spots.size():
				_finish()
				return
			_place_spot()
			return
	player._yaw = wrapf(TAU * turn_i / TURN_STEPS, -PI, PI)
	player._pitch = PITCHES[pitch_i]


func _check_camera(spot_name: String) -> void:
	cam_checks += 1
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var cam: Vector3 = player.get_camera().global_position
	var head: Vector3 = player.global_position + Vector3(0, player._anchor_height(), 0)
	cam_min_dist = minf(cam_min_dist, cam.distance_to(head))
	var where := "%s, direzione %d/%d, inclinazione %.1f" % [spot_name, turn_i, TURN_STEPS, PITCHES[pitch_i]]

	# a) niente tra la testa dell'omino e la telecamera
	var ray := PhysicsRayQueryParameters3D.create(head, cam, Config.LAYER_WORLD, [player.get_rid()])
	if not space.intersect_ray(ray).is_empty():
		cam_bad += 1
		problems.append("c'è un ostacolo tra omino e telecamera (%s)" % where)
		return
	# b) la telecamera non è dentro un muro o un oggetto (sfera grande quanto basta a coprire il piano vicino)
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), cam)
	q.collision_mask = Config.LAYER_WORLD
	q.exclude = [player.get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		cam_bad += 1
		problems.append("la telecamera tocca un muro o un oggetto (%s)" % where)


func _finish() -> void:
	print("  telecamera: %d posizioni controllate in %d punti, %d sbagliate, distanza minima dall'omino %.2f" % [cam_checks, spots.size(), cam_bad, cam_min_dist])
	if problems.is_empty():
		print("TEST OK")
		quit(0)
	else:
		for i in mini(problems.size(), 12):
			print("TEST FALLITO: " + problems[i])
		if problems.size() > 12:
			print("TEST FALLITO: ...e altri %d" % (problems.size() - 12))
		quit(1)
