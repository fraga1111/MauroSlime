extends SceneTree
## PRIMO PIANO DELLE ARMI: ogni arma di data/weapons.gd in una riga, vista di fianco, dall'alto
## e da dietro in alto (come in terza persona). Salva uno screenshot ed esce.
##   Godot..._console.exe --path . -s res://tools/armi.gd -- --shot=percorso.png

const Weapons := preload("res://scripts/data/weapons.gd")
const GunModels := preload("res://scripts/actors/gun_models.gd")

var _path := "armi.png"
var _frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_path = a.substr(7)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.75, 0.74, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)

	# di fianco (destra), dall'alto, da dietro in alto
	var rots := [Vector3(0, -90, 0), Vector3(90, 0, 0), Vector3(35, 180, 0)]
	var n := Weapons.LIST.size()
	for r in n:
		for c in rots.size():
			var g := GunModels.build(String(Weapons.LIST[r]["model"]))
			root.add_child(g)
			g.position = Vector3((c - 1.0) * 1.3, -r * 0.52, 0)    # spillatrice e telefono sono grandi il doppio
			if c == 1:      # dall'alto, con la punta a destra come nella vista di fianco
				g.basis = Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))
			else:
				g.rotation_degrees = rots[c]

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.52 * n + 0.25
	root.add_child(cam)
	cam.position = Vector3(0, -(n - 1) * 0.26, 5)
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_path)
		return true
	return false
