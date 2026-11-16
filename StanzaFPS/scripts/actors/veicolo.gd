extends CharacterBody3D
## BASE DEI VEICOLI: quello che serve al giocatore (actors/player.gd) per salire, guidare e scendere.
## I veicoli veri estendono questo file:
##   actors/macchinina.gd   Opel Agila bianca in scala 1:18, si guida a terra (e su per la rampa)
##   actors/aeroplanino.gd  aeroplanino di carta, si pilota in volo
## Si sale e si scende con E (tasto "interact" in game/input_setup.gd), a meno di Config.ENTER_DISTANCE.
## Mentre guidi l'omino è FIGLIO del veicolo (seduto al posto "seat"): così si muovono insieme senza scatti.
## Dove stanno a inizio partita: CAR_SPOT / PLANE_SPOT in world/room.gd. Numeri in config.gd.

const Config := preload("res://scripts/config.gd")

## Chi guida (il giocatore); null = nessuno
var driver: CharacterBody3D = null
## Per il messaggio "E  sali ..." (con la preposizione: "sulla macchinina")
var nome := "sul veicolo"
## Comandi mostrati in basso mentre guidi
var aiuto := ""
## Telecamera mentre guidi: distanza dietro il veicolo e altezza del punto che guarda
var cam_reach := 8.0
var cam_height := 2.0
## Dove sta l'ANCA di chi guida (coordinate del veicolo, metri di gioco)
var seat := Vector3.ZERO

var _home := Transform3D()


func _enter_tree() -> void:
	add_to_group("veicoli")


func _ready() -> void:
	_home = global_transform
	collision_layer = Config.LAYER_VEHICLE
	collision_mask = Config.LAYER_WORLD | Config.LAYER_VEHICLE | Config.LAYER_ENEMY
	floor_max_angle = deg_to_rad(Config.MAX_SLOPE_DEG)


## Dove vanno i piedi dell'omino seduto (l'anca è alta hip sopra i piedi), in coordinate del veicolo.
func seat_local(hip: float) -> Transform3D:
	return Transform3D(Basis(), seat - Vector3(0.0, hip, 0.0))


## Posti dove scendere, in ordine di preferenza (coordinate del veicolo): il giocatore prende il primo libero.
func exit_spots() -> Array[Vector3]:
	return [Vector3(-3.0, 0.05, 0.0), Vector3(3.0, 0.05, 0.0)]


## Il giocatore muove il mouse mentre guida (rel già moltiplicato per la sensibilità).
func mouse_look(_rel: Vector2) -> void:
	pass


## Dove guarda la telecamera mentre guidi.
func cam_yaw() -> float:
	return rotation.y


func cam_pitch() -> float:
	return -0.2


## Direzione del muso (per far scendere l'omino girato come il veicolo).
func heading() -> float:
	return rotation.y


## Qualcuno è salito (driver già impostato) / è sceso.
func got_in() -> void:
	pass


func got_out() -> void:
	pass


## I comandi valgono solo con qualcuno sopra e il mouse catturato (nei test automatici sempre).
func controls() -> bool:
	if driver == null:
		return false
	return bool(driver.get("auto_test")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Caduto fuori dal mondo: torna dove era a inizio partita.
func check_fallen() -> bool:
	if global_position.y > -40.0:
		return false
	global_transform = _home
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	return true


## Materiale semplice (colore, ruvidità, metallo).
static func mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Materiale che si illumina da solo (fari, display).
static func lamp(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := mat(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Scatola (dimensioni size, centro pos, rotazione in gradi rot) dentro parent.
static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## Lastra lunga da a a b (punti (z, y) visti di fianco), larga w lungo x, spessa t, centrata in x = cx.
static func slab(parent: Node3D, a: Vector2, b: Vector2, w: float, t: float, m: Material, cx := 0.0) -> MeshInstance3D:
	var d := b - a
	var mi := box(parent, Vector3(w, t, d.length()), Vector3(cx, (a.y + b.y) / 2.0, (a.x + b.x) / 2.0), m)
	mi.rotation.x = atan2(-d.y, d.x)
	return mi
