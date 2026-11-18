extends Node
## ONDATE DI NEMICI: quanti nemici arrivano, dove compaiono e quanto sono forti.
## I nemici (actors/nemico.gd) sono gli omini del menu con un'arma a caso; ogni ondata sono di più,
## hanno più vita, corrono di più, mirano meglio e sparano più spesso. Ogni WAVE_BOSS_EVERY ondate c'è un CAPO.
## Tutti i numeri sono in config.gd (sezione "partita OFFLINE"). main.gd ascolta i segnali per l'interfaccia.
##
## Due modi:
##   OFFLINE      tutto su questo computer, l'unico bersaglio è il giocatore.
##   CO-OP ONLINE (net = true) chi ospita (is_host) comanda: crea i nemici, li muove, decide chi colpiscono
##                (il giocatore più vicino, anche gli amici) e manda tutto agli altri 20 volte al secondo.
##                Gli altri hanno solo copie dei nemici (puppet): i loro colpi vengono mandati a chi ospita.
##                Chi muore resta a terra fino alla fine dell'ondata; se cadono tutti, la partita finisce.
## I PUNTI sono i danni fatti ai nemici: li conta game/punteggi.gd (anche uccisioni e assist di ognuno).
## I nemici non usano mai i personaggi dei giocatori (né il tuo né, in co-op, quelli degli amici).
## Questo nodo si chiama sempre "Ondate" ed è figlio di Main: le chiamate rpc cercano lo stesso percorso.

signal wave_started(wave: int, boss: bool)
signal wave_cleared(wave: int)
signal enemies_changed(left: int)
signal all_down(wave: int, score: int)        # co-op: tutti i giocatori a terra, partita finita

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")
const Characters := preload("res://scripts/data/characters.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const Nemico := preload("res://scripts/actors/nemico.gd")

var player                       # il giocatore di questo computer
var rete                         # game/rete.gd (co-op: gli omini degli amici sono bersagli anche loro)
var punteggi                     # game/punteggi.gd: danni, uccisioni e assist di ogni giocatore
var player_char := -1            # il personaggio del giocatore (i nemici non lo usano mai)
var spawn_parent: Node3D         # dove vengono aggiunti i nemici
var net := false                 # co-op online
var is_host := true              # offline o chi ospita: comanda lui
var wave := 0
## Punti di tutta la squadra (somma dei danni fatti, game/punteggi.gd)
var score: int:
	get:
		return punteggi.total_points() if punteggi else 0
var alive := 0
var running := false

var _to_spawn := 0
var _boss_pending := false
var _spawn_t := 0.0
var _next_wave_t := -1.0
var _enemies := {}               # net_id -> Nemico
var _next_id := 1
var _send_t := 0.0


func _ready() -> void:
	if net and not is_host:
		_sync_request.rpc_id(1)          # entrato a partita iniziata: chiede i nemici che ci sono già


func start() -> void:
	running = true
	_next_wave_t = Config.WAVE_FIRST_DELAY


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running or not is_host:
		return
	if _next_wave_t > 0.0:
		_next_wave_t -= delta
		if _next_wave_t <= 0.0:
			_start_wave()
	if (_to_spawn > 0 or _boss_pending) and alive < Config.WAVE_MAX_ALIVE:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = Config.WAVE_SPAWN_INTERVAL
			if _to_spawn > 0:
				_to_spawn -= 1
				_spawn(false)
			else:
				_boss_pending = false
				_spawn(true)
	if net:
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = 1.0 / Config.COOP_SEND_RATE
			_send_states()
		if wave >= 1 and targets().is_empty():
			running = false
			if punteggi:
				punteggi.flush()          # la classifica finale arriva a tutti prima della fine
			all_down.emit(wave, score)
			_all_down.rpc(wave, score)


func left() -> int:
	return alive + _to_spawn + (1 if _boss_pending else 0)


# ---------------------------------------------------------------- bersagli e danni (li usa nemico.gd)

## Giocatori vivi a cui sparare: il giocatore e, in co-op, gli omini degli amici.
func targets() -> Array:
	var out := []
	if player and is_instance_valid(player) and player.is_alive():
		out.append(player)
	if net and rete:
		for av in rete.avatars():
			if av.is_alive():
				out.append(av)
	return out


func damage_target(t: Node, amount: float) -> void:
	if t == null or not is_instance_valid(t):
		return
	if t == player:
		player.take_damage(amount)
	elif net:
		_enemy_damage.rpc_id(t.peer_id, amount)     # un amico: il danno lo applica il suo computer


func enemy_shot(e: Nemico, end: Vector3, normal: Vector3, wall: bool) -> void:
	if net:
		_shot.rpc(e.net_id, end, normal, wall)


## Copia di rete colpita da questo giocatore: manda il danno a chi ospita.
func send_hit(id: int, amount: float, head: bool) -> void:
	_hit.rpc_id(1, id, amount, head)


## Il mio id di rete (1 offline e per chi ospita): serve per sapere chi ha fatto i danni.
func my_id() -> int:
	return multiplayer.get_unique_id() if net else 1


## Un nemico ha preso danno da attacker (nemico.gd apply_damage, solo su chi comanda).
func enemy_damaged(attacker: int, id: int, amount: float, head: bool, killed: bool) -> void:
	if punteggi:
		punteggi.record_damage(attacker, "e%d" % id, amount, head, killed)


# ---------------------------------------------------------------- ondate (solo chi comanda)

func _start_wave() -> void:
	wave += 1
	var boss := wave % Config.WAVE_BOSS_EVERY == 0
	var players := targets().size() if net else 1
	var count := Config.WAVE_BASE_COUNT + wave * Config.WAVE_COUNT_PER_WAVE
	_to_spawn = int(round(count * (1.0 + Config.COOP_EXTRA_PER_PLAYER * maxi(players - 1, 0))))
	_boss_pending = boss
	_spawn_t = 0.3
	wave_started.emit(wave, boss)
	enemies_changed.emit(left())
	if net:
		_wave_start.rpc(wave, boss)
		_hud.rpc(wave, left())


func _spawn(boss: bool) -> void:
	var w := float(wave - 1)                 # 0 alla prima ondata
	var e := Nemico.new()
	e.ondate = self
	e.net_id = _next_id
	_next_id += 1
	e.name = "Nemico_%d" % e.net_id
	e.char_index = _pick_char()
	e.weapon = randi() % Weapons.LIST.size()
	e.boss = boss
	e.hp = Config.ENEMY_HP + w * Config.ENEMY_HP_PER_WAVE
	e.speed = minf(Config.ENEMY_SPEED + w * Config.ENEMY_SPEED_PER_WAVE, Config.ENEMY_MAX_SPEED)
	e.damage = minf(Config.ENEMY_DAMAGE + w * Config.ENEMY_DAMAGE_PER_WAVE, Config.ENEMY_MAX_DAMAGE)
	e.fire_delay = maxf(Config.ENEMY_FIRE_DELAY * pow(0.9, w), Config.ENEMY_FIRE_DELAY_MIN)
	e.burst = Config.ENEMY_BURST + int(w / 3.0)
	e.burst_pause = maxf(Config.ENEMY_BURST_PAUSE * pow(0.92, w), 0.6)
	e.spread = maxf(Config.ENEMY_SPREAD * pow(0.88, w), Config.ENEMY_SPREAD_MIN)
	e.reaction = maxf(Config.ENEMY_REACTION * pow(0.88, w), Config.ENEMY_REACTION_MIN)
	if boss:
		e.hp *= Config.BOSS_HP_MULT
		e.damage *= Config.BOSS_DAMAGE_MULT
		e.speed *= 0.8
	e.position = _pick_spawn()
	e.rotation.y = randf() * TAU
	e.died.connect(_on_died.bind(e))
	spawn_parent.add_child(e)
	_enemies[e.net_id] = e
	alive += 1
	if net:
		_spawn_puppet.rpc(_puppet_info(e))


## Un personaggio a caso tra quelli del menu, ma MAI uno usato da un giocatore (il tuo e, in co-op,
## quelli degli amici). Solo se i giocatori li usano tutti si prende uno qualsiasi tranne il tuo.
func _pick_char() -> int:
	var n := Characters.LIST.size()
	var used := [player_char]
	if net and rete:
		used.append_array(rete.used_chars())
	var free := []
	for i in n:
		if not used.has(i):
			free.append(i)
	if free.is_empty():
		for i in n:
			if i != player_char:
				free.append(i)
	if free.is_empty():
		return randi() % n
	return int(free[randi() % free.size()])


## Punto di comparsa a caso tra quelli di room.gd, lontano da tutti i giocatori.
func _pick_spawn() -> Vector3:
	var spawns := Room.ENEMY_SPAWNS.duplicate()
	spawns.shuffle()
	var pos: Vector3 = spawns[0] * Config.S
	var ts := targets()
	for p in spawns:
		var candidate: Vector3 = p * Config.S
		var near := false
		for t in ts:
			if candidate.distance_to(t.global_position) < Config.WAVE_MIN_SPAWN_DIST:
				near = true
		if near:
			continue
		if p.y > 0.5 and wave < Config.WAVE_DESK_FROM:
			continue
		pos = candidate
		break
	# un po' sparpagliati, così due nemici non nascono uno dentro l'altro
	return pos + Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0))


func _on_died(e: Nemico) -> void:
	_enemies.erase(e.net_id)
	alive -= 1
	enemies_changed.emit(left())
	if net:
		_died.rpc(e.net_id)
		_hud.rpc(wave, left())
	if running and left() <= 0:
		wave_cleared.emit(wave)
		if net:
			_wave_clear.rpc(wave)
		_next_wave_t = Config.WAVE_NEXT_DELAY


# ---------------------------------------------------------------- rete (co-op)

func _puppet_info(e: Nemico) -> Array:
	return [e.net_id, e.char_index, e.weapon, e.boss, e.global_position if e.is_inside_tree() else e.position,
			e.rotation.y, e.max_hp if e.max_hp > 0.0 else e.hp, e.hp]


func _send_states() -> void:
	if _enemies.is_empty():
		return
	var data := []
	for id in _enemies:
		var e: Nemico = _enemies[id]
		data.append([id, e.global_position, e.rotation.y, e.pitch(), e.hspeed(), e.hp])
	_states.rpc(data)


## Chi è entrato a partita iniziata chiede la situazione.
@rpc("any_peer", "reliable")
func _sync_request() -> void:
	if not is_host:
		return
	var who := multiplayer.get_remote_sender_id()
	for id in _enemies:
		_spawn_puppet.rpc_id(who, _puppet_info(_enemies[id]))
	_hud.rpc_id(who, wave, left())


@rpc("authority", "reliable")
func _spawn_puppet(info: Array) -> void:
	var id: int = info[0]
	if _enemies.has(id):
		return
	var e := Nemico.new()
	e.ondate = self
	e.puppet = true
	e.net_id = id
	e.name = "Nemico_%d" % id
	e.char_index = clampi(int(info[1]), 0, Characters.LIST.size() - 1)
	e.weapon = clampi(int(info[2]), 0, Weapons.LIST.size() - 1)
	e.boss = info[3]
	e.position = info[4]
	e.rotation.y = info[5]
	e.max_hp = info[6]
	e.hp = info[7]
	spawn_parent.add_child(e)
	_enemies[id] = e


@rpc("authority", "unreliable_ordered")
func _states(data: Array) -> void:
	for s in data:
		var e: Nemico = _enemies.get(int(s[0]))
		if e and is_instance_valid(e):
			e.apply_state(s[1], s[2], s[3], s[4], s[5])


@rpc("authority", "unreliable")
func _shot(id: int, end: Vector3, normal: Vector3, wall: bool) -> void:
	var e: Nemico = _enemies.get(id)
	if e and is_instance_valid(e):
		e.show_shot(end, normal, wall)


@rpc("authority", "reliable")
func _died(id: int) -> void:
	var e: Nemico = _enemies.get(id)
	_enemies.erase(id)
	if e and is_instance_valid(e):
		e.fall()


@rpc("authority", "reliable")
func _hud(w: int, n: int) -> void:
	wave = w
	enemies_changed.emit(n)


@rpc("authority", "reliable")
func _wave_start(w: int, boss: bool) -> void:
	wave = w
	wave_started.emit(w, boss)


@rpc("authority", "reliable")
func _wave_clear(w: int) -> void:
	wave_cleared.emit(w)


@rpc("authority", "reliable")
func _all_down(w: int, s: int) -> void:
	all_down.emit(w, s)


## Un nemico ha colpito me (lo decide chi ospita).
@rpc("authority", "reliable")
func _enemy_damage(amount: float) -> void:
	if player and is_instance_valid(player):
		player.take_damage(amount)


## Un amico ha colpito un nemico: il danno lo applico io (chi ospita).
@rpc("any_peer", "reliable")
func _hit(id: int, amount: float, head: bool) -> void:
	if not is_host:
		return
	var e: Nemico = _enemies.get(id)
	if e and is_instance_valid(e):
		e.apply_damage(clampf(amount, 0.0, 100.0), head, Vector3.ZERO, multiplayer.get_remote_sender_id())
