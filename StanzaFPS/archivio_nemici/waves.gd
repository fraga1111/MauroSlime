extends Node
## ONDATE DI SLIME: quando partono, quanti ne arrivano, dove compaiono e con che statistiche.
## Tutti i numeri sono in config.gd. main.gd ascolta i segnali e aggiorna interfaccia e ricompense.

signal wave_started(wave: int, boss: bool)
signal wave_cleared(wave: int)
signal score_changed(score: int)

const Config := preload("res://scripts/config.gd")
const Room := preload("res://scripts/world/room.gd")
const Slime := preload("res://scripts/actors/slime.gd")

var player                       # bersaglio degli slime
var spawn_parent: Node3D         # dove vengono aggiunti gli slime
var wave := 0
var score := 0
var alive := 0
var running := false

var _to_spawn := 0
var _boss_pending := false
var _spawn_t := 0.0
var _next_wave_t := -1.0


func start() -> void:
	running = true
	_next_wave_t = Config.FIRST_WAVE_DELAY


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	if _next_wave_t > 0.0:
		_next_wave_t -= delta
		if _next_wave_t <= 0.0:
			_start_wave()
	if _to_spawn > 0 or _boss_pending:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = Config.SPAWN_INTERVAL
			if _to_spawn > 0:
				_to_spawn -= 1
				_spawn_slime(false)
			else:
				_boss_pending = false
				_spawn_slime(true)


func _start_wave() -> void:
	wave += 1
	var boss := wave % Config.BOSS_EVERY == 0
	_to_spawn = Config.WAVE_BASE_COUNT + wave * Config.WAVE_COUNT_PER_WAVE
	_boss_pending = boss
	_spawn_t = 0.5
	wave_started.emit(wave, boss)


func _spawn_slime(boss: bool) -> void:
	if not running:
		return
	var s := Slime.new()
	s.player = player
	if boss:
		s.size = Config.BOSS_SIZE
		s.hp = Config.BOSS_HP + wave * Config.BOSS_HP_PER_WAVE
		s.speed = Config.BOSS_SPEED
		s.damage = Config.BOSS_DAMAGE
		s.color = Config.BOSS_COLOR
	else:
		s.hp = Config.SLIME_HP + wave / 2
		s.speed = minf(Config.SLIME_SPEED + wave * Config.SLIME_SPEED_PER_WAVE, Config.SLIME_MAX_SPEED)
		s.damage = Config.SLIME_DAMAGE + wave * Config.SLIME_DAMAGE_PER_WAVE
		if randf() < Config.SLIME_BLUE_CHANCE:
			s.color = Config.SLIME_BLUE
	s.position = _pick_spawn()
	s.died.connect(_on_slime_died)
	spawn_parent.add_child(s)
	alive += 1


## Punto di comparsa a caso tra quelli di room.gd, lontano dal giocatore.
func _pick_spawn() -> Vector3:
	var spawns := Room.ENEMY_SPAWNS.duplicate()
	spawns.shuffle()
	var pos: Vector3 = spawns[0] * Config.S
	for p in spawns:
		var candidate: Vector3 = p * Config.S
		if candidate.distance_to(player.global_position) < Config.MIN_SPAWN_DISTANCE:
			continue
		if p.y > 0.5 and wave < Config.DESK_SPAWNS_FROM_WAVE:
			continue
		pos = candidate
		break
	return pos


func _on_slime_died(points: int) -> void:
	alive -= 1
	score += points
	score_changed.emit(score)
	if running and alive <= 0 and _to_spawn == 0 and not _boss_pending:
		wave_cleared.emit(wave)
		_next_wave_t = Config.NEXT_WAVE_DELAY
