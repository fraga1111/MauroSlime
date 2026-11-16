extends SceneTree
## TEST AUTOMATICO (senza grafica): avvia una partita e controlla che
##   1) gli slime possano arrivare dal corridoio fin sopra l'isola (rampa percorribile);
##   2) gli slime compaiano;
##   3) gli slime raggiungano il giocatore fermo (che perde vita).
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).
## Uso: vedi CLAUDE.md (oppure: bash tools/check.sh)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")

const MAX_FRAMES := 3000

var main
var frames := 0
var problems: Array[String] = []
var max_slimes := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.start_game(0, true)   # al primo frame la scena è pronta (menu visibile)
	if frames < 2:
		return false
	if frames == 30:
		_check_ramp_path()
	if frames % 30 == 0:
		var n := 0
		for c in main.get_children():
			if c.has_method("take_hit"):
				n += 1
		max_slimes = maxi(max_slimes, n)
	var hurt: bool = main.player.hp < main.player.max_hp
	if (hurt and frames > 300) or frames >= MAX_FRAMES:
		if max_slimes == 0:
			problems.append("nessuno slime è comparso")
		if not hurt:
			problems.append("gli slime non hanno raggiunto il giocatore in %d frame" % frames)
		_finish()
	return false


func _check_ramp_path() -> void:
	var nav_map: RID = main.get_world_3d().navigation_map
	var from := Vector3(0.7, 0.05, 2.8) * Config.S              # corridoio oltre la porta
	var to := Vector3(-0.4, Room.T + 0.01, -0.45) * Config.S     # sopra l'isola
	var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.is_empty() or path[path.size() - 1].y < Room.T * Config.S - 1.0:
		problems.append("nessun percorso per gli slime dal corridoio fin sopra l'isola (rampa?)")
	else:
		print("  percorso porta -> isola: %d punti" % path.size())


func _finish() -> void:
	print("  slime visti contemporaneamente: %d, vita giocatore: %.0f, frame: %d" % [max_slimes, main.player.hp, frames])
	if problems.is_empty():
		print("TEST OK")
		quit(0)
	else:
		for p in problems:
			print("TEST FALLITO: " + p)
		quit(1)
