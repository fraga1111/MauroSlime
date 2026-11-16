extends Node3D
## MUNIZIONI A TERRA: ogni tanto compare una scatola di graffette (punti metallici) in uno dei punti
## di world/room.gd (PICKUP_SPOTS). Chi ci passa sopra la prende: un caricatore in più per OGNI arma.
## In multiplayer le fa comparire solo chi ospita e le manda a tutti; chi la prende avvisa gli altri,
## che la tolgono. Il nodo si chiama sempre "Munizioni" ed è figlio di Main (percorso uguale per le rpc).
## Numeri (ogni quanto, quante al massimo, caricatori per scatola) in config.gd, sezione "munizioni".

signal picked(text: String)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")

## Il giocatore locale (actors/player.gd), impostato da main.gd quando la partita parte
var player: Node = null

var _boxes := {}                 # id -> Node3D
var _next_id := 1
var _timer := 0.0
var _t := 0.0


func _ready() -> void:
	_timer = Config.PICKUP_FIRST
	multiplayer.peer_connected.connect(_on_peer_connected)


func _online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.multiplayer_peer != null


func _boss() -> bool:
	return not _online() or multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	# chi decide (giocatore da solo, o chi ospita) fa comparire le scatole
	if _boss():
		_timer -= delta
		if _timer <= 0.0:
			_timer = Config.PICKUP_INTERVAL
			if _boxes.size() < Config.PICKUP_MAX:
				var spot := _free_spot()
				if spot != Vector3.INF:
					var id := _next_id
					_next_id += 1
					_spawn(id, spot)
					if _online():
						_spawn.rpc(id, spot)
	# la scatola gira e galleggia; se il giocatore locale ci passa sopra, la prende
	for id in _boxes.keys():
		var b: Node3D = _boxes[id]
		b.rotation.y = _t * 1.6
		b.get_child(0).position.y = 0.25 + sin(_t * 3.0 + id) * 0.1
		if player.alive:
			var d: Vector3 = player.global_position - b.global_position
			if Vector2(d.x, d.z).length() < 1.1 and absf(d.y) < 1.6:
				_take(id)
				if _online():
					_take.rpc(id)
				player.add_clips(Config.PICKUP_CLIPS)
				picked.emit("+ GRAFFETTE  (un caricatore per ogni arma)")


## Punto di comparsa libero (niente scatole già lì), oppure Vector3.INF se sono tutti occupati.
func _free_spot() -> Vector3:
	var spots: Array = Room.PICKUP_SPOTS.duplicate()
	spots.shuffle()
	for s in spots:
		var p: Vector3 = s * Config.S
		var busy := false
		for b in _boxes.values():
			if (b as Node3D).global_position.distance_to(p) < 1.0:
				busy = true
		if not busy:
			return p
	return Vector3.INF


@rpc("authority", "reliable")
func _spawn(id: int, pos: Vector3) -> void:
	if _boxes.has(id):
		return
	var b := Node3D.new()
	b.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	b.add_child(_box_model())
	add_child(b)
	b.global_position = pos
	_boxes[id] = b
	_next_id = maxi(_next_id, id + 1)


@rpc("any_peer", "reliable")
func _take(id: int) -> void:
	var b: Node3D = _boxes.get(id)
	if b:
		b.queue_free()
	_boxes.erase(id)


## Chi ospita manda a chi arriva le scatole già a terra.
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	for bid in _boxes.keys():
		_spawn.rpc_id(id, bid, (_boxes[bid] as Node3D).global_position)


## Scatola di punti metallici (vera: circa 5 x 3 x 1,5 cm): cartone blu con l'etichetta,
## coperchio aperto e due stecche di graffette argentate sopra. Metri di gioco.
static func _box_model() -> Node3D:
	var root := Node3D.new()
	var blue := _mat(Color(0.12, 0.3, 0.75), 0.6)
	var white := _mat(Color(0.95, 0.95, 0.92), 0.7)
	var red := _mat(Color(0.85, 0.12, 0.12), 0.6)
	var steel := _mat(Color(0.82, 0.83, 0.86), 0.25)
	steel.metallic = 0.8
	steel.emission_enabled = true                    # un filo luminose, così si notano a terra
	steel.emission = Color(0.5, 0.5, 0.55)
	steel.emission_energy_multiplier = 0.3
	_box(root, Vector3(0.95, 0.28, 0.55), Vector3(0, 0.14, 0), blue)
	_box(root, Vector3(0.6, 0.18, 0.012), Vector3(0, 0.14, -0.28), white)       # etichetta davanti
	_box(root, Vector3(0.2, 0.1, 0.014), Vector3(-0.15, 0.14, -0.282), red)
	_box(root, Vector3(0.6, 0.18, 0.012), Vector3(0, 0.14, 0.28), white)        # etichetta dietro
	_box(root, Vector3(0.95, 0.02, 0.55), Vector3(0, 0.42, 0.33), blue, -70.0)  # coperchio aperto
	for z in [-0.1, 0.1]:                                                         # stecche di graffette
		_box(root, Vector3(0.8, 0.06, 0.12), Vector3(0, 0.31, z), steel)
		for i in 7:
			_box(root, Vector3(0.006, 0.065, 0.125), Vector3(-0.35 + i * 0.117, 0.31, z), _mat(Color(0.6, 0.6, 0.64), 0.4))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.75, 1.0)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.5
	root.add_child(light)
	return root


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot_x := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.x = deg_to_rad(rot_x)
	parent.add_child(mi)


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
