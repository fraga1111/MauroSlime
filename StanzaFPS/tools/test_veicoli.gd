extends SceneTree
## TEST AUTOMATICO (senza grafica) dei veicoli (actors/macchinina.gd, actors/aeroplanino.gd):
##   1) vicino alla macchinina il giocatore la "vede" (E) e ci sale: diventa suo figlio, seduto
##   2) col gas (W) va avanti; con D gira a destra; scendendo l'omino torna a piedi accanto alla portiera
##   3) la macchinina sale la rampa fino sopra le scrivanie
##   4) l'aeroplanino prende velocità a terra (W), decolla (Spazio) e sale; scendendo in volo l'omino cade a terra
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: bash tools/check.sh   (oppure: Godot..._console.exe --headless --fixed-fps 60 --path . -s res://tools/test_veicoli.gd)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")
const S := Config.S

var main
var player
var car
var plane
var frames := 0
var step := 0
var t0 := 0
var problems: Array[String] = []
var pos0 := Vector3.ZERO
var yaw0 := 0.0
var max_y := 0.0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var n := frames - t0
	match step:
		0:
			if frames == 3:
				main.nemici = false      # niente ondate di nemici durante il test
				main.start_game(0)
				player = main.player
				player.auto_test = true
				car = main.macchinina
				plane = main.aeroplanino
			if frames == 30:
				# accanto alla portiera del guidatore
				player.place(car.global_transform * Vector3(-2.0, 0.05, 0.0), car.rotation.y)
			if frames == 40:
				if player._near_vehicle() != car:
					problems.append("accanto alla macchinina il giocatore non la trova (E)")
				player.enter_vehicle(car)
				if player.get_parent() != car or not player._model.seated:
					problems.append("salendo l'omino non si siede nella macchinina")
				pos0 = car.global_position
				yaw0 = car.heading()
				Input.action_press("move_forward")
				_next()
		1:  # gas
			if n == 60:
				var d: float = car.global_position.distance_to(pos0)
				print("  macchinina: dopo 1 s di gas %.1f m/s, %.1f m percorsi" % [car.speed, d])
				if car.speed < 8.0 or d < 5.0:
					problems.append("col gas la macchinina non parte (%.1f m/s, %.1f m)" % [car.speed, d])
				Input.action_press("move_right")
			if n == 90:
				Input.action_release("move_right")
				Input.action_release("move_forward")
				var turned: float = angle_difference(yaw0, car.heading())
				print("  macchinina: con D ha girato di %.0f gradi" % rad_to_deg(turned))
				if turned > -0.2:
					problems.append("con D la macchinina non gira a destra (%.2f rad)" % turned)
				Input.action_press("move_back")
			if n == 150:
				Input.action_release("move_back")
				player.exit_vehicle()
				var away: float = player.global_position.distance_to(car.global_position)
				if player.get_parent() != main or player._model.seated or player._col.disabled:
					problems.append("scendendo l'omino non torna a piedi")
				elif away > Config.ENTER_DISTANCE:
					problems.append("scendendo l'omino finisce lontano dalla macchinina (%.1f m)" % away)
				_next()
		2:  # rampa: macchinina davanti alla rampa, muso verso l'isola
			if n == 30:
				car.global_position = Vector3(Room.RAMP_X, 0.0, Room.IZ1 + Room.RAMP_RUN + 0.25) * S
				car._heading = 0.0
				car.speed = 0.0
				car.reset_physics_interpolation()
				player.place(car.global_transform * Vector3(-2.0, 0.05, 0.0), 0.0)
			if n == 35:
				player.enter_vehicle(car)
				Input.action_press("move_forward")
			if n == 180:                    # in cima: via il gas e freno a mano (non cadere dall'altra parte)
				Input.action_release("move_forward")
				Input.action_press("jump")
			if n == 260:
				Input.action_release("jump")
			if n == 320:
				var y: float = car.global_position.y
				print("  macchinina sulla rampa: arriva a %.1f m (scrivanie a %.1f m)" % [y, Room.T * S])
				if y < Room.T * S - 1.0:
					problems.append("la macchinina non sale la rampa (y=%.1f)" % y)
				player.exit_vehicle()
				_next()
		3:  # aeroplanino: rullaggio, decollo, salita
			if n == 10:
				player.place(plane.global_transform * Vector3(-2.6, 0.05, 0.6), plane.rotation.y)
			if n == 20:
				player.enter_vehicle(plane)
				pos0 = plane.global_position
				Input.action_press("move_forward")
			if n == 90:
				print("  aeroplanino: a terra prende %.1f m/s" % plane.speed)
				if plane.speed < Config.PLANE_MIN_FLY:
					problems.append("l'aeroplanino non prende velocità a terra (%.1f m/s)" % plane.speed)
				Input.action_press("jump")
			max_y = maxf(max_y, plane.global_position.y)
			if n == 170:
				Input.action_release("jump")
				Input.action_release("move_forward")
				print("  aeroplanino: decollato, salito di %.1f m" % (max_y - pos0.y))
				if max_y - pos0.y < 3.0:
					problems.append("l'aeroplanino non decolla (salito %.1f m)" % (max_y - pos0.y))
				player.exit_vehicle()
			if n == 400:
				var py: float = player.global_position.y
				print("  sceso in volo: l'omino è a %.1f m, l'aeroplanino a %.1f m" % [py, plane.global_position.y])
				if not player.is_on_floor():
					problems.append("sceso dall'aeroplanino in volo l'omino non torna a terra")
				_finish()


func _next() -> void:
	step += 1
	t0 = frames


func _finish() -> void:
	if problems.is_empty():
		print("TEST OK")
		quit(0)
	else:
		for p in problems:
			print("TEST FALLITO: " + p)
		quit(1)
