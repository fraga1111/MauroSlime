extends Node
## PUNTEGGI DELLA PARTITA: per ogni giocatore danni fatti, punti, uccisioni, assist, colpi in testa, volte a terra.
## I PUNTI sono i danni fatti (a nemici o, in TUTTI CONTRO TUTTI, agli altri giocatori) x Config.POINTS_PER_DAMAGE.
## UCCISIONE = l'ultimo colpo; ASSIST = chi ha fatto danno allo stesso bersaglio ma non l'ha finito.
##
## Chi comanda i conti è uno solo: offline questo computer, online chi ospita. Gli altri gli mandano i danni
## (record_damage, death) e lui rimanda a tutti la classifica (rows) due volte al secondo.
## Chi avvisa: actors/nemico.gd (danni ai nemici, tramite game/ondate.gd), game/rete.gd (danni tra giocatori),
## main.gd (giocatore a terra). La classifica la mostra ui/hud.gd (Tab in partita e a fine partita);
## a fine partita main.gd la salva nello storico (game/storico.gd).
## Questo nodo si chiama sempre "Punteggi" ed è figlio di Main: le chiamate rpc cercano lo stesso percorso.

signal changed

const Config := preload("res://scripts/config.gd")
const Characters := preload("res://scripts/data/characters.gd")

var rete                          # game/rete.gd: nomi e personaggi degli altri giocatori

var _stats := {}                  # peer -> riga (solo chi comanda)
var _hurt := {}                   # bersaglio ("e12" nemico, "p345" giocatore) -> {peer: danno}
var _rows: Array = []             # classifica ricevuta da chi comanda (gli altri)
var _dirty := false
var _send_t := 0.0


func _online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## true se i conti li fa questo computer (offline o chi ospita).
func is_boss() -> bool:
	return not _online() or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if _online() else 1


func reset() -> void:
	_stats.clear()
	_hurt.clear()
	_rows.clear()
	_dirty = true


# ---------------------------------------------------------------- avvisi dal gioco

## attacker ha fatto amount di danno al bersaglio target ("e<id>" nemico, "p<peer>" giocatore).
## killed = quel colpo l'ha steso. Si può chiamare da qualsiasi computer.
func record_damage(attacker: int, target: String, amount: float, head: bool, killed: bool) -> void:
	if amount <= 0.0 and not killed:
		return
	if is_boss():
		_apply(attacker, target, amount, head, killed)
	else:
		_report.rpc_id(1, attacker, target, amount, head, killed)


## Il giocatore peer è finito a terra.
func death(peer: int) -> void:
	if is_boss():
		_row(peer)["deaths"] += 1
		_hurt.erase("p%d" % peer)
		_dirty = true
	else:
		_death.rpc_id(1, peer)


func _apply(attacker: int, target: String, amount: float, head: bool, killed: bool) -> void:
	var s := _row(attacker)
	s["damage"] += maxf(amount, 0.0)
	if head:
		s["heads"] += 1
	var h: Dictionary = _hurt.get(target, {})
	h[attacker] = float(h.get(attacker, 0.0)) + maxf(amount, 0.0)
	_hurt[target] = h
	if killed:
		s["kills"] += 1
		for p in h:
			if p != attacker and float(h[p]) > 0.0:
				_row(p)["assists"] += 1
		_hurt.erase(target)
	_dirty = true


func _row(peer: int) -> Dictionary:
	if not _stats.has(peer):
		_stats[peer] = {"peer": peer, "name": "?", "char": 0, "damage": 0.0, "kills": 0,
				"assists": 0, "heads": 0, "deaths": 0}
	var s: Dictionary = _stats[peer]
	var info := _info_of(peer)
	if not info.is_empty():          # il nome si aggiorna finché il giocatore c'è (resta se esce)
		s["name"] = String(info.get("name", s["name"]))
		s["char"] = clampi(int(info.get("char", 0)), 0, Characters.LIST.size() - 1)
	return s


func _info_of(peer: int) -> Dictionary:
	if rete == null:
		return {}
	if peer == my_id():
		return rete.my_info
	return rete.info_of(peer)


# ---------------------------------------------------------------- classifica

## Classifica ordinata per punti: [{peer, name, char, points, damage, kills, assists, heads, deaths}, ...]
func rows() -> Array:
	if not is_boss():
		return _rows
	_row(my_id())                     # chi gioca c'è sempre, anche a zero punti
	if rete and _online():
		for av in rete.avatars():
			_row(av.peer_id)
	var out := []
	for s in _stats.values():
		var r: Dictionary = s.duplicate()
		r["points"] = int(round(float(s["damage"]) * Config.POINTS_PER_DAMAGE))
		r["damage"] = snappedf(float(s["damage"]), 0.1)
		out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["kills"] > b["kills"])
	return out


func total_points() -> int:
	var t := 0
	for r in rows():
		t += int(r["points"])
	return t


## La mia riga (vuota se non c'è ancora).
func my_row() -> Dictionary:
	for r in rows():
		if int(r["peer"]) == my_id():
			return r
	return {}


## Manda subito la classifica a tutti (fine partita).
func flush() -> void:
	if is_boss() and _online():
		_table.rpc(rows())
	_dirty = false
	changed.emit()


func _process(delta: float) -> void:
	if not is_boss():
		return
	_send_t -= delta
	if _dirty or (_online() and _send_t <= -1.5):
		if _send_t > 0.0:
			return
		_send_t = 0.5
		_dirty = false
		if _online():
			_table.rpc(rows())
		changed.emit()


@rpc("any_peer", "reliable")
func _report(attacker: int, target: String, amount: float, head: bool, killed: bool) -> void:
	if not is_boss():
		return
	_apply(attacker, target, clampf(amount, 0.0, 1000.0), head, killed)


@rpc("any_peer", "reliable")
func _death(peer: int) -> void:
	if is_boss():
		death(peer)


@rpc("authority", "reliable")
func _table(r: Array) -> void:
	_rows = r
	changed.emit()
