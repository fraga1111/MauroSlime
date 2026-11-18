extends SceneTree
## TEST AUTOMATICO (senza grafica) della partita OFFLINE con le ondate di nemici:
##   1) parte l'ondata 1 e compaiono i nemici (omini del menu)
##   2) i nemici trovano la strada (mesh di navigazione) e ti vengono incontro
##   3) ti sparano: la vita del giocatore scende
##   4) uccidendoli l'ondata finisce e la successiva ha nemici più forti
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: Godot..._console.exe --headless --fixed-fps 60 --path . -s res://tools/test_nemici.gd

const Config := preload("res://scripts/config.gd")

var main
var player
var frames := 0
var problems: Array[String] = []
var start_dist := -1.0
var min_dist := 1e9
var hp1 := 0.0
var first_hp := 0.0
var step := 0
var step_t := 0


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


func _tick() -> void:
	frames += 1
	if frames == 2:
		main.start_game(0)
		player = main.player
		player.max_hp = 100000.0      # il giocatore non deve morire durante il test
		player.hp = 100000.0
		first_hp = player.hp
		return
	if player == null:
		return
	var en := _enemies()
	match step:
		0:     # aspetta i nemici e guarda se si avvicinano
			for e in en:
				var d: float = e.global_position.distance_to(player.global_position)
				if start_dist < 0.0:
					start_dist = d
				min_dist = minf(min_dist, d)
			if frames > 60 * 25:
				if main.ondate.wave < 1 or start_dist < 0.0:
					problems.append("nessun nemico comparso (ondata %d)" % main.ondate.wave)
				elif min_dist > start_dist - 4.0:
					problems.append("i nemici non si avvicinano (da %.1f a %.1f m)" % [start_dist, min_dist])
				if player.hp >= first_hp:
					problems.append("i nemici non hanno colpito il giocatore")
				print("ondata %d, nemici %d, distanza %.1f -> %.1f, danno subito %.0f" % [
						main.ondate.wave, en.size(), start_dist, min_dist, first_hp - player.hp])
				if en.size() > 0:
					hp1 = en[0].max_hp
				step = 1
				step_t = frames
		1:     # uccide tutti finché parte l'ondata 2
			for e in en:
				if main.ondate.wave >= 2 and e.max_hp > hp1:
					print("ondata 2: vita nemici %.1f (prima %.1f)" % [e.max_hp, hp1])
					step = 2
					break
			if step == 1 and main.ondate.wave < 2:
				for e in en:
					e.take_hit(1000.0, e.global_position, Vector3.FORWARD)
			if step == 1 and frames - step_t > 60 * 30:
				problems.append("l'ondata 2 non parte o non è più difficile (ondata %d)" % main.ondate.wave)
				step = 2
		2:
			if problems.is_empty():
				print("TEST OK")
				quit(0)
			else:
				print("TEST FALLITO: " + "; ".join(problems))
				quit(1)
