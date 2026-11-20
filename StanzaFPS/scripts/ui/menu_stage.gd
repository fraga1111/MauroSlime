extends Node3D
## SCHERMATA INIZIALE: i personaggi "in vetrina" sul pavimento della stanza, una telecamera
## che li guarda e il menu a schede (ui/menu.gd). Quando si preme GIOCA emette start_game.
## Stile "scelta del personaggio": la stanza è quasi al buio, ogni omino sta su un PIATTO girevole
## (come quello del microonde) e un FARO dall'alto illumina solo quello scelto. Accanto, su un piatto
## più piccolo con il suo faro, c'è l'ARMA scelta in grande. Quando scegli un omino o un'arma
## il piatto fa un giro in più (_kick). Le luci della stanza tornano normali quando il menu si chiude.

signal start_game(index: int, weapon: int, stile: String)
signal host_game(index: int, weapon: int, stile: String, player_name: String, coop: bool)
signal join_game(index: int, weapon: int, stile: String, player_name: String, ip: String)

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")
const CharacterModel := preload("res://scripts/actors/character_model.gd")
const GunModels := preload("res://scripts/actors/gun_models.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

# posizioni in metri reali (stessi assi di world/room.gd)
const MODELS_CENTER := Vector3(-0.55, 0.0, 1.05)   # omini in fila, centrati qui
const MODEL_SPACING := 0.15                        # si stringe da sola se gli omini sono tanti
const ROW_MAX_WIDTH := 0.44
const CAM_POS := Vector3(-0.55, 0.075, 1.4)
const CAM_LOOK := Vector3(-0.55, 0.03, 1.05)

# buio e fari (energie delle luci; misure in metri di gioco)
const ROOM_DIM := 0.08            # le luci della stanza scendono all'8%
const AMBIENT_DIM := 0.12         # luce ambiente al 12%
const PLATE_R := 0.68             # raggio del piatto sotto ogni omino
const PLATE_H := 0.16             # altezza del piatto (l'omino ci sta sopra)
const GUN_PLATE_R := 0.55         # piatto dell'arma
const GUN_PLATE_OFF := Vector3(0.0, 0.0, 1.15)   # piatto dell'arma: davanti all'omino scelto...
const GUN_LEN := 1.05             # lunghezza dell'arma in vetrina
const SPOT_HEIGHT := 5.6          # faro: quanto sta in alto sopra l'omino
const SPOT_FRONT := 1.6           # ...e quanto più verso la telecamera
const SPIN := 0.55                # giro lento del piatto scelto (rad/s), come il microonde
const KICK := 1.1                 # giro in più quando scegli (rad, circa 60°)

# il menu ricorda l'ultima scelta quando si torna indietro
static var last_index := 0
static var last_weapon := 0
static var last_stili := {}

var _plates: Array[Node3D] = []   # un piatto per omino (l'omino è figlio del piatto e gira con lui)
var _models: Array = []
var _kicks: Array[float] = []     # giro in più ancora da fare, per ogni piatto
var _rims: Array[StandardMaterial3D] = []
var _spot: SpotLight3D
var _beam: Node3D
var _beam_mat: ShaderMaterial
var _gun_plate: Node3D
var _gun_holder: Node3D
var _gun_kick := 0.0
var _gun_spot: SpotLight3D
var _gun_beam: Node3D
var _cam: Camera3D
var _menu: Menu
var _t := 0.0
var _first := true                # al primo fotogramma fari e piatto arma vanno subito al loro posto
var _dimmed: Array = []           # [luce, energia di prima] delle luci della stanza
var _env: Environment
var _env_ambient := 0.0
var _env_bg := Color.BLACK


func _ready() -> void:
	# omini e telecamera del menu si muovono a ogni fotogramma (_process), non nei passi della fisica
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dim_room()

	var n := Characters.LIST.size()
	var gap := minf(MODEL_SPACING, ROW_MAX_WIDTH / maxf(n - 1, 1))
	for i in n:
		var plate := _make_plate(PLATE_R, Characters.LIST[i]["accent"])
		plate.position = (MODELS_CENTER + Vector3((i - (n - 1) / 2.0) * gap, 0, 0)) * Config.S
		add_child(plate)
		_plates.append(plate)
		_kicks.append(0.0)
		var m := _make_model(i, String(last_stili.get(i, "")))
		_models.append(m)

	# un filo di luce per intravedere gli altri omini nel buio
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.55, 0.2, 1.3) * Config.S
	fill.omni_range = 14.0
	fill.light_energy = 0.22
	fill.light_color = Color(0.6, 0.7, 1.0)
	add_child(fill)

	# FARO sull'omino scelto (luce + cono di luce visibile)
	_spot = _make_spot(22.0, 15.0)
	_spot.shadow_enabled = true
	_beam_mat = _beam_material(Color(1, 1, 1, 0.16))
	_beam = _make_beam(PLATE_R * 1.25, _beam_mat)

	# piatto dell'ARMA scelta, con il suo faro
	_gun_plate = _make_plate(GUN_PLATE_R, Color(1.0, 0.85, 0.4))
	add_child(_gun_plate)
	_gun_holder = Node3D.new()
	_gun_holder.position.y = PLATE_H
	_gun_plate.get_node("Gira").add_child(_gun_holder)
	_gun_spot = _make_spot(14.0, 11.0)
	_gun_spot.light_color = Color(1.0, 0.95, 0.85)
	_gun_beam = _make_beam(GUN_PLATE_R * 1.2, _beam_material(Color(1.0, 0.92, 0.75, 0.12)))

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true

	_menu = Menu.new()
	_menu.index = last_index
	_menu.weapon = last_weapon
	_menu.stili = last_stili.duplicate()
	add_child(_menu)
	_menu.selected.connect(_on_selected)
	_menu.weapon_selected.connect(_on_weapon_selected)
	_menu.style_changed.connect(_on_style_changed)
	_menu.start_game.connect(_on_start)
	_menu.host_game.connect(func(i: int, w: int, st: String, n2: String, coop: bool) -> void:
		_remember(i, w)
		host_game.emit(i, w, st, n2, coop))
	_menu.join_game.connect(func(i: int, w: int, st: String, n2: String, ip: String) -> void:
		_remember(i, w)
		join_game.emit(i, w, st, n2, ip))
	_show_gun(last_weapon)
	_on_selected(last_index)
	_process(0.0)


func _exit_tree() -> void:
	_restore_room()


func _process(delta: float) -> void:
	_t += delta
	var sel := _menu.index
	for i in _models.size():
		var m: CharacterModel = _models[i]
		var p := _plates[i]
		var gira: Node3D = p.get_node("Gira")
		if i == sel:
			# piatto del microonde: gira piano, più il giro in più quando scegli
			var k := _kicks[i] * clampf(delta * 5.0, 0.0, 1.0)
			_kicks[i] -= k
			gira.rotation.y += delta * SPIN + k
			gira.position.y = sin(clampf(_kicks[i] / KICK, 0.0, 1.0) * PI) * 0.05   # saltino
			m.animate(delta, 3.0 + sin(_t) * 2.0, false, sin(_t * 0.7) * 0.3, true, false)
		else:
			_kicks[i] = 0.0
			gira.rotation.y = lerp_angle(gira.rotation.y, 0.0, clampf(delta * 4.0, 0.0, 1.0))
			gira.position.y = 0.0
			m.animate(delta, 0.0, false, 0.0, true, false)
		_rims[i].emission_energy_multiplier = lerpf(_rims[i].emission_energy_multiplier,
				2.2 if i == sel else 0.15, clampf(delta * 6.0, 0.0, 1.0))

	# il faro e il piatto dell'arma scivolano verso l'omino scelto
	var target := _plates[sel].global_position
	var side := -signf(target.x - MODELS_CENTER.x * Config.S)
	if side == 0.0:
		side = 1.0
	var gun_target := target + Vector3(side * _gap() * Config.S * 0.5, 0, 0) + GUN_PLATE_OFF
	var f := 1.0 if _first else clampf(delta * 7.0, 0.0, 1.0)
	_first = false
	_gun_plate.global_position = _gun_plate.global_position.lerp(gun_target, f)
	var spot_target := target + Vector3(0, SPOT_HEIGHT, SPOT_FRONT)
	_spot.global_position = _spot.global_position.lerp(spot_target, f)
	_aim(_spot, _beam, target + Vector3(0, PLATE_H, 0))
	var gspot_target := _gun_plate.global_position + Vector3(0, SPOT_HEIGHT * 0.8, SPOT_FRONT * 0.8)
	_gun_spot.global_position = _gun_spot.global_position.lerp(gspot_target, f)
	_aim(_gun_spot, _gun_beam, _gun_plate.global_position + Vector3(0, PLATE_H, 0))

	var gk := _gun_kick * clampf(delta * 5.0, 0.0, 1.0)
	_gun_kick -= gk
	var gg: Node3D = _gun_plate.get_node("Gira")
	gg.rotation.y += delta * SPIN * 1.3 + gk
	gg.position.y = sin(clampf(_gun_kick / KICK, 0.0, 1.0) * PI) * 0.05

	# il faro "respira" un poco, come una lampada vera
	_spot.light_energy = 22.0 + sin(_t * 2.3) * 0.8
	_cam.global_position = (CAM_POS + Vector3(sin(_t * 0.3) * 0.02, 0, 0)) * Config.S
	_cam.look_at(CAM_LOOK * Config.S)


func _gap() -> float:
	var n := Characters.LIST.size()
	return minf(MODEL_SPACING, ROW_MAX_WIDTH / maxf(n - 1, 1))


func _on_selected(i: int) -> void:
	var accent: Color = Characters.LIST[i]["accent"]
	_spot.light_color = Color.WHITE.lerp(accent, 0.3)
	_beam_mat.set_shader_parameter("col", Color(Color.WHITE.lerp(accent, 0.35), 0.16))
	_kicks[i] = KICK
	_gun_kick = KICK


func _make_model(i: int, stile: String) -> CharacterModel:
	var m := CharacterModel.new()
	var d: Dictionary = Characters.LIST[i].duplicate()
	d["gun"] = Weapons.LIST[_menu.weapon if _menu else last_weapon]["model"]   # tutti con l'arma scelta
	if stile != "":
		d["stile"] = stile
	m.setup(d)
	m.position.y = PLATE_H
	m.rotation.y = PI      # rivolti verso la telecamera
	_plates[i].get_node("Gira").add_child(m)
	return m


## Cambio di aspetto (BLENDER / MINECRAFT): il modello di quel personaggio si rifà al suo posto.
func _on_style_changed(i: int, stile: String) -> void:
	var old: CharacterModel = _models[i]
	var m := _make_model(i, stile)
	m.transform = old.transform
	_models[i] = m
	old.queue_free()
	_kicks[i] = KICK


func _on_weapon_selected(w: int) -> void:
	for m in _models:
		(m as CharacterModel).set_gun(String(Weapons.LIST[w]["model"]))
	_show_gun(w)
	_kicks[_menu.index] = KICK * 0.6
	_gun_kick = KICK


## Mette sul piatto dell'arma il modello grande dell'arma w, centrato e appoggiato sul piatto.
func _show_gun(w: int) -> void:
	for c in _gun_holder.get_children():
		c.queue_free()
	var g := GunModels.build(String(Weapons.LIST[w]["model"]))
	var box := _local_aabb(g)
	var longest := maxf(box.size.x, box.size.z)
	var s := GUN_LEN / longest if longest > 0.001 else 1.0
	g.scale = Vector3.ONE * s
	var c := box.get_center()
	g.position = Vector3(-c.x * s, (-box.position.y) * s + 0.02, -c.z * s)
	var tilt := Node3D.new()          # un po' girata di fianco: si vede meglio
	tilt.rotation.y = deg_to_rad(-35.0)
	tilt.add_child(g)
	_gun_holder.add_child(tilt)


## Ingombro di tutte le mesh di n, nelle coordinate di n (anche prima che sia nella scena).
static func _local_aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p != null:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# ---------------------------------------------------------------- buio, fari, piatti

## Abbassa tutte le luci della stanza e la luce ambiente (le rimette _restore_room quando il menu si chiude).
func _dim_room() -> void:
	for node in get_tree().root.find_children("*", "Light3D", true, false):
		var l: Light3D = node
		if is_ancestor_of(l):
			continue
		_dimmed.append([l, l.light_energy])
		l.light_energy *= ROOM_DIM
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var we: WorldEnvironment = node
		if we.environment:
			_env = we.environment
			_env_ambient = _env.ambient_light_energy
			_env_bg = _env.background_color
			_env.ambient_light_energy *= AMBIENT_DIM
			_env.background_color = Color(0.01, 0.01, 0.015)
			break


func _restore_room() -> void:
	for d in _dimmed:
		var l: Light3D = d[0]
		if is_instance_valid(l):
			l.light_energy = float(d[1])
	_dimmed.clear()
	if _env:
		_env.ambient_light_energy = _env_ambient
		_env.background_color = _env_bg
		_env = null


## Piatto girevole: base scura ferma con un anello luminoso del colore del personaggio,
## sopra il disco di vetro che gira (nodo "Gira", con delle righe per vedere che gira).
func _make_plate(r: float, accent: Color) -> Node3D:
	var root := Node3D.new()
	var base_m := StandardMaterial3D.new()
	base_m.albedo_color = Color(0.06, 0.06, 0.07)
	base_m.metallic = 0.6
	base_m.roughness = 0.35
	_mesh(root, _cyl_mesh(r * 1.08, r * 1.14, PLATE_H * 0.55), base_m, Vector3(0, PLATE_H * 0.275, 0))
	var rim := StandardMaterial3D.new()
	rim.albedo_color = accent.darkened(0.3)
	rim.emission_enabled = true
	rim.emission = accent
	rim.emission_energy_multiplier = 0.15
	var torus := TorusMesh.new()
	torus.inner_radius = r * 1.06
	torus.outer_radius = r * 1.16
	_mesh(root, torus, rim, Vector3(0, PLATE_H * 0.55, 0))
	if r == PLATE_R:
		_rims.append(rim)

	var gira := Node3D.new()
	gira.name = "Gira"
	root.add_child(gira)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.88, 0.95, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.3
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(gira, _cyl_mesh(r, r, PLATE_H * 0.45), glass, Vector3(0, PLATE_H * 0.775, 0))
	var rib := StandardMaterial3D.new()
	rib.albedo_color = Color(0.85, 0.9, 1.0, 0.55)
	rib.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rib.roughness = 0.2
	for k in 6:                       # righe in rilievo, come sul piatto del microonde
		var b := BoxMesh.new()
		b.size = Vector3(0.025, 0.012, r * 0.8)
		var mi := _mesh(gira, b, rib, Vector3(0, PLATE_H, 0))
		mi.rotation.y = k * PI / 3.0
		mi.position += Vector3(sin(k * PI / 3.0), 0, cos(k * PI / 3.0)) * r * 0.5
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.25
	ring.outer_radius = r * 0.3
	_mesh(gira, ring, rib, Vector3(0, PLATE_H, 0))
	return root


func _make_spot(energy: float, angle: float) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_energy = energy
	s.spot_range = 12.0
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.6
	s.spot_attenuation = 0.4
	add_child(s)
	return s


## Cono di luce visibile del faro (un cono trasparente che si somma alla scena).
func _make_beam(bottom_r: float, m: ShaderMaterial) -> Node3D:
	var beam := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = bottom_r
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Cono"
	beam.add_child(mi)
	add_child(beam)
	return beam


func _beam_material(c: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 0.15);
varying float h;
void vertex() { h = VERTEX.y + 0.5; }   // 0 = in basso (sul piatto), 1 = in alto (sul faro)
void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float along = smoothstep(0.0, 0.12, h) * (0.35 + 0.65 * h);
	ALBEDO = col.rgb;
	ALPHA = col.a * edge * along;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", c)
	return m


## Punta il faro (luce + cono) da dov'è verso il punto target.
func _aim(spot: SpotLight3D, beam: Node3D, target: Vector3) -> void:
	var from := spot.global_position
	var dir := target - from
	var length := dir.length()
	if length < 0.01:
		return
	var b := Basis.looking_at(dir, Vector3.UP)
	spot.global_basis = b
	beam.global_transform = Transform3D(b, from)
	var cono: MeshInstance3D = beam.get_node("Cono")
	cono.rotation = Vector3(PI / 2.0, 0, 0)       # l'asse del cilindro (Y) lungo la direzione del faro
	cono.position = Vector3(0, 0, -length / 2.0)
	cono.scale = Vector3(1, length, 1)


func _cyl_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 40
	return c


func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _on_start(index: int, w: int, stile: String) -> void:
	_remember(index, w)
	start_game.emit(index, w, stile)


func _remember(index: int, w: int) -> void:
	last_index = index
	last_weapon = w
	last_stili = _menu.stili.duplicate()


## Messaggio nel pannello multiplayer del menu (es. "non riesco a collegarmi").
func set_net_status(text: String) -> void:
	_menu.set_net_status(text)
