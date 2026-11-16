extends "res://scripts/world/kit.gd"
## L'UFFICIO (ricostruito dalle foto in ../ft e dalla planimetria). Qui c'è SOLO la disposizione:
## le funzioni box/cyl/sphere/... e i materiali sono in world/kit.gd, le texture in world/textures.gd.
##
## Misure in METRI REALI (vengono scalate da S). Orientamento come la planimetria vista dall'alto:
##   -Z = parete delle 3 finestre (in alto)      +Z = parete con la porta (in basso)
##   -X = parete sinistra (ovest)                +X = parete destra (est)
##   y = 0 è il pavimento.
##
## Indice delle sezioni (una funzione ciascuna, chiamate da build()):
##   _ceiling_and_lights  controsoffitto, plafoniere, luci
##   _floor_and_walls     pavimento, pareti laterali, battiscopa
##   _window_wall         parete finestre + pilastri + _window() per ogni finestra
##   _door_wall           parete porta, anta, corridoio, condizionatore, calendario
##   _island              isola di 4 scrivanie
##   _stations            monitor, tastiere, mouse, sedie (dati in STATIONS)
##   _desk_clutter        oggettini sulle scrivanie
##   _window_cabinets     mobiletti bassi sotto le finestre
##   _south_corner        mobiletto con zaini, rotoli, scatola
##   _coat_rack           attaccapanni con giubbotti
##   _dracena             pianta in vaso
##   _ramp                tavoletta-rampa per salire sull'isola (aggiunta per il gioco)

const Textures := preload("res://scripts/world/textures.gd")

# --- misure principali -------------------------------------------------------
const W := 3.0          # larghezza stanza (X)
const D := 4.47         # profondità stanza (Z)
const H := 2.75         # altezza controsoffitto
const T := 0.75         # altezza piano scrivanie
const WALL := 0.12      # spessore pareti

const ZN := -D / 2      # filo interno parete finestre
const ZS := D / 2       # filo interno parete porta
const ZG := -2.39       # piano dei vetri (le finestre sono rientrate nel muro)

const IX0 := -0.80      # isola centrale di 4 scrivanie: bordi X e Z
const IX1 := 0.85
const IZ0 := -1.79
const IZ1 := 0.79
const ICX := (IX0 + IX1) / 2
const ICZ := (IZ0 + IZ1) / 2

const DOOR_X0 := 0.30   # vano porta sulla parete +Z
const DOOR_X1 := 1.05

const RAMP_X := 0.1     # rampa per salire sull'isola: centro (X), larghezza, lunghezza a terra
const RAMP_W := 0.3     # (parte dal bordo IZ1 dell'isola e scende verso la porta)
const RAMP_RUN := 1.0

# --- punti di comparsa (metri reali) -----------------------------------------
const PLAYER_SPAWN := Vector3(-0.6, 0.02, 1.3)
# per ora non usati: i nemici sono in archivio_nemici/ (torneranno più avanti)
const ENEMY_SPAWNS := [
	Vector3(-1.15, 0.05, -1.6),
	Vector3(1.17, 0.05, -1.6),
	Vector3(-1.2, 0.05, 1.4),
	Vector3(1.2, 0.05, 0.6),
	Vector3(0.7, 0.05, 2.8),          # dal corridoio oltre la porta
	Vector3(0.45, 0.05, 1.6),
	Vector3(-0.4, T + 0.05, -0.45),   # sopra l'isola (y > 0.5 = solo dopo qualche ondata)
]

# scatole di graffette (game/munizioni.gd): punti liberi sul pavimento e uno sopra l'isola
const PICKUP_SPOTS := [
	Vector3(-1.15, 0.0, -1.6),
	Vector3(1.17, 0.0, -1.6),
	Vector3(-1.2, 0.0, 1.4),
	Vector3(1.2, 0.0, 0.6),
	Vector3(0.45, 0.0, 1.6),
	Vector3(-0.4, T, -0.45),
]

# --- le 4 postazioni sull'isola ----------------------------------------------
# side: -1 = chi siede sta a ovest, +1 = a est.  z: centro postazione.
# Coordinate locali di postazione: x = lungo l'isola, z = verso chi siede.
# monitors: [x locale, alzata, rotazione gradi, schermo ("desktop" | "code" | "sheet")]
const STATIONS := [
	{"side": -1, "z": -1.15, "chair": "exec", "chair_dist": 1.18,
		"monitors": [[0.29, 0.0, -8.0, "desktop"], [-0.29, 0.0, 8.0, "code"]],
		"keyboard": Vector3(0, 0, 0.6), "mouse": Vector3(0.3, 0, 0.6)},
	{"side": -1, "z": 0.15, "chair": "mesh", "chair_dist": 1.2,
		"monitors": [[0.0, 0.0, 0.0, "sheet"]],
		"keyboard": null, "mouse": null},
	{"side": 1, "z": -1.15, "chair": "mesh", "chair_dist": 1.2,
		"monitors": [[-0.27, 0.05, 6.0, "code"], [0.3, 0.0, -6.0, "desktop"]],
		"keyboard": Vector3(0, 0, 0.6), "mouse": Vector3(0.3, 0, 0.6)},
	{"side": 1, "z": 0.15, "chair": "mesh", "chair_dist": 1.2,
		"monitors": [[0.25, 0.0, 0.0, "desktop"]],
		"keyboard": Vector3(0.05, 0, 0.55), "mouse": Vector3(0.35, 0, 0.6)},
]

# --- colori ricorrenti -------------------------------------------------------
const C_WALL := Color(0.9, 0.9, 0.88)
const C_CONCRETE := Color(0.88, 0.88, 0.86)
const C_LIGHT_WOOD := Color(0.8, 0.68, 0.52)
const C_DESK := Color(0.62, 0.6, 0.57)
const C_FRAME := Color(0.22, 0.23, 0.24)
const C_PAPER := Color(0.97, 0.97, 0.96)
const PEN_COLORS := [
	Color(1.0, 0.9, 0.1), Color(1.0, 0.3, 0.6), Color(0.3, 0.9, 0.3), Color(1.0, 0.55, 0.1),
	Color(0.2, 0.5, 1.0), Color(0.6, 0.3, 0.9), Color(0.1, 0.9, 0.8), Color(0.9, 0.15, 0.15),
]

var _screens := {}


## nav_root: stanza e mobili (ciò su cui si cammina; un domani anche i nemici). other_root: soffitti e luci.
func build(nav_root: Node3D, other_root: Node3D) -> void:
	rng.seed = 2026
	_screens = {"desktop": Textures.screen_desktop(), "code": Textures.screen_code(), "sheet": Textures.screen_sheet()}
	root = other_root
	_ceiling_and_lights()
	root = nav_root
	_floor_and_walls()
	_window_wall()
	_door_wall()
	_island()
	_stations()
	_desk_clutter()
	_window_cabinets()
	_south_corner()
	_coat_rack()
	_dracena(Vector3(0.55, 0, 0.98))
	_ramp()


# ============================================================ STRUTTURA

func _ceiling_and_lights() -> void:
	box(Vector3(W + 0.4, 0.1, D + 0.4), Vector3(0, H, 0), mat(Color(0.95, 0.95, 0.94), 0.95))
	# griglia del controsoffitto 60x60
	var grid := mat(Color(0.78, 0.78, 0.78), 0.6)
	var x := -W / 2 + 0.3
	while x < W / 2:
		box(Vector3(0.025, 0.012, D), Vector3(x, H - 0.012, 0), grid, false)
		x += 0.6
	var z := ZN + 0.4
	while z < ZS:
		box(Vector3(W, 0.012, 0.025), Vector3(0, H - 0.012, z), grid, false)
		z += 0.6
	# plafoniere e rilevatore di fumo
	var panel := emis(Color(1, 0.98, 0.94), 2.5)
	box(Vector3(0.58, 0.015, 0.58), Vector3(0.0, H - 0.015, -1.0), panel, false)
	box(Vector3(0.58, 0.015, 0.58), Vector3(0.0, H - 0.015, 1.1), panel, false)
	cyl(0.05, 0.03, Vector3(-0.6, H - 0.03, 0.5), mat(Color(0.9, 0.88, 0.75), 0.5), false)
	# luci (range in metri di gioco)
	omni(Vector3(0.0, H - 0.2, -1.0), 85.0, 1.6, Color(1, 0.97, 0.93), true)
	omni(Vector3(0.0, H - 0.2, 1.1), 85.0, 1.4, Color(1, 0.97, 0.93))
	omni(Vector3(0.0, 1.8, -2.0), 60.0, 1.6, Color(0.8, 0.88, 1.0))     # luce dalle finestre
	omni(Vector3(0.68, 2.3, 2.9), 30.0, 1.4, Color(1, 0.9, 0.75))       # corridoio
	box(Vector3(1.4, 0.1, 1.2), Vector3(0.68, H, 2.9), mat(Color(0.95, 0.95, 0.94), 0.95))


func _floor_and_walls() -> void:
	box(Vector3(W + 0.4, 0.1, D + 0.4), Vector3(0, -0.1, 0), tiled(Textures.carpet(), 0.5, 1.0))
	var wall := mat(C_WALL, 0.95)
	box(Vector3(WALL, H, D + 0.5), Vector3(-W / 2 - WALL / 2, 0, -0.1), wall)
	box(Vector3(WALL, H, D + 0.5), Vector3(W / 2 + WALL / 2, 0, -0.1), wall)
	var bb := mat(Color(0.72, 0.6, 0.45), 0.7)
	box(Vector3(0.012, 0.07, D), Vector3(-W / 2 + 0.006, 0, 0), bb, false)
	box(Vector3(0.012, 0.07, D), Vector3(W / 2 - 0.006, 0, 0), bb, false)
	box(Vector3(DOOR_X0 + W / 2, 0.07, 0.012), Vector3((-W / 2 + DOOR_X0) / 2, 0, ZS - 0.006), bb, false)


func _window_wall() -> void:
	var concrete := mat(C_CONCRETE, 0.95)
	var reveal := ZN - ZG + 0.05      # profondità degli sguinci
	box(Vector3(W + 0.3, H, 0.1), Vector3(0, 0, ZG - 0.05), concrete)
	# tratti pieni tra le finestre [x inizio, x fine]
	for seg in [[-1.5, -1.42], [-0.67, -0.37], [0.38, 0.68], [1.42, 1.5]]:
		var a: float = seg[0]
		var b: float = seg[1]
		box(Vector3(b - a, H, reveal), Vector3((a + b) / 2, 0, (ZN + ZG) / 2), concrete)
	# due pilastri profondi (l'isola ci si appoggia)
	box(Vector3(0.16, H, IZ0 - ZG), Vector3(-0.50, 0, (IZ0 + ZG) / 2), concrete)
	box(Vector3(0.15, H, IZ0 - ZG), Vector3(0.503, 0, (IZ0 + ZG) / 2), concrete)
	# finestre: centro x, larghezza, vista, anta aperta, lunghezza tenda (0 = niente)
	_window(-1.045, 0.75, 1, true, 0.0)
	_window(0.005, 0.75, 2, false, 0.8)
	_window(1.045, 0.74, 3, false, 0.95)


func _window(xc: float, w: float, view_seed: int, open_sash: bool, blind_len: float) -> void:
	var y0 := 0.72     # davanzale
	var y1 := 2.55     # architrave
	var concrete := mat(C_CONCRETE, 0.95)
	var frame := mat(C_FRAME, 0.4, 0.5)
	var reveal := ZN - ZG + 0.05
	box(Vector3(w, y0, reveal), Vector3(xc, 0, (ZN + ZG) / 2), concrete)
	box(Vector3(w, H - y1, reveal), Vector3(xc, y1, (ZN + ZG) / 2), concrete)
	quad(Vector2(w, y1 - y0), Vector3(xc, (y0 + y1) / 2, ZG + 0.01), lit(Textures.window_view(view_seed), 1.6))
	var fz := ZG + 0.03
	box(Vector3(0.05, y1 - y0, 0.05), Vector3(xc - w / 2 + 0.025, y0, fz), frame, false)
	box(Vector3(0.05, y1 - y0, 0.05), Vector3(xc + w / 2 - 0.025, y0, fz), frame, false)
	box(Vector3(w, 0.05, 0.05), Vector3(xc, y0, fz), frame, false)
	box(Vector3(w, 0.05, 0.05), Vector3(xc, y1 - 0.05, fz), frame, false)
	box(Vector3(w, 0.05, 0.05), Vector3(xc, 1.62, fz), frame, false)
	if blind_len > 0.0:
		quad(Vector2(w - 0.1, blind_len), Vector3(xc, y1 - 0.05 - blind_len / 2, ZG + 0.07), lit(Textures.blind(), 0.9, Color(0.5, 0.5, 0.5)))
	if open_sash:
		# anta aperta verso l'interno, cerniera sul lato destro
		var a := deg_to_rad(70.0)
		var hinge := Vector3(xc + w / 2 - 0.05, 0.0, ZG + 0.05)
		var o := Transform3D(Basis(Vector3.UP, a), hinge + Vector3(-cos(a), 0, sin(a)) * 0.32)
		lbox(o, Vector3(0.64, 0.05, 0.05), Vector3(0, 0.85, 0), frame)
		lbox(o, Vector3(0.64, 0.05, 0.05), Vector3(0, 2.45, 0), frame)
		lbox(o, Vector3(0.05, 1.65, 0.05), Vector3(-0.3, 0.85, 0), frame)
		lbox(o, Vector3(0.05, 1.65, 0.05), Vector3(0.3, 0.85, 0), frame)
		lbox(o, Vector3(0.56, 1.55, 0.01), Vector3(0, 0.9, 0), glass(Color(0.75, 0.85, 0.95, 0.18)), false)
		lbox(o, Vector3(0.02, 0.14, 0.03), Vector3(-0.27, 1.55, 0.04), frame, false)


func _door_wall() -> void:
	var wall := mat(C_WALL, 0.95)
	var wood := mat(C_LIGHT_WOOD, 0.6)
	var zc := ZS + WALL / 2
	box(Vector3(DOOR_X0 + W / 2 + 0.12, H, WALL), Vector3((-W / 2 - 0.12 + DOOR_X0) / 2, 0, zc), wall)
	box(Vector3(W / 2 + 0.12 - DOOR_X1, H, WALL), Vector3((DOOR_X1 + W / 2 + 0.12) / 2, 0, zc), wall)
	box(Vector3(DOOR_X1 - DOOR_X0, H - 2.1, WALL), Vector3((DOOR_X0 + DOOR_X1) / 2, 2.1, zc), wall)
	# stipiti
	box(Vector3(0.06, 2.15, WALL + 0.04), Vector3(DOOR_X0 - 0.03, 0, zc), wood, false)
	box(Vector3(0.06, 2.15, WALL + 0.04), Vector3(DOOR_X1 + 0.03, 0, zc), wood, false)
	box(Vector3(DOOR_X1 - DOOR_X0 + 0.12, 0.06, WALL + 0.04), Vector3((DOOR_X0 + DOOR_X1) / 2, 2.1, zc), wood, false)

	# anta aperta verso l'interno, cerniera sul lato est
	var a := deg_to_rad(62.0)
	var leaf_w := DOOR_X1 - DOOR_X0
	var hinge := Vector3(DOOR_X1, 0, ZS - 0.03)
	var o := Transform3D(Basis(Vector3.UP, -a), hinge + Vector3(-cos(a), 0, -sin(a)) * (leaf_w / 2))
	lbox(o, Vector3(leaf_w, 2.07, 0.04), Vector3.ZERO, wood)
	var steel := mat(Color(0.8, 0.8, 0.82), 0.25, 0.9)
	lbox(o, Vector3(0.13, 0.02, 0.03), Vector3(-leaf_w / 2 + 0.12, 1.0, 0.05), steel, false)
	lbox(o, Vector3(0.13, 0.02, 0.03), Vector3(-leaf_w / 2 + 0.12, 1.0, -0.05), steel, false)

	# corridoio oltre la porta
	box(Vector3(1.4, 0.1, 1.3), Vector3(0.68, -0.098, 2.95), mat(Color(0.62, 0.56, 0.5), 0.35))
	box(Vector3(0.1, H, 1.3), Vector3(DOOR_X0 - 0.2, 0, 2.95), wall)
	box(Vector3(0.1, H, 1.3), Vector3(DOOR_X1 + 0.25, 0, 2.95), wall)
	box(Vector3(1.6, H, 0.1), Vector3(0.68, 0, 3.55), wall)
	box(Vector3(0.8, 2.05, 0.03), Vector3(0.68, 0, 3.49), wood, false)
	box(Vector3(0.55, 1.6, 0.01), Vector3(0.68, 0.3, 3.47), emis(Color(0.95, 0.92, 0.85), 0.8), false)

	# condizionatore sopra la porta
	box(Vector3(0.85, 0.28, 0.21), Vector3(0.68, 2.2, ZS - 0.105), mat(Color(0.96, 0.96, 0.96), 0.4))
	box(Vector3(0.75, 0.02, 0.01), Vector3(0.68, 2.25, ZS - 0.215), mat(Color(0.6, 0.6, 0.6)), false)
	box(Vector3(0.12, 0.05, 0.01), Vector3(0.98, 2.4, ZS - 0.215), mat(Color(0.85, 0.15, 0.15)), false)

	# calendario, lettore badge, presa
	box(Vector3(0.32, 0.5, 0.005), Vector3(0.0, 1.25, ZS - 0.003), mat(C_PAPER), false)
	box(Vector3(0.32, 0.08, 0.006), Vector3(0.0, 1.67, ZS - 0.004), mat(Color(0.8, 0.12, 0.12)), false)
	for i in 8:
		box(Vector3(0.12, 0.012, 0.006), Vector3(-0.07, 1.3 + i * 0.045, ZS - 0.004), mat(Color(0.2, 0.2, 0.2)), false)
	box(Vector3(0.08, 0.08, 0.02), Vector3(0.2, 1.1, ZS - 0.01), mat(Color(0.12, 0.12, 0.12)), false)
	box(Vector3(0.08, 0.06, 0.02), Vector3(DOOR_X1 + 0.3, 0.2, ZS - 0.01), mat(Color(0.12, 0.12, 0.12)), false)


# ============================================================ SCRIVANIE

func _island() -> void:
	var top := mat(C_DESK, 0.55)
	var leg := mat(Color(0.82, 0.82, 0.84), 0.35, 0.6)
	var hw := (IX1 - IX0) / 2
	var hl := (IZ1 - IZ0) / 2
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cx: float = ICX + sx * hw / 2
			var cz: float = ICZ + sz * hl / 2
			box(Vector3(hw - 0.006, 0.03, hl - 0.006), Vector3(cx, T - 0.03, cz), top)
			for lx in [-1.0, 1.0]:
				for lz in [-1.0, 1.0]:
					box(Vector3(0.05, T - 0.03, 0.05), Vector3(cx + lx * (hw / 2 - 0.05), 0, cz + lz * (hl / 2 - 0.05)), leg)
	box(Vector3(0.02, 0.37, IZ1 - IZ0 - 0.2), Vector3(ICX, 0.35, ICZ), mat(Color(0.55, 0.55, 0.55), 0.6))
	for z in [-1.15, 0.15]:
		cyl(0.04, 0.004, Vector3(ICX - 0.12, T, z), mat(Color(0.95, 0.95, 0.95), 0.4), false)
		cyl(0.03, 0.005, Vector3(ICX - 0.12, T, z), mat(Color(0.1, 0.1, 0.1)), false)


func _stations() -> void:
	for st in STATIONS:
		var side: int = st["side"]
		var o := xf(Vector3(ICX, T, st["z"]), 90.0 if side > 0 else -90.0)
		for m in st["monitors"]:
			_monitor(o, Vector3(m[0], m[1], 0.18), m[2], _screens[m[3]])
		if st["keyboard"] != null:
			_keyboard(o, st["keyboard"])
		if st["mouse"] != null:
			_mouse(o, st["mouse"])
		var p := o * Vector3(0, 0, st["chair_dist"])
		var chair_o := Transform3D(o.basis * Basis(Vector3.UP, PI), Vector3(p.x, 0, p.z))
		if st["chair"] == "exec":
			_exec_chair(chair_o)
		else:
			_mesh_chair(chair_o)
	# risma di carta verde sotto un monitor della postazione est-finestre
	box(Vector3(0.3, 0.05, 0.21), Vector3(ICX + 0.2, T, -0.88), mat(Color(0.35, 0.85, 0.2), 0.8), true, 90.0)


func _monitor(o: Transform3D, local_pos: Vector3, yaw: float, tex: Texture2D) -> void:
	var m := o * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), local_pos)
	var dark := mat(Color(0.06, 0.06, 0.07), 0.35)
	lbox(m, Vector3(0.22, 0.012, 0.18), Vector3(0, 0, 0), dark)
	lbox(m, Vector3(0.04, 0.3, 0.03), Vector3(0, 0.012, -0.06), dark)
	lbox(m, Vector3(0.56, 0.34, 0.03), Vector3(0, 0.11, -0.04), dark)
	lquad(m, Vector2(0.53, 0.31), Vector3(0, 0.28, -0.0235), lit(tex))


func _keyboard(o: Transform3D, local_pos: Vector3) -> void:
	var k := o * Transform3D(Basis(), local_pos)
	lbox(k, Vector3(0.44, 0.022, 0.14), Vector3.ZERO, mat(Color(0.08, 0.08, 0.09), 0.5))
	var key_m := mat(Color(0.2, 0.2, 0.22), 0.6)
	for r in 4:
		for c in 14:
			lbox(k, Vector3(0.024, 0.008, 0.024), Vector3(-0.19 + c * 0.0295, 0.022, -0.045 + r * 0.03), key_m, false)


func _mouse(o: Transform3D, local_pos: Vector3) -> void:
	var m := o * Transform3D(Basis(), local_pos)
	lbox(m, Vector3(0.22, 0.003, 0.2), Vector3.ZERO, mat(Color(0.08, 0.08, 0.09), 1.0), false)
	lbox(m, Vector3(0.06, 0.035, 0.1), Vector3(0, 0.003, 0), mat(Color(0.12, 0.12, 0.13), 0.3))


## Sedia da ufficio a rete. o = posizione a terra, chi siede guarda verso +Z locale.
func _mesh_chair(o: Transform3D) -> void:
	var black := mat(Color(0.07, 0.07, 0.08), 0.5)
	_chair_base(o, black)
	lbox(o, Vector3(0.48, 0.07, 0.46), Vector3(0, 0.42, 0), black)
	lbox(o, Vector3(0.05, 0.2, 0.03), Vector3(0, 0.45, -0.22), black)
	lbox(o, Vector3(0.44, 0.62, 0.04), Vector3(0, 0.6, -0.25), mat(Color(0.13, 0.13, 0.15), 0.95))
	for s in [-1.0, 1.0]:
		lbox(o, Vector3(0.04, 0.2, 0.04), Vector3(s * 0.25, 0.49, -0.02), black)
		lbox(o, Vector3(0.06, 0.03, 0.24), Vector3(s * 0.25, 0.69, 0.0), black)


## Poltrona direzionale in pelle con felpa nera sullo schienale (foto 7).
func _exec_chair(o: Transform3D) -> void:
	var leather := mat(Color(0.05, 0.05, 0.05), 0.3)
	var chrome := mat(Color(0.8, 0.8, 0.82), 0.2, 1.0)
	_chair_base(o, chrome)
	lbox(o, Vector3(0.54, 0.11, 0.52), Vector3(0, 0.4, 0), leather)
	lbox(o, Vector3(0.52, 0.78, 0.12), Vector3(0, 0.52, -0.26), leather)
	lbox(o, Vector3(0.42, 0.2, 0.1), Vector3(0, 1.3, -0.27), leather)
	lbox(o, Vector3(0.56, 0.35, 0.16), Vector3(0, 1.02, -0.27), mat(Color(0.02, 0.02, 0.02), 0.95))
	lbox(o, Vector3(0.22, 0.12, 0.005), Vector3(0, 1.2, -0.355), mat(Color(0.9, 0.9, 0.9), 0.8), false)
	for s in [-1.0, 1.0]:
		lbox(o, Vector3(0.04, 0.22, 0.2), Vector3(s * 0.29, 0.5, 0.0), chrome)
		lbox(o, Vector3(0.07, 0.04, 0.32), Vector3(s * 0.29, 0.7, 0.0), leather)


func _chair_base(o: Transform3D, m: Material) -> void:
	var black := mat(Color(0.07, 0.07, 0.08), 0.5)
	for i in 5:
		var a := TAU * i / 5.0
		var dir := Basis(Vector3.UP, a) * Vector3(1, 0, 0)
		lbox(o, Vector3(0.3, 0.03, 0.04), dir * 0.15 + Vector3(0, 0.045, 0), m, false, rad_to_deg(a))
		sphere(0.025, o * (dir * 0.29 + Vector3(0, 0.025, 0)), black, false)
	lcyl(o, 0.025, 0.36, Vector3(0, 0.06, 0), m)


func _desk_clutter() -> void:
	var white := mat(C_PAPER, 0.9)
	# --- testata dell'isola verso le finestre
	_pen_cup(Vector3(-0.55, T, -1.66), mat(Color(0.08, 0.08, 0.08), 0.5))
	_pen_cup(Vector3(-0.4, T, -1.7), mat(Color(0.15, 0.3, 0.75), 0.4))
	_headset(Vector3(-0.68, T, -1.5), Color(0.25, 0.8, 0.2))
	sphere(0.07, Vector3(-0.35, T + 0.03, -1.55), glass(Color(1, 1, 1, 0.45)), false, 0.6)   # busta di plastica
	box(Vector3(0.21, 0.004, 0.3), Vector3(0.15, T, -1.62), white, false, 10.0)
	box(Vector3(0.21, 0.004, 0.3), Vector3(0.2, T + 0.004, -1.6), white, false, -6.0)
	box(Vector3(0.2, 0.012, 0.14), Vector3(-0.45, T, -0.6), mat(Color(0.15, 0.15, 0.17), 0.6), true, 20.0)  # agenda

	# --- postazione ovest-porta (foto 7)
	box(Vector3(0.15, 0.015, 0.21), Vector3(-0.6, T, -0.28), mat(Color(0.95, 0.5, 0.15), 0.7), true, -15.0)   # quaderno arancione
	cyl(0.035, 0.09, Vector3(-0.42, T, -0.32), glass(Color(1, 1, 1, 0.5)))                                       # bicchiere
	box(Vector3(0.1, 0.02, 0.12), Vector3(-0.3, T, -0.05), mat(Color(0.05, 0.05, 0.05), 0.4), true, 10.0)       # portafoglio
	_glasses(Vector3(-0.62, T, 0.02))
	_headset(Vector3(-0.66, T, 0.22), Color(0.1, 0.1, 0.1))
	box(Vector3(0.17, 0.015, 0.24), Vector3(-0.6, T, 0.55), mat(Color(0.1, 0.55, 0.3), 0.7), true, 8.0)        # quaderno verde
	box(Vector3(0.22, 0.003, 0.18), Vector3(-0.32, T, 0.32), mat(Color(0.08, 0.08, 0.08), 1.0), false, -5.0)   # tappetino
	box(Vector3(0.06, 0.035, 0.1), Vector3(-0.34, T + 0.003, 0.3), mat(Color(0.1, 0.1, 0.1), 0.3))
	cyl_t(0.008, 0.14, Transform3D(Basis(Vector3.BACK, PI / 2) * Basis(Vector3.RIGHT, 0.6), Vector3(-0.15, T + 0.008, 0.48)), mat(Color(0.7, 0.1, 0.1)), false)
	torus(0.03, 0.05, Transform3D(Basis(), Vector3(-0.42, T + 0.01, 0.68)), mat(Color(0.95, 0.85, 0.8), 0.5))   # nastro adesivo
	box(Vector3(0.07, 0.003, 0.07), Vector3(-0.25, T, 0.62), mat(Color(1, 0.3, 0.2)), false, 15.0)            # post-it
	box(Vector3(0.07, 0.003, 0.07), Vector3(-0.22, T + 0.003, 0.6), mat(Color(0.9, 1, 0.2)), false, -10.0)

	# --- centro isola verso la porta: case del PC con sopra il contenitore trasparente
	box(Vector3(0.2, 0.36, 0.42), Vector3(0.12, T, 0.47), mat(Color(0.06, 0.06, 0.07), 0.4))
	box(Vector3(0.36, 0.15, 0.46), Vector3(0.12, T + 0.36, 0.47), glass(Color(0.9, 0.95, 1.0, 0.3)))
	for i in 6:
		var c: Color = PEN_COLORS[i]
		box(Vector3(0.08 + rng.randf() * 0.15, 0.03 + rng.randf() * 0.05, 0.1), Vector3(0.05 + rng.randf() * 0.12, T + 0.37, 0.3 + i * 0.06), mat(c, 0.6), false, rng.randf_range(-20, 20))

	# --- postazione est-finestre: badge col cordino blu, evidenziatori, ciabatta
	box(Vector3(0.012, 0.003, 0.35), Vector3(0.5, T, -0.75), mat(Color(0.1, 0.35, 0.9)), false, 30.0)
	box(Vector3(0.055, 0.004, 0.085), Vector3(0.45, T, -0.6), white, false)
	for i in 8:
		var c: Color = PEN_COLORS[i]
		cyl_t(0.012, 0.12, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0.38 + i * 0.026, T + 0.012, -0.45)), mat(c, 0.5), false)
	collider(Vector3(0.21, 0.024, 0.12), Vector3(0.47, T, -0.45))
	box(Vector3(0.06, 0.04, 0.32), Vector3(ICX + 0.06, T, -0.55), white)
	box(Vector3(0.03, 0.01, 0.03), Vector3(ICX + 0.06, T + 0.04, -0.43), emis(Color(1, 0.1, 0.1), 1.5), false)

	# --- postazione est-porta: pila di fogli e cuffie
	for i in 5:
		box(Vector3(0.21, 0.006, 0.3), Vector3(0.62 + rng.randf() * 0.03, T + i * 0.006, 0.5), white, true, rng.randf_range(-12, 12))
	_headset(Vector3(0.72, T, 0.72), Color(0.1, 0.1, 0.1))


func _pen_cup(p: Vector3, m: Material) -> void:
	cyl(0.04, 0.1, p, m)
	for i in 6:
		var c: Color = PEN_COLORS[rng.randi() % PEN_COLORS.size()]
		var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.05, 0.3))
		cyl_t(0.007, 0.15, Transform3D(tilt, p + Vector3(rng.randf_range(-0.02, 0.02), 0.1, rng.randf_range(-0.02, 0.02))), mat(c, 0.5), false)


func _headset(p: Vector3, accent: Color) -> void:
	torus(0.07, 0.085, Transform3D(Basis(Vector3.FORWARD, PI / 2), p + Vector3(0, 0.08, 0)), mat(Color(0.05, 0.05, 0.05), 0.4))
	for s in [-1.0, 1.0]:
		cyl_t(0.04, 0.03, Transform3D(Basis(Vector3.BACK, PI / 2), p + Vector3(s * 0.08, 0.04, 0)), mat(accent, 0.4), false)
	collider(Vector3(0.2, 0.1, 0.08), p)


func _glasses(p: Vector3) -> void:
	var frame := mat(Color(0.05, 0.05, 0.05), 0.3)
	var lens := glass(Color(0.6, 0.8, 0.95, 0.25))
	for s in [-1.0, 1.0]:
		var c := p + Vector3(s * 0.033, 0.028, 0)
		torus(0.024, 0.028, Transform3D(Basis(Vector3.RIGHT, PI / 2), c), frame)
		cyl_t(0.024, 0.002, Transform3D(Basis(Vector3.RIGHT, PI / 2), c), lens, false)
		box(Vector3(0.004, 0.004, 0.13), p + Vector3(s * 0.062, 0.002, -0.065), frame, false)
	box(Vector3(0.014, 0.004, 0.004), p + Vector3(0, 0.04, 0), frame, false)
	collider(Vector3(0.13, 0.056, 0.14), p + Vector3(0, 0, -0.06))


# ============================================================ MOBILI E OGGETTI

## Mobiletto basso (corpo grigio, piano bianco). facing = gradi; il fronte guarda +Z locale.
## Ritorna il suo sistema locale, per appoggiarci sopra oggetti con lbox/lcyl (piano a y = h).
func _low_cabinet(cx: float, cz: float, w: float, dpt: float, h: float, facing: float) -> Transform3D:
	var o := xf(Vector3(cx, 0, cz), facing)
	var steel := mat(Color(0.8, 0.8, 0.82), 0.25, 0.9)
	lbox(o, Vector3(w, h - 0.03, dpt), Vector3.ZERO, mat(Color(0.55, 0.55, 0.56), 0.5))
	lbox(o, Vector3(w + 0.02, 0.03, dpt + 0.02), Vector3(0, h - 0.03, 0), mat(Color(0.96, 0.96, 0.95), 0.4))
	lbox(o, Vector3(0.004, h - 0.08, 0.004), Vector3(0, 0.03, dpt / 2 + 0.002), mat(Color(0.3, 0.3, 0.3)), false)
	lbox(o, Vector3(0.015, 0.12, 0.02), Vector3(-0.03, h * 0.55, dpt / 2 + 0.01), steel, false)
	lbox(o, Vector3(0.015, 0.12, 0.02), Vector3(0.03, h * 0.55, dpt / 2 + 0.01), steel, false)
	return o


func _window_cabinets() -> void:
	# sinistra: zaino giallo e cartelline
	var l := _low_cabinet(-1.045, ZN + 0.2, 0.74, 0.4, 0.72, 0.0)
	lbox(l, Vector3(0.3, 0.22, 0.2), Vector3(0.18, 0.72, 0.02), mat(Color(0.95, 0.75, 0.1), 0.8), true, 15.0)
	lbox(l, Vector3(0.24, 0.006, 0.32), Vector3(-0.15, 0.72, 0.0), mat(Color(0.85, 0.2, 0.3), 0.6), false, -8.0)
	lbox(l, Vector3(0.21, 0.004, 0.3), Vector3(-0.2, 0.726, 0.02), mat(C_PAPER, 0.9), false, 12.0)
	# destra: bonsai, libro, sacca nera
	var r := _low_cabinet(1.045, ZN + 0.2, 0.74, 0.4, 0.72, 0.0)
	lcyl(r, 0.06, 0.11, Vector3(-0.05, 0.72, -0.05), mat(Color(0.97, 0.97, 0.97), 0.4))
	lcyl(r, 0.008, 0.12, Vector3(-0.05, 0.83, -0.05), mat(Color(0.45, 0.35, 0.25)), false)
	for i in 6:
		var a := TAU * i / 6.0
		sphere(0.045, r * Vector3(-0.05 + cos(a) * 0.05, 0.96 + rng.randf() * 0.05, -0.05 + sin(a) * 0.05), mat(Color(0.2, 0.5, 0.2), 0.7), false)
	lbox(r, Vector3(0.15, 0.03, 0.22), Vector3(0.2, 0.72, 0.05), mat(Color(0.95, 0.95, 0.9), 0.8), true, -10.0)
	lbox(r, Vector3(0.11, 0.025, 0.17), Vector3(0.2, 0.75, 0.03), mat(Color(0.15, 0.12, 0.1), 0.7), true, 15.0)
	lbox(r, Vector3(0.18, 0.08, 0.14), Vector3(-0.22, 0.72, 0.08), mat(Color(0.05, 0.05, 0.05), 0.8), true, 25.0)
	lbox(r, Vector3(0.05, 0.2, 0.05), Vector3(-0.28, 0.72, -0.12), mat(Color(0.12, 0.12, 0.12), 0.4))


func _south_corner() -> void:
	# mobiletto basso con zaini e bottiglia, contro la parete della porta
	var o := _low_cabinet(-0.6, ZS - 0.23, 0.8, 0.45, 0.78, 180.0)
	lbox(o, Vector3(0.32, 0.42, 0.18), Vector3(0.15, 0.78, 0.0), mat(Color(0.08, 0.1, 0.18), 0.9), true, -10.0)
	lbox(o, Vector3(0.24, 0.18, 0.06), Vector3(0.15, 0.82, -0.11), mat(Color(0.06, 0.08, 0.14), 0.9), false, -10.0)
	lbox(o, Vector3(0.3, 0.3, 0.2), Vector3(-0.2, 0.78, 0.0), mat(Color(0.05, 0.05, 0.05), 0.9), true, 20.0)
	lbox(o, Vector3(0.2, 0.1, 0.006), Vector3(-0.2, 0.92, -0.103), mat(Color(0.75, 0.65, 0.35), 0.6), false, 20.0)
	lcyl(o, 0.04, 0.3, Vector3(0.0, 0.78, 0.12), glass(Color(0.85, 0.95, 1.0, 0.45)))
	lcyl(o, 0.02, 0.03, Vector3(0.0, 1.08, 0.12), mat(Color(0.1, 0.5, 0.2)), false)
	lbox(o, Vector3(0.3, 0.006, 0.4), Vector3(0.0, 0.78, -0.02), mat(Color(0.3, 0.6, 0.85), 0.7), false, 5.0)
	# rotoli di disegni appoggiati all'angolo
	for i in 3:
		var p := Vector3(-1.08 + i * 0.07, 0.0, ZS - 0.1)
		cyl_t(0.04, 0.9, Transform3D(Basis(Vector3.RIGHT, 0.12), p + Vector3(0, 0.45, -0.05)), mat(Color(0.95, 0.95, 0.95), 0.9))
	# scatola di cartone aperta nell'angolo
	box(Vector3(0.35, 0.16, 0.28), Vector3(-1.3, 0, ZS - 0.2), mat(Color(0.66, 0.5, 0.32), 0.95), true, 8.0)
	box(Vector3(0.35, 0.004, 0.12), Vector3(-1.3, 0.16, ZS - 0.4), mat(Color(0.95, 0.85, 0.2), 0.8), false, 8.0)


func _coat_rack() -> void:
	var p := Vector3(1.3, 0, ZS - 0.22)
	var black := mat(Color(0.05, 0.05, 0.05), 0.4)
	cyl(0.17, 0.03, p, black)
	cyl(0.015, 1.75, p, black)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		cyl_t(0.008, 0.12, Transform3D(Basis(Vector3(-d.z, 0, d.x), 1.2), p + Vector3(0, 1.66, 0) + d * 0.05), black, false)
		sphere(0.02, p + Vector3(0, 1.69, 0) + d * 0.11, black, false)
	# giubbotto alta visibilità + giacca nera (solo grafica, una collisione unica sotto)
	box(Vector3(0.36, 0.75, 0.18), p + Vector3(-0.08, 0.92, 0.06), mat(Color(0.85, 1.0, 0.05), 0.7), false, 10.0)
	box(Vector3(0.365, 0.04, 0.185), p + Vector3(-0.08, 1.1, 0.06), emis(Color(0.85, 0.85, 0.85), 0.6), false, 10.0)
	box(Vector3(0.365, 0.04, 0.185), p + Vector3(-0.08, 1.3, 0.06), emis(Color(0.85, 0.85, 0.85), 0.6), false, 10.0)
	box(Vector3(0.3, 0.95, 0.14), p + Vector3(0.0, 0.72, -0.04), mat(Color(0.04, 0.04, 0.05), 0.9), false, -10.0)
	collider(Vector3(0.42, 1.0, 0.32), p + Vector3(-0.03, 0.7, 0.0))


func _dracena(p: Vector3) -> void:
	cyl(0.17, 0.48, p, mat(Color(0.95, 0.95, 0.93), 0.5))
	cyl(0.172, 0.06, p + Vector3(0, 0.36, 0), mat(Color(0.95, 0.75, 0.1), 0.5), false)
	cyl(0.025, 0.55, p + Vector3(0, 0.48, 0), mat(Color(0.45, 0.38, 0.28), 0.9))
	var leaf := mat(Color(0.35, 0.5, 0.35), 0.7)
	var leaf2 := mat(Color(0.5, 0.62, 0.45), 0.7)
	var top := p + Vector3(0, 1.0, 0)
	for i in 46:
		var yaw := rng.randf() * TAU
		var pitch := rng.randf_range(0.15, 1.45)
		var leaf_len := rng.randf_range(0.3, 0.55)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		box_t(Vector3(0.018, leaf_len, 0.004), Transform3D(b, top + b.y * (leaf_len / 2)), leaf if i % 3 != 0 else leaf2, false)


## Tavoletta di legno appoggiata all'isola dal lato porta: è la rampa per salire sulle scrivanie.
## (Non esiste nella stanza vera: serve al gioco. La pendenza deve restare sotto Config.MAX_SLOPE_DEG;
## sotto i 40° la potranno usare anche i nemici quando torneranno.)
## In cima finisce esattamente a filo del piano della scrivania (niente scalino); in basso entra
## un po' nel pavimento, così non resta un bordo su cui inciampare.
func _ramp() -> void:
	var a := atan2(T, RAMP_RUN)
	var b := Basis(Vector3.RIGHT, a)          # b.z punta in discesa, b.y è perpendicolare alla tavola
	var extra := 0.04                         # tratto in più, tutto dalla parte bassa
	var length := sqrt(T * T + RAMP_RUN * RAMP_RUN) + extra
	var mid := Vector3(RAMP_X, T / 2, IZ1 + RAMP_RUN / 2)
	box_t(Vector3(RAMP_W, 0.02, length), Transform3D(b, mid - b.y * 0.01 + b.z * (extra / 2)), mat(Color(0.72, 0.56, 0.36), 0.7))
