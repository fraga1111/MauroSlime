extends SceneTree
## TEST AUTOMATICO (senza grafica) di classifica, nemici, forziere, zoom e storico:
##   1) giocando con BROSKI nessun nemico è BROSKI, e tutti i nemici hanno l'alone rosso
##   2) colpendo i nemici salgono danni, punti (= danni x POINTS_PER_DAMAGE) e uccisioni; un nemico
##      colpito da un "amico" finto e finito da te dà l'assist all'amico
##   3) a fine ondata compare il forziere con un'arma diversa; passandoci sopra hai 2 armi e Q le cambia
##   4) zoom: click = forte, doppio click = leggero, click tenuto = si toglie al rilascio
##   5) storico: record e classifica di tutti i tempi da partite finte; classifica a schermo senza errori
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: Godot..._console.exe --headless --fixed-fps 60 --path . -s res://tools/test_novita.gd

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")
const Storico := preload("res://scripts/game/storico.gd")

const BROSKI := 4

var main
var player
var frames := 0
var problems: Array[String] = []
var step := 0
var seen := 0
var assist_done := false


func _init() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _enemies() -> Array:
	var out := []
	for c in main.get_children():
		if c is CharacterBody3D and c.has_method("take_hit") and c != player and not c._dead:
			out.append(c)
	return out


func _end() -> void:
	if problems.is_empty():
		print("TEST OK")
		quit(0)
	else:
		print("TEST FALLITO: " + "; ".join(problems))
		quit(1)


func _tick() -> void:
	frames += 1
	if frames == 2:
		main.start_game(BROSKI)
		player = main.player
		player.max_hp = 100000.0
		player.hp = 100000.0
		return
	if player == null:
		return
	player.hp = 100000.0
	var en := _enemies()
	match step:
		0:
			# nemici dell'ondata 1: controllo personaggio e alone, poi li abbatto
			for e in en:
				seen += 1
				if e.char_index == BROSKI:
					problems.append("un nemico è BROSKI come il giocatore")
				var m: MeshInstance3D = e.find_children("*", "MeshInstance3D", true, false)[0]
				if m.material_overlay == null:
					problems.append("nemico senza alone rosso")
				if not assist_done:
					# un amico finto (id 77) lo colpisce, io lo finisco: assist a lui, uccisione a me
					e.apply_damage(1.0, false, Vector3.ZERO, 77)
					assist_done = true
				e.take_hit(1000.0, e.global_position + Vector3(0, 0.5, 0), Vector3.FORWARD)
			if main.forziere and is_instance_valid(main.forziere):
				print("ondata 1 finita: nemici visti %d" % seen)
				step = 1
			elif frames > 60 * 60:
				problems.append("niente forziere a fine ondata (ondata %d)" % main.ondate.wave)
				_end()
		1:
			main.punteggi.flush()
			var me: Dictionary = main.punteggi.my_row()
			print("io: punti %d, danni %.1f, uccisioni %d, assist %d" % [me["points"], me["damage"], me["kills"], me["assists"]])
			if int(me["kills"]) < seen or int(me["points"]) <= 0:
				problems.append("uccisioni/punti sbagliati: %s (nemici %d)" % [str(me), seen])
			if int(me["points"]) != int(round(float(me["damage"]) * Config.POINTS_PER_DAMAGE)):
				problems.append("punti diversi da danni x %d" % int(Config.POINTS_PER_DAMAGE))
			var friend := {}
			for r in main.punteggi.rows():
				if int(r["peer"]) == 77:
					friend = r
			if friend.is_empty() or int(friend["assists"]) != 1 or int(friend["kills"]) != 0:
				problems.append("assist dell'amico sbagliato: %s" % str(friend))
			step = 2
		2:
			# il forziere si apre dopo un po': ci vado sopra
			var f = main.forziere
			if f and is_instance_valid(f) and f._open:
				var w: int = f.weapon
				if player.owned.has(w):
					problems.append("il forziere dà un'arma che hai già")
				player.place(f.global_position + Vector3(0, 0.3, 0), 0.0)
				step = 3
				seen = frames
			elif frames > 60 * 80:
				problems.append("il forziere non si apre")
				_end()
		3:
			if frames - seen > 20:
				if player.owned.size() != 2:
					problems.append("dopo il forziere le armi sono %d" % player.owned.size())
				else:
					var before: int = player.weapon
					var ev := InputEventAction.new()
					ev.action = "weapon_next"
					ev.pressed = true
					player.auto_test = true
					player._unhandled_input(ev)
					if player.weapon == before:
						problems.append("Q non cambia arma")
					print("armi: %s, in mano %d (prima %d)" % [str(player.owned), player.weapon, before])
				_test_zoom()
				_test_storico()
				_end()


func _test_zoom() -> void:
	player.zoom = 0
	player._zoom_press_t = -10.0
	player._zoom_click(true)
	player._zoom_click(false)
	if player.zoom != 2:
		problems.append("un click destro non dà lo zoom forte (%d)" % player.zoom)
	player._zoom_click(true)               # subito dopo: doppio click
	if player.zoom != 1:
		problems.append("il doppio click non dà lo zoom leggero (%d)" % player.zoom)
	player._zoom_press_t = -10.0
	player._zoom_click(true)
	if player.zoom != 0:
		problems.append("un click con lo zoom acceso non lo toglie (%d)" % player.zoom)
	player._zoom_click(true)
	player._zoom_click(false)
	player.zoom = 2
	player._zoom_press_t = Time.get_ticks_msec() / 1000.0 - 1.0     # tenuto premuto un secondo
	player._zoom_click(false)
	if player.zoom != 0:
		problems.append("lasciando il click tenuto lo zoom non si toglie (%d)" % player.zoom)
	print("zoom ok" if problems.is_empty() else "zoom: problemi")


func _test_storico() -> void:
	var fake := Storico.example()
	var lb := Storico.leaderboard(fake)
	if lb.size() != 2 or String(lb[0]["name"]) != "Matteo" or int(lb[0]["kills"]) != 19 or int(lb[0]["partite"]) != 2:
		problems.append("classifica di tutti i tempi sbagliata: %s" % str(lb))
	var rec := Storico.records(fake)
	if String(rec[0][1]) != "6" or String(rec[1][1]) != "1200" or String(rec[2][1]) != "500":
		problems.append("record sbagliati: %s" % str(rec))
	main.hud.show_scoreboard("PROVA", main.punteggi.rows(), main.punteggi.my_id(), "fine")
	print("storico ok: %s primo con %d uccisioni" % [lb[0]["name"], lb[0]["kills"]])
