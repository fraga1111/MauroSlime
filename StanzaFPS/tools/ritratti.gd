extends SceneTree
## RITRATTI DEI PERSONAGGI: tutti gli omini di data/characters.gd in fila, visti da davanti,
## di tre quarti, di fianco e da dietro, su sfondo neutro. Salva uno screenshot ed esce.
##   Godot..._console.exe --path . -s res://tools/ritratti.gd -- --shot=percorso.png [--from=N]
## --from=N parte dal personaggio N (0 = il primo), utile per guardare da vicino solo i nuovi.

const Characters := preload("res://scripts/data/characters.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")

var _path := "ritratti.png"
var _frames := 0
var _cam_override := PackedFloat64Array()


func _initialize() -> void:
	var first := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_path = a.substr(7)
		elif a.begins_with("--from="):
			first = clampi(int(a.substr(7)), 0, Characters.LIST.size() - 1)
		elif a.begins_with("--cam="):     # --cam=x,y,ampiezza  per un primo piano
			_cam_override = a.substr(6).split_floats(",")

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	root.add_child(sun)

	# una riga per personaggio, quattro pose per riga
	var yaws := [0.0, 35.0, 90.0, 180.0]
	var chars := range(first, Characters.LIST.size())
	for r in chars.size():
		for c in yaws.size():
			var m := CharacterModel.new()
			m.setup(Characters.LIST[chars[r]])
			root.add_child(m)
			m.position = Vector3((c - 1.5) * 1.3, -r * 2.3, 0)
			m.rotation.y = PI + deg_to_rad(yaws[c])
			m.animate(0.0, 0.0, false, 0.0, true, false)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.4 * chars.size() + 0.2
	root.add_child(cam)
	cam.position = Vector3(0, 1.0 - (chars.size() - 1) * 1.15, 10)
	if _cam_override.size() == 3:
		cam.position = Vector3(_cam_override[0], _cam_override[1], 10)
		cam.size = _cam_override[2]
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_path)
		return true
	return false
