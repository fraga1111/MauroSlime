extends RefCounted
## EFFETTI DEI COLPI, uguali per il giocatore e per gli omini degli altri (actors/avatar.gd):
##   tracer  "proiettile" luminoso che vola dalla bocca dell'arma al punto colpito (es. evidenziatore fluo)
##   impact  segno sul muro: buco scuro, oppure macchia colorata (splat) se l'arma ne ha una
## Colori e voglia di tracer/splat stanno in data/weapons.gd ("tracer", "splat").

const MAX_MARKS := 80
const TRACER_SPEED := 160.0          # metri di gioco al secondo
static var _marks: Array[Node3D] = []


## Colpo luminoso da from a to (parent = dove metterlo, di solito Main).
static func tracer(parent: Node, from: Vector3, to: Vector3, c: Color) -> void:
	var dist := from.distance_to(to)
	if dist < 0.3:
		return
	var bolt := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.07
	cm.height = minf(1.4, dist)
	cm.radial_segments = 8
	cm.rings = 2
	bolt.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	bolt.material_override = m
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(bolt)
	var dir := (to - from) / dist
	# la capsula è lungo Y: la giro verso la direzione del colpo
	bolt.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), from)
	var glow := OmniLight3D.new()
	glow.light_color = c
	glow.light_energy = 1.2
	glow.omni_range = 3.0
	glow.shadow_enabled = false
	bolt.add_child(glow)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "global_position", to, dist / TRACER_SPEED)
	tw.tween_callback(bolt.queue_free)


## Segno del colpo su una superficie. splat = colore della macchia, oppure null per il buco scuro.
static func impact(parent: Node, pos: Vector3, normal: Vector3, splat: Variant = null) -> void:
	var mark := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	if splat is Color:
		var c: Color = splat
		var disc := CylinderMesh.new()
		var r := randf_range(0.1, 0.16)
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.012
		disc.radial_segments = 10
		mark.mesh = disc
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.4
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		sm.radial_segments = 6
		sm.rings = 3
		mark.mesh = sm
		m.albedo_color = Color(0.05, 0.05, 0.05)
		m.roughness = 1.0
	mark.material_override = m
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(mark)
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	mark.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, n)).rotated(n, randf() * TAU),
			pos + n * 0.008)
	_marks.append(mark)
	while _marks.size() > MAX_MARKS:
		var old: Node3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
