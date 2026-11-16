extends Node3D
## Omino alto circa 1,8 m in scala gioco (cioè 10 cm reali), con animazioni semplici:
## camminata, salto, accovacciamento, mira su/giù, rinculo e ricarica.
## Guarda verso -Z come il giocatore.
## Tipi: soldatino a blocchi (MAURO, ANTONINO, JESN) e persona vera (MATTEO, BROSKI) in due stili:
## "blender" (modelli/<look>.glb, o forme arrotondate con le foto di data/looks.gd) e "minecraft"
## (cubi e quadratini, data/looks_minecraft.gd). Lo stile lo sceglie il menu (chiave "stile").

const GunModels := preload("res://scripts/actors/gun_models.gd")
const Looks := preload("res://scripts/data/looks.gd")
const LooksMinecraft := preload("res://scripts/data/looks_minecraft.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var data: Dictionary = {}
var muzzle: Node3D

var _upper: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arms: Node3D
var _gun: Node3D
var _phase := 0.0
var _kick := 0.0
var _crouch := 0.0
var _gun_base := Vector3(0.12, -0.1, -0.4)
var _fade := 0.0
var _meshes: Array[MeshInstance3D] = []


func setup(d: Dictionary) -> void:
	data = d
	var sc: float = d.get("scale", 1.0)
	scale = Vector3.ONE * sc
	if d.has("look") and String(d.get("stile", "")) == "minecraft" and LooksMinecraft.LOOKS.has(d["look"]):
		_build_cubes(LooksMinecraft.LOOKS[d["look"]])
	elif d.has("look"):
		var glb := "res://modelli/%s.glb" % d["look"]
		if ResourceLoader.exists(glb):
			_load_model(glb)
		else:
			_build_person(Looks.LOOKS[d["look"]])
	else:
		_build_soldier(d)
	set_gun(String(d.get("gun", Weapons.LIST[0]["model"])))


## Mette in mano all'omino il modello d'arma kind (actors/gun_models.gd), togliendo quello di prima.
func set_gun(kind: String) -> void:
	if _gun:
		_arms.remove_child(_gun)
		_gun.queue_free()
	_gun = GunModels.build(kind)
	_gun.position = _gun_base
	_arms.add_child(_gun)
	muzzle = _gun.get_node("Muzzle")
	_meshes.clear()                      # set_fade deve ritrovare anche le mesh della nuova arma
	if _fade > 0.0:
		var a := _fade
		_fade = -1.0
		set_fade(a)


## Soldatino a blocchi grandi (MAURO, ANTONINO, JESN): colori da data/characters.gd.
func _build_soldier(d: Dictionary) -> void:
	var skin := _mat(d.get("skin", Color(0.94, 0.76, 0.6)), 0.7)
	var uniform := _mat(d.get("uniform", Color(0.3, 0.4, 0.25)), 0.9)
	var uniform2 := _mat(d.get("uniform2", Color(0.2, 0.3, 0.15)), 0.9)
	var vest := _mat(d.get("vest", Color(0.4, 0.35, 0.25)), 0.8)
	var hat := _mat(d.get("hat_color", Color(0.3, 0.35, 0.2)), 0.6)
	var accent := _mat(d.get("accent", Color(0.3, 0.9, 0.3)), 0.5)
	var boots := _mat(Color(0.1, 0.09, 0.08), 0.6)
	var black := _mat(Color(0.03, 0.03, 0.03), 0.4)

	# gambe (perno all'anca)
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(s * 0.12, 0.85, 0)
		add_child(leg)
		_box(leg, Vector3(0.19, 0.72, 0.22), Vector3(0, -0.38, 0), uniform2)
		_box(leg, Vector3(0.21, 0.16, 0.3), Vector3(0, -0.77, -0.04), boots)
		_box(leg, Vector3(0.2, 0.1, 0.05), Vector3(0, -0.42, -0.12), uniform)
		if s < 0.0:
			_leg_l = leg
		else:
			_leg_r = leg

	# busto
	_upper = Node3D.new()
	add_child(_upper)
	_box(_upper, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.16, 0), uniform)
	_box(_upper, Vector3(0.54, 0.38, 0.33), Vector3(0, 1.2, 0), vest)
	_box(_upper, Vector3(0.52, 0.06, 0.3), Vector3(0, 0.88, 0), boots)
	for x in [-0.15, 0.0, 0.15]:
		_box(_upper, Vector3(0.11, 0.12, 0.06), Vector3(x, 1.08, -0.19), vest)
	_box(_upper, Vector3(0.08, 0.04, 0.01), Vector3(-0.15, 1.3, -0.17), accent)
	# zaino
	_box(_upper, Vector3(0.36, 0.42, 0.14), Vector3(0, 1.18, 0.22), uniform2)

	# testa e copricapo
	_head = Node3D.new()
	_head.position = Vector3(0, 1.48, 0)
	_upper.add_child(_head)
	_box(_head, Vector3(0.28, 0.3, 0.28), Vector3(0, 0.15, 0), skin)
	_box(_head, Vector3(0.05, 0.045, 0.01), Vector3(-0.065, 0.17, -0.142), black)
	_box(_head, Vector3(0.05, 0.045, 0.01), Vector3(0.065, 0.17, -0.142), black)
	match String(d.get("hat", "helmet")):
		"bandana":
			_box(_head, Vector3(0.3, 0.08, 0.3), Vector3(0, 0.26, 0), hat)
			_box(_head, Vector3(0.04, 0.03, 0.18), Vector3(0.05, 0.25, 0.22), hat, Vector3(0.4, 0.3, 0))
			_box(_head, Vector3(0.04, 0.03, 0.15), Vector3(-0.03, 0.24, 0.2), hat, Vector3(0.6, -0.2, 0))
			_box(_head, Vector3(0.29, 0.11, 0.02), Vector3(0, 0.06, -0.14), black)
		"hardhat":
			_cyl(_head, 0.18, 0.13, Vector3(0, 0.33, 0), hat)
			_cyl(_head, 0.23, 0.025, Vector3(0, 0.27, -0.02), hat)
			_box(_head, Vector3(0.27, 0.1, 0.03), Vector3(0, 0.05, -0.135), _mat(Color(0.3, 0.2, 0.12), 0.9))
		_:
			_box(_head, Vector3(0.34, 0.13, 0.34), Vector3(0, 0.33, 0), hat)
			_box(_head, Vector3(0.36, 0.03, 0.38), Vector3(0, 0.27, -0.01), hat)
			_box(_head, Vector3(0.3, 0.05, 0.02), Vector3(0, 0.28, -0.19), accent)

	# braccia + arma: ruotano insieme con la mira
	_arms = Node3D.new()
	_arms.position = Vector3(0, 1.38, 0)
	_upper.add_child(_arms)
	_box(_arms, Vector3(0.16, 0.12, 0.16), Vector3(0.3, 0.0, 0.0), vest)
	_box(_arms, Vector3(0.16, 0.12, 0.16), Vector3(-0.3, 0.0, 0.0), vest)
	_box(_arms, Vector3(0.12, 0.12, 0.38), Vector3(0.22, -0.1, -0.17), uniform, Vector3(0, deg_to_rad(21), 0))
	_box(_arms, Vector3(0.12, 0.12, 0.68), Vector3(-0.1, -0.08, -0.3), uniform, Vector3(0, deg_to_rad(-29), 0))
	_box(_arms, Vector3(0.1, 0.1, 0.1), Vector3(0.14, -0.18, -0.33), skin)
	_box(_arms, Vector3(0.1, 0.1, 0.1), Vector3(0.07, -0.13, -0.62), skin)


## Persona vera fatta in BLENDER (modelli/<look>.glb, creato da tools/blender_persona.py e ritoccabile
## in blender/<look>.blend). Se il file c'è, si usa al posto di _build_person. I pezzi devono chiamarsi
## GambaSX, GambaDX, Busto, Testa, Braccia, con i perni dove li mette _build_person (anche, collo, spalle).
func _load_model(path: String) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	add_child(scene)
	_leg_l = scene.find_child("GambaSX", true, false) as Node3D
	_leg_r = scene.find_child("GambaDX", true, false) as Node3D
	_upper = scene.find_child("Busto", true, false) as Node3D
	_head = scene.find_child("Testa", true, false) as Node3D
	_arms = scene.find_child("Braccia", true, false) as Node3D
	assert(_leg_l and _leg_r and _upper and _head and _arms, "pezzi mancanti in " + path)


## Persona vera (aspetto in data/looks.gd): corpo a forme arrotondate; testa, busto e gambe "dipinti"
## con le foto (proiettate da davanti, dietro e di fianco). Stessa struttura di nodi del soldatino,
## quindi le animazioni sono le stesse.
func _build_person(lk: Dictionary) -> void:
	var who: String = lk["photos"]
	var rnd: float = lk.get("round", 2.4)
	var skin := _mat(lk["skin"], 0.6)
	var shirt := _mat(lk["shirt"], 0.9)

	# gambe (perno all'anca): pantaloni con la foto, scarpe arrotondate con suola e fascia colorata
	var leg_x: float = lk.get("leg_x", 0.12)
	var sc: Array = lk["shoe_colors"]
	var upper_m := _mat(sc[0], 0.7)
	var sole_m := _mat(sc[1], 0.8)
	var detail_m := _mat(sc[2], 0.75)
	var leg_mesh := _loft(lk["leg"], rnd)
	var so: Array = lk["sole"]
	var shoe := _loft(lk["shoe"], 2.6)
	var sole := _loft([[so[0], so[2] * 0.85, so[3] * 0.9, so[4]], [so[0] + 0.006, so[2], so[3], so[4]],
			[so[1], so[2], so[3], so[4]], [so[1] + 0.002, so[2] * 0.8, so[3] * 0.8, so[4]]], 2.6)
	var dy: float = so[1] + 0.006
	var stripe := _loft([[dy, so[2] * 0.95, so[3] * 0.95, so[4]], [dy + 0.014, so[2] * 0.9, so[3] * 0.9, so[4]]], 2.6, true)
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(s * leg_x, 0.85, 0)
		add_child(leg)
		_mesh(leg, leg_mesh, _photo_mat(who, "legs", leg_mesh, lk["pants"], s < 0.0))
		_mesh(leg, shoe, upper_m)
		_mesh(leg, sole, sole_m)
		_mesh(leg, stripe, detail_m)
		if s < 0.0:
			_leg_l = leg
		else:
			_leg_r = leg

	# busto con la foto della maglia
	_upper = Node3D.new()
	add_child(_upper)
	var torso := _loft(lk["torso"], rnd)
	_mesh(_upper, torso, _photo_mat(who, "torso", torso, lk["shirt"]))

	# testa con le foto (faccia, fianchi, nuca) + collo
	_head = Node3D.new()
	_head.position = Vector3(0, 1.48, 0)
	_upper.add_child(_head)
	var nk: Array = lk["neck"]
	_limb(_head, Vector3(0, nk[1], 0.01), Vector3(0, nk[2], 0.01), nk[0], skin)
	var head := _loft(lk["head"], 2.2)
	_mesh(_head, head, _photo_mat(who, "head", head, lk["hair"], false, 0.85))

	# braccia (stessa posa del soldatino): braccio nudo, manica, braccialetti, mani
	_arms = Node3D.new()
	_arms.position = Vector3(0, 1.38, 0)
	_upper.add_child(_arms)
	var w: float = lk.get("arm_r", 0.045)
	var sx := torso.get_aabb().end.x - w * 0.9
	var arms := [
		[Vector3(sx, -0.02, 0.0), Vector3(0.14, -0.17, -0.31), lk.get("sleeve_r", 0.45), lk.get("bracelets_r", [])],
		[Vector3(-sx, -0.02, 0.0), Vector3(0.07, -0.12, -0.58), lk.get("sleeve_l", 0.3), lk.get("bracelets_l", [])],
	]
	for a in arms:
		var from: Vector3 = a[0]
		var to: Vector3 = a[1]
		var cut: float = a[2]
		var dir := to - from
		_limb(_arms, from, to, w, skin)
		_limb(_arms, from - dir * 0.04, from + dir * cut, w * 1.3, shirt)
		var k := 0
		for c in a[3]:
			var at := 0.9 - k * 0.035
			_limb(_arms, from + dir * at, from + dir * (at + 0.02), w * 1.12, _mat(c, 0.35))
			k += 1
	for h in [Vector3(0.14, -0.18, -0.34), Vector3(0.07, -0.13, -0.62)]:
		var hand := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = w * 1.05
		sm.height = w * 2.6
		hand.mesh = sm
		hand.material_override = skin
		hand.position = h
		hand.rotation.x = 1.2
		_arms.add_child(hand)


## Persona vera in versione "MINECRAFT" (data/looks_minecraft.gd): solo cubi, faccia e maglia a quadratini.
## Stessa struttura di nodi del soldatino, quindi le animazioni sono le stesse.
func _build_cubes(lk: Dictionary) -> void:
	var pal := {}
	var shiny: String = lk.get("shiny", "")
	var colors: Dictionary = lk["pal"]
	for ch in colors:
		var m := _mat(colors[ch], 0.3 if shiny.contains(ch) else 0.85)
		if shiny.contains(ch):
			m.metallic = 0.5
		pal[ch] = m
	var depth: Dictionary = lk.get("depth", {})
	var skin: Material = pal["k"]

	# gambe: i blocchi di leg_boxes valgono per entrambe (x positiva = verso l'esterno)
	var leg_x: float = lk.get("leg_x", 0.12)
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(s * leg_x, 0.85, 0)
		add_child(leg)
		for b in lk["leg_boxes"]:
			var p: Vector3 = b[1]
			_box(leg, b[0], Vector3(p.x * s, p.y, p.z), pal[b[2]])
		if s < 0.0:
			_leg_l = leg
		else:
			_leg_r = leg

	# busto: maglia + orlo + disegni davanti e dietro
	_upper = Node3D.new()
	add_child(_upper)
	var t: Array = lk["torso"]
	var tsize: Vector3 = t[0]
	var ty: float = t[1]
	_box(_upper, tsize, Vector3(0, ty, 0), pal[t[2]])
	var hem: Array = lk["hem"]
	_box(_upper, hem[0], Vector3(0, hem[1], 0), pal[hem[2]])
	var px := Vector2(tsize.x / 10.0, tsize.y / 13.0)
	var top := ty + tsize.y / 2.0
	_pixels(_upper, lk.get("shirt_front", []), pal, depth, Vector3(0, top, -tsize.z / 2.0),
			Vector3.LEFT, Vector3.FORWARD, px)
	_pixels(_upper, lk.get("shirt_back", []), pal, depth, Vector3(0, top, tsize.z / 2.0),
			Vector3.RIGHT, Vector3.BACK, px)
	for b in lk.get("torso_boxes", []):
		_box(_upper, b[0], b[1], pal[b[2]])

	# testa: collo, cranio, orecchie, poi faccia/fianchi/nuca a quadratini e i blocchi extra
	_head = Node3D.new()
	_head.position = Vector3(0, 1.48, 0)
	_upper.add_child(_head)
	_box(_head, Vector3(0.12, 0.07, 0.12), Vector3(0, 0.025, 0), skin)
	_box(_head, Vector3(0.28, 0.28, 0.28), Vector3(0, 0.18, 0), skin)
	var ear: Material = pal.get("K", skin)
	for s in [-1.0, 1.0]:
		_box(_head, Vector3(0.03, 0.075, 0.056), Vector3(s * 0.15, 0.166, 0.014), ear)
	var hp := Vector2(0.028, 0.028)
	_pixels(_head, lk["face"], pal, depth, Vector3(0, 0.32, -0.14), Vector3.LEFT, Vector3.FORWARD, hp)
	_pixels(_head, lk["back"], pal, depth, Vector3(0, 0.32, 0.14), Vector3.RIGHT, Vector3.BACK, hp)
	_pixels(_head, lk["side"], pal, depth, Vector3(0.14, 0.32, 0), Vector3.BACK, Vector3.RIGHT, hp)
	_pixels(_head, lk["side"], pal, depth, Vector3(-0.14, 0.32, 0), Vector3.BACK, Vector3.LEFT, hp)
	for b in lk.get("head_boxes", []):
		var rot := Vector3(0, deg_to_rad(b[3]), 0) if b.size() > 3 else Vector3.ZERO
		_box(_head, b[0], b[1], pal[b[2]], rot)

	# braccia (stessa posa del soldatino): spalla, manica, avambraccio nudo, braccialetti, mano
	_arms = Node3D.new()
	_arms.position = Vector3(0, 1.38, 0)
	_upper.add_child(_arms)
	var w: float = lk.get("arm_w", 0.11)
	var sleeve: Material = pal[lk.get("sleeve", "s")]
	var sx := tsize.x / 2.0 + 0.035
	for s in [-1.0, 1.0]:
		_box(_arms, Vector3(0.15, 0.14, 0.16), Vector3(s * sx, -0.015, 0.0), sleeve)
	var arms := [
		[Vector3(sx - 0.01, -0.05, 0.0), Vector3(0.15, -0.16, -0.33), lk.get("sleeve_r", 0.45), lk.get("bracelets_r", [])],
		[Vector3(-sx + 0.01, -0.05, 0.0), Vector3(0.07, -0.11, -0.6), lk.get("sleeve_l", 0.3), lk.get("bracelets_l", [])],
	]
	for a in arms:
		var from: Vector3 = a[0]
		var to: Vector3 = a[1]
		var cut: float = a[2]
		_block_limb(_arms, from, to, w, skin, cut - 0.02, 0.97)
		_block_limb(_arms, from, to, w + 0.025, sleeve, 0.0, cut)
		var k := 0
		for ch in a[3]:
			var at := 0.86 - k * 0.045
			_block_limb(_arms, from, to, w + 0.018, pal[ch], at, at + 0.03)
			k += 1
	_box(_arms, Vector3(0.1, 0.1, 0.11), Vector3(0.14, -0.18, -0.34), skin)
	_box(_arms, Vector3(0.1, 0.1, 0.11), Vector3(0.07, -0.13, -0.62), skin)


## Da chiamare ogni frame. hspeed = velocità orizzontale, pitch = mira su/giù (radianti).
## prone = 0..1 quanto è sdraiato (il giocatore ruota tutto il modello a pancia in giù: qui si muovono
## solo gambe, braccia e testa, per strisciare guardando e mirando in avanti).
func animate(delta: float, hspeed: float, crouch: bool, pitch: float, on_floor: bool, reloading: bool,
		prone := 0.0) -> void:
	var k := clampf(hspeed / 6.0, 0.0, 1.5)
	if prone > 0.5:
		k = clampf(hspeed / 1.6, 0.0, 1.0)            # strisciando si va piano, ma le gambe si muovono
	if on_floor and hspeed > 0.3:
		_phase += delta * maxf(hspeed, 3.0 * prone) * 1.7
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(delta * 6.0, 0.0, 1.0))
	_crouch = move_toward(_crouch, 1.0 if crouch else 0.0, delta * 5.0)

	var swing := sin(_phase) * 0.7 * k * (1.0 - prone)
	var l := swing
	var r := -swing
	if not on_floor and prone < 0.5:
		l = 0.55
		r = -0.35
	l += _crouch * 1.2
	r += _crouch * 0.9
	var t := clampf(delta * 15.0, 0.0, 1.0)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, l, t)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, r, t)
	# strisciando: le gambe si aprono e chiudono a forbice sul pavimento
	var crawl := sin(_phase) * 0.35 * k * prone
	_leg_l.rotation.z = lerpf(_leg_l.rotation.z, -0.12 * prone + crawl, t)
	_leg_r.rotation.z = lerpf(_leg_r.rotation.z, 0.12 * prone + crawl, t)
	var hip := 0.85 - 0.4 * _crouch
	_leg_l.position.y = hip
	_leg_r.position.y = hip
	_upper.position.y = -0.4 * _crouch + absf(sin(_phase)) * 0.04 * k * (1.0 - prone)
	_upper.rotation.z = lerpf(_upper.rotation.z, -crawl * 0.3, t)

	var aim := clampf(pitch, -1.1, 1.2)
	if reloading:
		aim -= 0.6
	# sdraiato il corpo è ruotato di 90°: braccia e testa si alzano di altrettanto per guardare avanti
	aim = lerpf(aim, PI / 2 + clampf(pitch, -0.25, 0.6), prone)
	_arms.rotation.x = lerpf(_arms.rotation.x, aim, clampf(delta * 20.0, 0.0, 1.0))
	_arms.rotation.z = lerpf(_arms.rotation.z, 0.5 if reloading else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	var look := lerpf(clampf(pitch, -0.8, 0.8) * 0.6, 1.25 + clampf(pitch, -0.3, 0.5) * 0.4, prone)
	_head.rotation.x = lerpf(_head.rotation.x, look, t)

	_kick = lerpf(_kick, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_gun.position = _gun_base + Vector3(0, 0, _kick * 0.08)


func recoil() -> void:
	_kick = 1.0


## Rende l'omino trasparente (0 = normale, 1 = invisibile): lo usa il giocatore quando la telecamera
## gli finisce addosso (spalle al muro), così non copre la visuale.
func set_fade(amount: float) -> void:
	var a := snappedf(clampf(amount, 0.0, 1.0), 0.05)
	if is_equal_approx(a, _fade):
		return
	_fade = a
	if _meshes.is_empty():
		for n in find_children("*", "MeshInstance3D", true, false):
			_meshes.append(n as MeshInstance3D)
	for m in _meshes:
		m.transparency = a
	visible = a < 0.97


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


## Arto arrotondato (capsula) tra due punti, raggio r.
func _limb(parent: Node3D, from: Vector3, to: Vector3, r: float, m: Material) -> void:
	var dir := to - from
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = dir.length() + 2.0 * r
	cm.radial_segments = 20
	cm.rings = 6
	mi.mesh = cm
	mi.material_override = m
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())), from + dir * 0.5)
	parent.add_child(mi)


## Disegno a quadratini su una faccia di un blocco. rows = righe dall'alto; top = centro del bordo alto;
## right = direzione delle colonne; out = verso cui sporge. Pezzi uguali vicini diventano un blocco solo.
func _pixels(parent: Node3D, rows: Array, pal: Dictionary, depth: Dictionary, top: Vector3,
		right: Vector3, out: Vector3, px: Vector2) -> void:
	for r in rows.size():
		var row: String = rows[r]
		var n := row.length()
		var c := 0
		while c < n:
			var ch := row[c]
			var run := 1
			while c + run < n and row[c + run] == ch:
				run += 1
			if pal.has(ch):
				var d: float = depth.get(ch, 0.01)
				var mid := c + (run - 1) / 2.0 - (n - 1) / 2.0
				var pos := top + right * (mid * px.x) + Vector3.DOWN * ((r + 0.5) * px.y) + out * (d / 2.0 - 0.002)
				var size := right.abs() * (px.x * run) + Vector3(0, px.y, 0) + out.abs() * d
				_box(parent, size, pos, pal[ch])
			c += run


## Blocco allungato tra due punti (braccia della versione Minecraft): t0..t1 = tratto da coprire (0 = from, 1 = to).
func _block_limb(parent: Node3D, from: Vector3, to: Vector3, w: float, m: Material, t0: float, t1: float) -> void:
	var dir := to - from
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, w, dir.length() * (t1 - t0))
	mi.mesh = bm
	mi.material_override = m
	mi.transform = Transform3D(Basis.looking_at(dir.normalized()), from + dir * ((t0 + t1) / 2.0))
	parent.add_child(mi)


func _mesh(parent: Node3D, mesh: Mesh, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Forma "a vaso": anelli ovali [y, mezza larghezza, mezza profondità, spostamento z] dal basso in alto,
## chiusi sopra e sotto. n = squadratura della sezione (2 = ovale). open = senza tappi (fasce).
static func _loft(rings: Array, n := 2.4, open := false, seg := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for r in rings:
		for i in seg:
			var ang := TAU * i / seg
			var c := cos(ang)
			var s := sin(ang)
			st.add_vertex(Vector3(signf(c) * pow(absf(c), 2.0 / n) * r[1], r[0],
					signf(s) * pow(absf(s), 2.0 / n) * r[2] + r[3]))
	var nr := rings.size()
	for j in nr - 1:
		for i in seg:
			var i1 := (i + 1) % seg
			var p00 := j * seg + i
			var p01 := j * seg + i1
			var p10 := (j + 1) * seg + i
			var p11 := (j + 1) * seg + i1
			for v in [p00, p01, p11, p00, p11, p10]:
				st.add_index(v)
	if not open:
		var first: Array = rings[0]
		var last: Array = rings[nr - 1]
		st.add_vertex(Vector3(0, first[0], first[3]))
		st.add_vertex(Vector3(0, last[0], last[3]))
		var cb := nr * seg
		var ct := cb + 1
		for i in seg:
			var i1 := (i + 1) % seg
			for v in [cb, i1, i]:
				st.add_index(v)
			for v in [ct, (nr - 1) * seg + i, (nr - 1) * seg + i1]:
				st.add_index(v)
	st.generate_normals()
	return st.commit()


## Materiale "foto": proietta le foto della parte (davanti, dietro, fianchi) sulla forma, dentro il suo ingombro.
## top = colore della parte vista dall'alto (capelli, spalle). mirror = gamba sinistra (foto specchiata).
static var _shader: Shader
static var _tex_cache := {}

static func _photo_mat(who: String, part: String, mesh: Mesh, top: Color, mirror := false,
		front_end := 0.75) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PHOTO_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	for view in ["front", "back", "side"]:
		m.set_shader_parameter(view, _photo_tex("res://textures/persone/%s_%s_%s.png" % [who, part, view]))
	var bb := mesh.get_aabb()
	m.set_shader_parameter("bmin", bb.position)
	m.set_shader_parameter("bmax", bb.end)
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("mirror", mirror)
	m.set_shader_parameter("front_end", front_end)
	return m


static func _photo_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		var img := (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex_cache[path] = ImageTexture.create_from_image(img)
	return _tex_cache[path]


const PHOTO_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D front : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D back : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D side : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 bmin;
uniform vec3 bmax;
uniform vec4 top_color : source_color;
uniform bool mirror = false;
uniform float front_end = 0.75;
uniform float sharp_top = 0.75;
varying vec3 p;
varying vec3 nrm;

void vertex() {
	p = VERTEX;
	nrm = NORMAL;
}

void fragment() {
	vec3 s = bmax - bmin;
	float v = clamp((bmax.y - p.y) / s.y, 0.0, 1.0);
	float uf = (bmax.x - p.x) / s.x;
	float ub = (p.x - bmin.x) / s.x;
	if (mirror) { uf = 1.0 - uf; ub = 1.0 - ub; }
	vec4 cf = texture(front, vec2(uf, v));
	vec4 cb = texture(back, vec2(ub, v));
	vec4 cs = texture(side, vec2((bmax.z - p.z) / s.z, v));
	vec3 n = normalize(nrm);
	// giro intorno al corpo: 0 = davanti, 1 = di fianco, 2 = dietro. Ogni foto copre solo il suo spicchio,
	// così il profilo (naso, occhi) non si sovrappone alla faccia vista da davanti.
	float ang = atan(abs(n.x), -n.z) / (PI * 0.5);
	// peso di ogni foto: spicchio di angolo x sagoma della persona (alfa della texture)
	float wf = (1.0 - smoothstep(front_end, front_end + 0.3, ang)) * cf.a;
	float wb = smoothstep(2.0 - front_end - 0.3, 2.0 - front_end, ang) * cb.a;
	float ws = (1.0 - smoothstep(0.25, 0.55, abs(ang - 1.0))) * cs.a * 0.999;
	float wsum = wf + wb + ws;
	vec3 c = (cf.rgb * wf + cb.rgb * wb + cs.rgb * ws) / max(wsum, 1e-4);
	c = mix(top_color.rgb, c, smoothstep(0.0, 0.25, wsum));
	// sopra (capelli, spalle) sfuma verso il colore top
	float wt = smoothstep(sharp_top, 1.0, n.y);
	ALBEDO = mix(c, top_color.rgb, wt * 0.7);
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
"""
