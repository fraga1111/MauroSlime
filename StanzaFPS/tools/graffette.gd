extends SceneTree
## PRIMO PIANO di scatola di graffette (game/munizioni.gd), colpo fluo e macchia (actors/effetti.gd).
##   Godot..._console.exe --path . -s res://tools/graffette.gd -- --shot=percorso.png

const Munizioni := preload("res://scripts/game/munizioni.gd")
const Effetti := preload("res://scripts/actors/effetti.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var _path := "graffette.png"
var _frames := 0
var _world: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_path = a.substr(7)
	_world = Node3D.new()
	root.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.75, 0.74, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	_world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.45, 0.5)
	floor_mi.material_override = fm
	_world.add_child(floor_mi)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(20, 6, 0.2)
	wall.mesh = wm
	wall.position = Vector3(0, 3, 3)
	_world.add_child(wall)
	var box := Munizioni._box_model()
	_world.add_child(box)
	box.rotation.y = 0.5
	var c: Color = Weapons.LIST[0]["splat"]
	for i in 6:
		Effetti.impact(_world, Vector3(-1.0 + i * 0.35, 1.2 + (i % 3) * 0.3, 2.9), Vector3.FORWARD, c)
	Effetti.impact(_world, Vector3(1.0, 1.4, 2.9), Vector3.FORWARD, null)
	var cam := Camera3D.new()
	cam.fov = 50
	_world.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(1.2, 1.3, -2.2)).looking_at(Vector3(0.0, 0.35, 0.0))


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 30:
		Effetti.tracer(_world, Vector3(2.0, 1.4, -1.5), Vector3(-1.0, 1.0, 2.9), Weapons.LIST[0]["tracer"])
	if _frames == 31:
		root.get_viewport().get_texture().get_image().save_png(_path)
		return true
	return false
