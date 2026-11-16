extends SceneTree
## TEST AUTOMATICO (senza grafica) delle mosse del giocatore:
##   1) corsa: con Shift va più veloce che camminando
##   2) scivolata: Ctrl mentre corri -> parte più veloce della corsa, si abbassa e poi si ferma da sola
##   3) a terra (Z): si sdraia (capsula orizzontale), striscia piano, si rialza
##   4) visuale frontale (V): la telecamera finisce davanti all'omino
##   5) super salto (B): dal pavimento si arriva sul sedile di una sedia; il salto normale invece no
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: bash tools/check.sh   (oppure: Godot..._console.exe --headless --fixed-fps 60 --path . -s res://tools/test_moves.gd)
## I tasti "appena premuti" vanno simulati nel passo della fisica, per questo si usa il segnale physics_frame.

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")
const S := Config.S

# sedia della postazione est vicino alla porta (Room.STATIONS[3]): sedile a 0,49 m reali
const CHAIR := Vector3(Room.ICX + 1.2, 0.0, 0.15)
const SEAT_TOP := 0.49

var main
var player
var frames := 0
var step := 0
var t0 := 0
var problems: Array[String] = []
var walk_speed := 0.0
var sprint_speed := 0.0
var slide_peak := 0.0
var slide_low := 100.0
var pos0 := Vector3.ZERO
var max_y := 0.0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _hv() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _tap(action: String) -> void:
	Input.action_press(action)


func _tick() -> void:
	frames += 1
	var n := frames - t0
	match step:
		0:
			if frames == 3:
				main.start_game(0)
				player = main.player
				player.auto_test = true
			if frames == 20:
				_next()
				player.place(Vector3(-1.35, 0.02, 1.3) * S, -PI / 2)     # verso est, lungo la stanza
		1:  # camminata e corsa
			if n == 5:
				Input.action_press("move_forward")
			if n == 40:
				walk_speed = _hv()
				Input.action_press("sprint")
			if n == 75:
				sprint_speed = _hv()
				print("  corsa: camminando %.1f m/s, correndo %.1f m/s" % [walk_speed, sprint_speed])
				if sprint_speed < walk_speed * 1.5:
					problems.append("la corsa non è abbastanza più veloce (%.1f contro %.1f)" % [sprint_speed, walk_speed])
				_tap("crouch")
				_next()
		2:  # scivolata
			if n == 1:
				Input.action_release("crouch")
				Input.action_release("sprint")
			if n < 8:
				slide_peak = maxf(slide_peak, _hv())
			slide_low = minf(slide_low, player._height)
			if n == 70:
				Input.action_release("move_forward")
				print("  scivolata: picco %.1f m/s, altezza minima %.2f, dopo %.2f s velocità %.1f" % [slide_peak, slide_low, n / 60.0, _hv()])
				if slide_peak < sprint_speed * 1.15:
					problems.append("la scivolata non parte più veloce della corsa (%.1f)" % slide_peak)
				if slide_low > Config.PLAYER_CROUCH_HEIGHT + 0.2:
					problems.append("in scivolata l'omino non si abbassa (altezza %.2f)" % slide_low)
				_next()
				player.place(Vector3(-1.35, 0.02, 1.3) * S, -PI / 2)
		3:  # a terra
			if n == 10:
				_tap("prone")
			if n == 11:
				Input.action_release("prone")
			if n == 30:
				if not player._prone or absf(player._col.rotation.x - PI / 2) > 0.01:
					problems.append("premendo Z l'omino non si sdraia")
				pos0 = player.global_position
				Input.action_press("move_forward")
			if n == 90:
				Input.action_release("move_forward")
				var d: float = player.global_position.distance_to(pos0)
				print("  a terra: strisciato %.2f m in 1 s (in piedi sarebbero %.1f)" % [d, walk_speed])
				if d < 0.5 or d > walk_speed * 0.6:
					problems.append("strisciando percorre %.2f m in 1 s (atteso piano ma non fermo)" % d)
				_tap("prone")
			if n == 91:
				Input.action_release("prone")
			if n == 140:
				if player._prone:
					problems.append("premendo di nuovo Z l'omino non si rialza")
				elif player._height < Config.PLAYER_HEIGHT - 0.05:
					problems.append("dopo essersi rialzato l'omino resta basso (%.2f)" % player._height)
				_next()
		4:  # visuale frontale
			if n == 1:
				player.set_front_view(true)
			if n == 60:
				var fwd: Vector3 = Basis(Vector3.UP, player._yaw) * Vector3.FORWARD
				var rel: Vector3 = player.get_camera().global_position - player.global_position
				var look: Vector3 = -player.get_camera().global_transform.basis.z
				print("  visuale frontale: telecamera %.1f m davanti, guarda verso l'omino: %s" % [rel.dot(fwd), look.dot(fwd) < -0.5])
				if rel.dot(fwd) < 1.5 or look.dot(fwd) > -0.5:
					problems.append("con V la telecamera non va davanti all'omino")
				player.set_front_view(false)
			if n == 120:
				var rel2: Vector3 = player.get_camera().global_position - player.global_position
				var fwd2: Vector3 = Basis(Vector3.UP, player._yaw) * Vector3.FORWARD
				if rel2.dot(fwd2) > -1.0:
					problems.append("ripremendo V la telecamera non torna dietro")
				_next()
				# davanti alla sedia, sul pavimento, guardando il sedile (verso est)
				player.place(Vector3(CHAIR.x - 0.3, 0.02, CHAIR.z) * S, -PI / 2)
				max_y = 0.0
		5:  # salto normale: non arriva sul sedile
			max_y = maxf(max_y, player.global_position.y)
			if n == 10:
				_tap("jump")
			if n == 11:
				Input.action_release("jump")
			if n == 80:
				print("  salto normale: arriva a %.1f m (sedile a %.1f m)" % [max_y, SEAT_TOP * S])
				_next()
				player.place(Vector3(CHAIR.x - 0.3, 0.02, CHAIR.z) * S, -PI / 2)
				max_y = 0.0
		6:  # super salto sulla sedia
			max_y = maxf(max_y, player.global_position.y)
			if n == 10:
				_tap("super_jump")
			if n == 11:
				Input.action_release("super_jump")
			if n == 30:
				Input.action_press("move_forward")
			if n == 75:
				Input.action_release("move_forward")
			if n == 180:
				var y: float = player.global_position.y
				var on_seat: bool = player.is_on_floor() and absf(y - SEAT_TOP * S) < 0.6
				print("  super salto: arriva a %.1f m, atterra a %.1f m (sedile %.1f): %s" % [max_y, y, SEAT_TOP * S, "sulla sedia" if on_seat else "NON sulla sedia"])
				if not on_seat:
					problems.append("col super salto non si arriva sulla sedia (y=%.2f)" % y)
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
