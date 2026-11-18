extends RefCounted
## KIT DI COSTRUZIONE: forme semplici e materiali per creare il mondo da codice.
##
## Regole (valgono per tutte le funzioni qui sotto):
##   - le misure sono in METRI REALI: vengono moltiplicate per S automaticamente;
##   - "pos" = centro della BASE dell'oggetto (dove appoggia), "center" = centro del volume;
##   - "look" può essere un Color oppure un Material;
##   - collide = true crea anche la collisione (si può camminarci sopra / ripararsi).
##
## world/room.gd estende questo file, quindi lì si scrive direttamente box(...), cyl(...).

const Config := preload("res://scripts/config.gd")
const S := Config.S

var root: Node3D                       # dove vengono aggiunti gli oggetti
var rng := RandomNumberGenerator.new()
var _mats := {}
var _lotti := {}                       # pezzi da unire: "root|zona|materiale" -> [root, materiale, SurfaceTool]
var _corpi := {}                       # root -> StaticBody3D con tutte le collisioni
## Zona della mappa (es. "ufficio", "corridoio"). Pezzi di zone diverse restano mesh separate,
## così la scheda video salta quelle fuori dall'inquadratura. Cambiarla all'inizio di ogni stanza nuova.
var zona := ""


# ---------------------------------------------------------------- scatole

## Scatola. pos = centro della base. rot_y in gradi.
func box(size: Vector3, pos: Vector3, look, collide := true, rot_y := 0.0) -> void:
	var center := pos + Vector3(0, size.y * 0.5, 0)
	box_t(size, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), center), look, collide)


## Scatola con trasformazione libera (origine = centro della scatola).
func box_t(size: Vector3, t: Transform3D, look, collide := true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size * S
	var shape: Shape3D = null
	if collide:
		var bs := BoxShape3D.new()
		bs.size = size * S
		shape = bs
	_add(mesh, shape, t, look)


## Scatola in coordinate LOCALI di un oggetto "o" (vedi xf()). local_bottom = centro della base.
func lbox(o: Transform3D, size: Vector3, local_bottom: Vector3, look, collide := true, local_yaw := 0.0) -> void:
	var b := o.basis * Basis(Vector3.UP, deg_to_rad(local_yaw))
	box_t(size, Transform3D(b, o * (local_bottom + Vector3(0, size.y / 2, 0))), look, collide)


## Sistema di riferimento di un oggetto: origine (metri reali) e rotazione in gradi.
## Serve per costruire mobili ruotati con lbox/lcyl/lquad.
func xf(origin: Vector3, yaw_deg := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), origin)


# ---------------------------------------------------------------- cilindri, sfere, anelli

## Cilindro in piedi. pos = centro della base.
func cyl(r: float, h: float, pos: Vector3, look, collide := true) -> void:
	cyl_t(r, h, Transform3D(Basis(), pos + Vector3(0, h / 2, 0)), look, collide)


func lcyl(o: Transform3D, r: float, h: float, local_bottom: Vector3, look, collide := true) -> void:
	cyl_t(r, h, Transform3D(o.basis, o * (local_bottom + Vector3(0, h / 2, 0))), look, collide)


## Cilindro con trasformazione libera (origine = centro). Per sdraiarlo ruotare la Basis.
func cyl_t(r: float, h: float, t: Transform3D, look, collide := true) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r * S
	mesh.bottom_radius = r * S
	mesh.height = h * S
	var shape: Shape3D = null
	if collide:
		var cs := CylinderShape3D.new()
		cs.radius = r * S
		cs.height = h * S
		shape = cs
	_add(mesh, shape, t, look)


## Sfera. center = centro. stretch_y allunga verticalmente (solo grafica).
func sphere(r: float, center: Vector3, look, collide := true, stretch_y := 1.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r * S
	mesh.height = r * 2.0 * S * stretch_y
	var shape: Shape3D = null
	if collide:
		var ss := SphereShape3D.new()
		ss.radius = r * S
		shape = ss
	_add(mesh, shape, Transform3D(Basis(), center), look)


## Anello (toro), solo grafica. Di default è sdraiato; ruotare la Basis per metterlo in piedi.
func torus(inner: float, outer: float, t: Transform3D, look) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner * S
	mesh.outer_radius = outer * S
	_add(mesh, null, t, look)


# ---------------------------------------------------------------- piani, collisioni, luci

## Piano verticale rivolto verso +Z (ruotato di rot_y gradi). Solo grafica (quadri, schermi, vetri).
func quad(size: Vector2, center: Vector3, look, rot_y := 0.0) -> void:
	quad_t(size, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), center), look)


func lquad(o: Transform3D, size: Vector2, local_center: Vector3, look) -> void:
	quad_t(size, Transform3D(o.basis, o * local_center), look)


func quad_t(size: Vector2, t: Transform3D, look) -> void:
	var q := QuadMesh.new()
	q.size = size * S
	_add(q, null, t, look)


## Collisione invisibile (pos = centro della base). Utile per oggetti fatti di tanti pezzi solo grafici.
func collider(size: Vector3, pos: Vector3) -> void:
	var bs := BoxShape3D.new()
	bs.size = size * S
	var cs := CollisionShape3D.new()
	cs.shape = bs
	cs.position = (pos + Vector3(0, size.y * 0.5, 0)) * S
	_body().add_child(cs)


## Luce puntiforme. range_m è in metri DI GIOCO.
func omni(pos: Vector3, range_m: float, energy: float, c: Color, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos * S
	l.omni_range = range_m
	l.omni_attenuation = 0.5
	l.light_energy = energy
	l.light_color = c
	l.shadow_enabled = shadows
	root.add_child(l)
	return l


## I pezzi NON diventano nodi separati: la grafica finisce in un "lotto" per materiale (una mesh unica,
## un solo disegno per la scheda video) e le collisioni in un unico StaticBody3D per root.
## I lotti diventano mesh vere con finish(), da chiamare alla fine della costruzione.
func _add(mesh: Mesh, shape: Shape3D, t: Transform3D, look) -> void:
	var xform := Transform3D(t.basis, t.origin * S)
	var m := _m(look)
	var key := "%d|%s|%d" % [root.get_instance_id(), zona, m.get_instance_id()]
	if not _lotti.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lotti[key] = [root, m, st]
	var st: SurfaceTool = _lotti[key][2]
	st.append_from(mesh, 0, xform)
	if shape:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = xform
		_body().add_child(cs)


## Corpo fisso unico (collisioni del mondo) del root attuale.
func _body() -> StaticBody3D:
	var id := root.get_instance_id()
	if not _corpi.has(id):
		var body := StaticBody3D.new()
		body.name = "Collisioni"
		body.collision_layer = Config.LAYER_WORLD
		root.add_child(body)
		_corpi[id] = body
	return _corpi[id]


## Trasforma i lotti in mesh (una per materiale e per zona). Va chiamata UNA volta, alla fine.
func finish() -> void:
	for key in _lotti:
		var l: Array = _lotti[key]
		var st: SurfaceTool = l[2]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = l[1]
		(l[0] as Node3D).add_child(mi)
	_lotti.clear()


# ---------------------------------------------------------------- materiali (con cache)

func _m(look) -> Material:
	if look is Material:
		return look
	return mat(look)


## Materiale opaco. rough 0 = lucido, 1 = opaco. metal 0..1.
func mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


## Materiale che emette luce (plafoniere, LED, vetri luminosi).
func emis(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "e%s|%s" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## Materiale trasparente: l'alfa del colore decide quanto si vede attraverso.
func glass(c: Color) -> StandardMaterial3D:
	var key := "g%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	_mats[key] = m
	return m


## Materiale con una texture che si ripete in coordinate mondo (pavimenti, muri).
## tile_m = quanti metri reali copre una ripetizione della texture.
func tiled(tex: Texture2D, tile_m: float, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / (tile_m * S)
	m.roughness = rough
	return m


## Materiale "acceso" che mostra una texture (schermi, vista dalla finestra, tende).
func lit(tex: Texture2D, energy := 1.3, base := Color.BLACK) -> StandardMaterial3D:
	var key := "l%d|%s|%s" % [tex.get_instance_id(), energy, base.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color.BLACK
	m.emission_texture = tex
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m
