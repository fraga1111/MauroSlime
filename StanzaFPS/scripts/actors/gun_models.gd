extends RefCounted
## Modelli delle armi (gli stessi per la prima e la terza persona).
## Tutte hanno il mirino red dot alla stessa altezza, così la mira funziona uguale.
## Ogni arma ha un nodo figlio "Muzzle" sulla bocca della canna.
## Armi del gioco (data/weapons.gd): "evidenziatore", "spillatrice", "telefono", "pinza".
## Sono oggetti veri dell'ufficio: niente mirino. Il mirino red dot ce l'hanno solo i vecchi
## "rifle" / "smg" / "lmg" (non usati).
## Misure in metri di gioco: l'omino è alto 1,8, l'evidenziatore è lungo 0,6 (portato come un fucile).

static func build(kind: String) -> Node3D:
	var g := Node3D.new()
	var metal := _mat(Color(0.13, 0.13, 0.14), 0.35, 0.7)
	var muzzle_z := -0.68
	var muzzle_y := 0.01
	var red_dot := true
	var size := 1.0          # grandezza in mano (2 = il doppio)
	var back_z := 0.0        # z del fondo dell'arma: ingrandendo resta fermo lì
	match kind:
		"evidenziatore":
			# evidenziatore giallo fluo (foto): corpo ovale, tappo arrotondato davanti con anello a
			# zigrinatura, tappino in fondo, scritta "tratto VIDEO" sui fianchi
			var fluo := _mat(Color(0.86, 1.0, 0.1), 0.45)
			fluo.emission_enabled = true
			fluo.emission = Color(0.55, 0.7, 0.0)
			fluo.emission_energy_multiplier = 0.25
			var fluo2 := _mat(Color(0.8, 0.95, 0.08), 0.35)
			fluo2.emission_enabled = true
			fluo2.emission = Color(0.5, 0.65, 0.0)
			fluo2.emission_energy_multiplier = 0.2
			_oval(g, 0.05, 0.32, Vector3(0, -0.01, 0.04), fluo, 1.0, 1.25)          # corpo
			_oval(g, 0.043, 0.03, Vector3(0, -0.01, 0.215), fluo2, 1.0, 1.2)        # tappino in fondo
			_box(g, Vector3(0.05, 0.07, 0.03), Vector3(0, -0.01, 0.24), fluo2)
			_oval(g, 0.053, 0.21, Vector3(0, -0.01, -0.225), fluo2, 1.0, 1.25)      # tappo
			_oval(g, 0.058, 0.025, Vector3(0, -0.01, -0.12), fluo2, 1.0, 1.22)      # anello del tappo
			for i in 3:
				_oval(g, 0.06, 0.004, Vector3(0, -0.01, -0.112 - i * 0.008), fluo, 1.0, 1.2)
			var tip := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.053
			sm.height = 0.106
			tip.mesh = sm
			tip.material_override = fluo2
			tip.scale = Vector3(1.0, 1.25, 0.75)
			tip.position = Vector3(0, -0.01, -0.33)
			g.add_child(tip)
			for side in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = "tratto  VIDEO"
				l.font_size = 30
				l.outline_size = 0
				l.pixel_size = 0.001
				l.modulate = Color(0.02, 0.02, 0.02)
				l.double_sided = false
				l.position = Vector3(side * 0.0515, -0.012, 0.05)
				l.rotation.y = side * PI / 2
				g.add_child(l)
			muzzle_z = -0.38
			muzzle_y = -0.01
			red_dot = false
		"spillatrice":
			# spillatrice da scrivania: base nera, braccio superiore incernierato dietro, testa cromata
			var black := _mat(Color(0.07, 0.07, 0.08), 0.3, 0.2)
			var chrome := _mat(Color(0.86, 0.87, 0.9), 0.15, 0.6)
			var rubber := _mat(Color(0.02, 0.02, 0.02), 0.9)
			_box(g, Vector3(0.09, 0.025, 0.5), Vector3(0, -0.085, -0.03), black)        # base
			_box(g, Vector3(0.094, 0.008, 0.48), Vector3(0, -0.1, -0.03), rubber)      # piedino
			_box(g, Vector3(0.055, 0.006, 0.07), Vector3(0, -0.07, -0.24), chrome)      # incudine
			_box(g, Vector3(0.062, 0.04, 0.42), Vector3(0, -0.04, -0.04), chrome)       # caricatore
			_box(g, Vector3(0.082, 0.045, 0.44), Vector3(0, 0.022, -0.03), black, -1.5) # coperchio
			_box(g, Vector3(0.082, 0.03, 0.06), Vector3(0, 0.005, -0.255), black, 30.0) # muso inclinato
			_box(g, Vector3(0.068, 0.07, 0.035), Vector3(0, -0.04, -0.255), chrome)     # testa
			_box(g, Vector3(0.075, 0.07, 0.06), Vector3(0, -0.04, 0.19), black)         # cerniera
			_cyl(g, 0.022, 0.1, Vector3(0, -0.035, 0.205), chrome, true)
			_box(g, Vector3(0.084, 0.006, 0.2), Vector3(0, 0.046, 0.0), chrome)         # striscia sul coperchio
			muzzle_z = -0.28
			muzzle_y = -0.055
			red_dot = false
			size = 2.0                                  # il doppio di una spillatrice vera in scala
			back_z = 0.22
		"telefono":
			# cordless nero (foto): tastiera verso l'alto, l'auricolare davanti; lungo 0,5
			var body := _mat(Color(0.05, 0.05, 0.06), 0.35, 0.1)
			var key := _mat(Color(0.03, 0.03, 0.035), 0.25, 0.1)
			var lcd := _mat(Color(0.6, 0.66, 0.58), 0.6)
			lcd.emission_enabled = true
			lcd.emission = Color(0.45, 0.5, 0.42)
			lcd.emission_energy_multiplier = 0.25
			_box(g, Vector3(0.13, 0.05, 0.4), Vector3(0, 0, -0.05), body)
			for z in [-0.25, 0.15]:                                                  # estremità arrotondate
				var end := MeshInstance3D.new()
				var em := CylinderMesh.new()
				em.top_radius = 0.065
				em.bottom_radius = 0.065
				em.height = 0.05
				end.mesh = em
				end.material_override = body
				end.position = Vector3(0, 0, z)
				g.add_child(end)
			_box(g, Vector3(0.12, 0.012, 0.14), Vector3(0, -0.028, 0.08), body)         # dorso più spesso
			var ear := MeshInstance3D.new()                                           # auricolare
			var earm := CylinderMesh.new()
			earm.top_radius = 0.028
			earm.bottom_radius = 0.028
			earm.height = 0.006
			ear.mesh = earm
			ear.material_override = key
			ear.position = Vector3(0, 0.026, -0.235)
			g.add_child(ear)
			_box(g, Vector3(0.088, 0.004, 0.06), Vector3(0, 0.026, -0.155), lcd)        # display
			_label(g, "Gigaset", Vector3(0, 0.0262, -0.105), 0.0005, Color(0.85, 0.85, 0.85))
			for sx in [-0.024, 0.024]:                                                # tasti sotto il display
				_box(g, Vector3(0.04, 0.008, 0.012), Vector3(sx, 0.027, -0.083), key)
			_box(g, Vector3(0.03, 0.012, 0.028), Vector3(-0.042, 0.028, -0.052), key)  # verde, navigazione, rosso
			_box(g, Vector3(0.034, 0.014, 0.034), Vector3(0, 0.029, -0.055), key)
			_box(g, Vector3(0.03, 0.012, 0.028), Vector3(0.042, 0.028, -0.052), key)
			var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
			for r in 4:
				for c in 3:
					var p := Vector3((c - 1) * 0.036, 0.028, -0.012 + r * 0.03)
					_box(g, Vector3(0.028, 0.01, 0.02), p, key)
					_label(g, keys[r * 3 + c], p + Vector3(0, 0.0055, 0), 0.0004, Color(0.95, 0.95, 0.95))
			_box(g, Vector3(0.024, 0.004, 0.003), Vector3(0, 0.026, 0.135), key)       # microfono
			muzzle_z = -0.32
			muzzle_y = 0.0
			red_dot = false
			size = 2.0                                  # il doppio di un cordless vero in scala
			back_z = 0.18
		"pinza":
			# spillatrice a pinza: muso davanti, due bracci curvi che si aprono a V verso il fondo.
			# Sopra: braccio cromato bombato con il caricatore (striscia di punti dentro) e il muso;
			# sotto: braccio nero con l'incudine davanti e l'impugnatura gommata in fondo.
			# Perno con rivetti, molla a spirale tra i bracci, spingipunti con la levetta dietro.
			var chrome := _mat(Color(0.9, 0.91, 0.94), 0.12, 0.75)
			var chrome2 := _mat(Color(0.7, 0.71, 0.75), 0.25, 0.7)      # parti in ombra / satinate
			var black := _mat(Color(0.08, 0.08, 0.09), 0.4, 0.25)        # lamiera verniciata
			var rubber := _mat(Color(0.03, 0.03, 0.035), 0.95)
			var staples := _mat(Color(0.78, 0.78, 0.8), 0.3, 0.8)
			var red := _mat(Color(0.75, 0.08, 0.1), 0.45)
			# braccio sotto (nero): punti del profilo (y, z), dal muso al fondo, curvo in giù alla fine
			var low := [Vector2(-0.085, -0.265), Vector2(-0.09, -0.15), Vector2(-0.1, 0.0),
					Vector2(-0.115, 0.12), Vector2(-0.14, 0.22), Vector2(-0.18, 0.3), Vector2(-0.215, 0.34)]
			_profile(g, low, 0.074, 0.034, black)
			_profile(g, low.slice(3), 0.082, 0.046, rubber)                   # impugnatura gommata
			for i in 5:                                                        # righine della gomma
				var t := 0.15 + i * 0.17
				var q := _along(low.slice(3), t)
				_box(g, Vector3(0.086, 0.05, 0.008), Vector3(0, q.x, q.y), rubber, q.z)
			_box(g, Vector3(0.06, 0.008, 0.07), Vector3(0, -0.064, -0.245), chrome)   # incudine
			_box(g, Vector3(0.02, 0.003, 0.04), Vector3(0, -0.0595, -0.245), chrome2) # scanalature dell'incudine
			for sx in [-1.0, 1.0]:                                              # fianchi che salgono al perno
				_box(g, Vector3(0.006, 0.075, 0.12), Vector3(sx * 0.039, -0.055, -0.17), black)
			# braccio sopra (cromato): bombato (due strati), curvo in su alla fine
			var up := [Vector2(0.02, -0.26), Vector2(0.026, -0.12), Vector2(0.036, 0.02),
					Vector2(0.05, 0.13), Vector2(0.075, 0.23), Vector2(0.11, 0.3), Vector2(0.14, 0.335)]
			_profile(g, up, 0.07, 0.03, chrome)
			var crown: Array = []
			for v in up:
				crown.append(v + Vector2(0.016, 0.0))
			_profile(g, crown.slice(0, 5), 0.044, 0.012, chrome)             # dorso bombato
			_profile(g, up.slice(4), 0.074, 0.034, rubber)                   # puntale gommato
			# muso: blocco cromato con il naso arrotondato e la lama che spinge il punto
			_box(g, Vector3(0.076, 0.085, 0.07), Vector3(0, -0.02, -0.235), chrome)
			_cyl(g, 0.038, 0.076, Vector3(0, 0.0, -0.268), chrome, true)
			_box(g, Vector3(0.05, 0.035, 0.012), Vector3(0, -0.05, -0.276), chrome2)   # lama / bocca
			_box(g, Vector3(0.04, 0.01, 0.004), Vector3(0, -0.06, -0.283), black)      # fessura dei punti
			# caricatore sotto il braccio sopra: canale cromato con la striscia di punti dentro
			_box(g, Vector3(0.056, 0.03, 0.3), Vector3(0, -0.012, -0.06), chrome2, 2.5)
			_box(g, Vector3(0.03, 0.012, 0.27), Vector3(0, -0.03, -0.075), staples, 2.5)
			for i in 9:                                                         # punti uno dietro l'altro
				_box(g, Vector3(0.032, 0.004, 0.003), Vector3(0, -0.037 + i * 0.0011, -0.19 + i * 0.026), chrome2, 2.5)
			# spingipunti con la levetta rossa dietro il caricatore
			_box(g, Vector3(0.03, 0.022, 0.03), Vector3(0, -0.02, 0.1), black, 4.0)
			_box(g, Vector3(0.016, 0.03, 0.016), Vector3(0, 0.0, 0.112), red)
			# perno: asse con i rivetti sui due lati
			_cyl(g, 0.012, 0.09, Vector3(0, -0.04, -0.19), chrome2, true)
			for sx in [-1.0, 1.0]:
				_cyl(g, 0.017, 0.006, Vector3(sx * 0.045, -0.04, -0.19), chrome, true)
			# molla a spirale tra i due bracci
			var y0 := _height_at(low, 0.15) + 0.02
			var y1 := _height_at(up, 0.15) - 0.015
			var turns := 7
			for i in turns:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.013
				tm.outer_radius = 0.019
				tm.rings = 12
				tm.ring_segments = 6
				ring.mesh = tm
				ring.material_override = chrome2
				ring.position = Vector3(0, lerpf(y0, y1, (i + 0.5) / turns), 0.15)
				ring.rotation.x = 0.12
				g.add_child(ring)
			muzzle_z = -0.29
			muzzle_y = -0.05
			red_dot = false
		"smg":
			var red := _mat(Color(0.75, 0.12, 0.12), 0.5)
			_box(g, Vector3(0.065, 0.1, 0.3), Vector3(0, 0, -0.02), metal)
			_box(g, Vector3(0.067, 0.025, 0.2), Vector3(0, -0.02, -0.05), red)
			_cyl(g, 0.022, 0.12, Vector3(0, 0.01, -0.23), metal)
			_box(g, Vector3(0.04, 0.26, 0.06), Vector3(0, -0.16, -0.08), metal, -5.0)
			_box(g, Vector3(0.045, 0.12, 0.05), Vector3(0, -0.1, 0.07), metal, 15.0)
			_box(g, Vector3(0.02, 0.06, 0.2), Vector3(0, -0.01, 0.22), metal)
			_box(g, Vector3(0.02, 0.1, 0.02), Vector3(0, -0.05, 0.32), metal)
			muzzle_z = -0.3
		"lmg":
			var olive := _mat(Color(0.3, 0.32, 0.2), 0.8)
			_box(g, Vector3(0.09, 0.12, 0.5), Vector3(0, 0, -0.05), metal)
			_cyl(g, 0.02, 0.36, Vector3(0, 0.01, -0.48), metal)
			_box(g, Vector3(0.06, 0.04, 0.26), Vector3(0, 0.045, -0.42), olive)
			_box(g, Vector3(0.11, 0.15, 0.13), Vector3(-0.01, -0.13, -0.1), olive)
			_box(g, Vector3(0.045, 0.13, 0.05), Vector3(0, -0.1, 0.1), metal, 15.0)
			_box(g, Vector3(0.07, 0.11, 0.24), Vector3(0, -0.02, 0.3), olive)
			_box(g, Vector3(0.012, 0.012, 0.22), Vector3(0.025, -0.03, -0.5), metal)
			_box(g, Vector3(0.012, 0.012, 0.22), Vector3(-0.025, -0.03, -0.5), metal)
			_box(g, Vector3(0.025, 0.05, 0.12), Vector3(0, 0.1, 0.02), metal)
			muzzle_z = -0.68
		_:
			var tan_m := _mat(Color(0.45, 0.38, 0.26), 0.8)
			_box(g, Vector3(0.07, 0.1, 0.4), Vector3(0, 0, -0.05), metal)
			_box(g, Vector3(0.075, 0.085, 0.25), Vector3(0, -0.005, -0.37), tan_m)
			_box(g, Vector3(0.045, 0.2, 0.08), Vector3(0, -0.13, -0.12), tan_m, -12.0)
			_box(g, Vector3(0.045, 0.13, 0.05), Vector3(0, -0.1, 0.07), metal, 15.0)
			_box(g, Vector3(0.055, 0.09, 0.2), Vector3(0, -0.02, 0.24), tan_m)
			_cyl(g, 0.014, 0.2, Vector3(0, 0.01, -0.58), metal)
			muzzle_z = -0.68

	if red_dot:
		_red_dot(g, metal)

	if size != 1.0:
		# ingrandita: il fondo resta dov'era (contro il petto) e l'arma cresce in avanti
		var big := Node3D.new()
		for c in g.get_children():
			g.remove_child(c)
			big.add_child(c)
		big.scale = Vector3.ONE * size
		big.position.z = back_z * (1.0 - size)
		g.add_child(big)
		muzzle_y *= size
		muzzle_z = back_z + (muzzle_z - back_z) * size

	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, muzzle_y, muzzle_z)
	g.add_child(muzzle)
	return g


## Barra che segue un profilo di punti (y, z) visto di fianco: pezzi dritti tra i punti e giunti tondi
## (cilindri lungo X), così le curve vengono morbide. w = larghezza (X), th = spessore.
static func _profile(g: Node3D, pts: Array, w: float, th: float, m: Material) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, th, d.length())
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(0, (a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
		mi.rotation.x = atan2(d.x, -d.y)
		g.add_child(mi)
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i]
		_cyl(g, th / 2.0, w, Vector3(0, p.x, p.y), m, true)


## Punto a frazione t (0..1) lungo un profilo: (y, z, inclinazione in gradi per _box).
static func _along(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 0.999) * n
	var i := int(f)
	var a: Vector2 = pts[i]
	var b: Vector2 = pts[i + 1]
	var p := a.lerp(b, f - i)
	var d := b - a
	return Vector3(p.x, p.y, rad_to_deg(atan2(d.x, -d.y)))


## Altezza (y) di un profilo alla profondità z.
static func _height_at(pts: Array, z: float) -> float:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if z >= a.y and z <= b.y:
			return lerpf(a.x, b.x, (z - a.y) / (b.y - a.y))
	var last: Vector2 = pts[pts.size() - 1]
	return last.x


## Slitta e mirino red dot (cornice aperta), solo per i vecchi fucili.
static func _red_dot(g: Node3D, metal: Material) -> void:
	_box(g, Vector3(0.03, 0.015, 0.3), Vector3(0, 0.058, -0.1), metal)
	_box(g, Vector3(0.05, 0.012, 0.05), Vector3(0, 0.072, -0.08), metal)
	_box(g, Vector3(0.006, 0.045, 0.04), Vector3(-0.025, 0.1, -0.08), metal)
	_box(g, Vector3(0.006, 0.045, 0.04), Vector3(0.025, 0.1, -0.08), metal)
	_box(g, Vector3(0.056, 0.006, 0.04), Vector3(0, 0.125, -0.08), metal)
	var dot := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.0025
	dm.height = 0.005
	dot.mesh = dm
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1, 0.1, 0.1)
	dot.material_override = dot_mat
	dot.position = Vector3(0, 0.105, -0.1)
	g.add_child(dot)


## Scritta appoggiata sulla faccia di sopra, leggibile da dietro (l'alto del testo verso -Z).
static func _label(g: Node3D, text: String, pos: Vector3, px: float, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 32
	l.outline_size = 0
	l.pixel_size = px
	l.modulate = c
	l.double_sided = false
	l.position = pos
	l.rotation.x = -PI / 2
	g.add_child(l)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = deg_to_rad(rot_x)
	parent.add_child(mi)


## Cilindro coricato lungo Z (along_x = true: lungo X, per cerniere e perni).
static func _cyl(parent: Node3D, r: float, length: float, pos: Vector3, m: Material, along_x := false) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	mi.mesh = cm
	mi.material_override = m
	if along_x:
		mi.rotation.z = PI / 2
	else:
		mi.rotation.x = PI / 2
	mi.position = pos
	parent.add_child(mi)


## Cilindro a sezione ovale lungo Z: largo r*sx, alto r*sy.
static func _oval(parent: Node3D, r: float, length: float, pos: Vector3, m: Material, sx: float, sy: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = m
	mi.rotation.x = PI / 2
	mi.scale = Vector3(sx, 1.0, sy)      # dopo la rotazione la z locale è la verticale
	mi.position = pos
	parent.add_child(mi)


static func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
