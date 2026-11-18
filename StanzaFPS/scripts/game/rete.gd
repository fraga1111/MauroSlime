extends Node
## MULTIPLAYER IN RETE LOCALE (stessa rete: ufficio, casa).
## Uno OSPITA (fa da server sulla porta PORT), gli altri si UNISCONO scrivendo il suo IP nel menu.
## Ognuno muove il proprio omino; 20 volte al secondo manda agli altri la sua posizione/posa
## (_state) e gli altri lo disegnano con un "avatar" (actors/avatar.gd). Spari e colpi viaggiano
## come messaggi: chi spara decide se ha colpito un avatar e manda il danno al suo proprietario (_hit).
## Ci si può unire anche a partita iniziata. Con la rete si passa per il server (server_relay di Godot),
## quindi i client si vedono anche tra loro.
##
## Chi ospita manda ogni secondo un "faro" sulla rete (UDP broadcast, porta BEACON_PORT): il menu degli
## altri lo sente e mostra il pulsante per entrare senza scrivere l'IP (ui/menu.gd).
## VERSIONE: un codice calcolato dai file degli script; se due giocatori ce l'hanno diverso, il gioco avvisa.
##
## MODO: chi ospita sceglie CO-OP (tutti insieme contro le ondate di nemici, game/ondate.gd; niente
## danni tra amici) oppure TUTTI CONTRO TUTTI. Il modo viaggia nella presentazione di chi ospita (_info).
##
## Questo nodo si chiama sempre "Rete" ed è figlio di Main: le chiamate rpc cercano lo stesso
## percorso su tutti i computer.

signal message(text: String)                 # avvisi da mostrare (entrato, uscito, colpito...)
signal joined                                 # client: collegato all'host, si può entrare in partita
signal join_failed(text: String)
signal host_closed
signal coop_known                             # client: chi ospita ha detto che la partita è in CO-OP

const Config := preload("res://scripts/config.gd")
const Avatar := preload("res://scripts/actors/avatar.gd")

const PORT := 7777
const BEACON_PORT := 7778
const BEACON_TAG := "MAUROSLIME"
const MAX_PLAYERS := 8
const SEND_RATE := 20.0                       # aggiornamenti al secondo

var online := false
var is_host := false
var coop := false                             # true = tutti insieme contro le ondate (niente danni tra amici)
## Chi sono io: {"name", "char", "stile", "weapon"}; impostato da main.gd prima di ospitare/unirsi
var my_info := {}
## Il giocatore locale (actors/player.gd), impostato da main.gd quando la partita parte
var player: Node = null
## game/punteggi.gd: chi mi colpisce si prende i punti (danni) e l'uccisione
var punteggi: Node = null

var _infos := {}                              # id -> info degli altri
var _avatars := {}                            # id -> Avatar
var _send_t := 0.0
var _beacon: PacketPeerUDP
var _beacon_t := 0.0
static var _version := ""


func _ready() -> void:
	my_info["ver"] = version()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


## Apre la partita su questo computer. Ritorna OK o un codice di errore.
func host() -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = true
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	return OK


## Si collega alla partita di chi ospita (ip). Il risultato arriva con i segnali joined / join_failed.
func join(ip: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	online = false
	is_host = false
	coop = false
	if _beacon:
		_beacon.close()
		_beacon = null
	for id in _avatars.keys():
		_remove_avatar(id)


## Indirizzi IPv4 di rete locale di questo computer (quelli da dare agli amici).
static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a):
			out.append(a)
	return out


static func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var second := int(a.split(".")[1])
	return second >= 16 and second <= 31


## Codice della versione del gioco: impronta (md5) di tutti gli script. Cambia a ogni modifica.
static func version() -> String:
	if _version != "":
		return _version
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var files := PackedStringArray()
	_collect("res://scripts", files)
	files.sort()
	for f in files:
		ctx.update(FileAccess.get_file_as_bytes(f))
	_version = ctx.finish().hex_encode().substr(0, 6) if files.size() > 0 else "?"
	return _version


static func _collect(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)


func player_count() -> int:
	return _avatars.size() + 1


## Presentazione dell'altro giocatore id ({"name", "char", ...}); vuota se non lo conosco.
func info_of(id: int) -> Dictionary:
	return _infos.get(id, {})


## Personaggi usati da tutti i giocatori (io compreso): i nemici delle ondate non li usano.
func used_chars() -> Array:
	var out := []
	if my_info.has("char"):
		out.append(int(my_info["char"]))
	for info in _infos.values():
		out.append(int(info.get("char", -1)))
	return out


# ---------------------------------------------------------------- collegamenti

func _on_peer_connected(id: int) -> void:
	_info.rpc_id(id, my_info)                 # mi presento a chi è appena arrivato


func _on_peer_disconnected(id: int) -> void:
	if _infos.has(id):
		message.emit("%s è uscito" % _infos[id]["name"])
	_infos.erase(id)
	_remove_avatar(id)


func _on_connected() -> void:
	online = true
	joined.emit()


func _on_failed() -> void:
	multiplayer.multiplayer_peer = null
	join_failed.emit("Non riesco a collegarmi: controlla l'IP e che l'altro abbia premuto OSPITA")


func _on_server_gone() -> void:
	leave()
	host_closed.emit()


# ---------------------------------------------------------------- messaggi

## Presentazione: nome, personaggio, aspetto, arma. Crea l'avatar di chi la manda.
@rpc("any_peer", "reliable")
func _info(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	var first := not _infos.has(id)
	_infos[id] = info
	if first and String(info.get("ver", "")) != version():
		message.emit("ATTENZIONE: %s ha un'altra versione del gioco (%s, tu %s).
Aggiornate tutti e due!" % [
				info.get("name", "?"), info.get("ver", "?"), version()])
	if _avatars.has(id):
		_remove_avatar(id)
	var av := Avatar.new()
	av.name = "Avatar_%d" % id
	av.setup(id, info)
	av.hit.connect(_on_avatar_hit)
	get_parent().add_child(av)
	_avatars[id] = av
	if id == 1 and bool(info.get("coop", false)) and not coop:
		coop = true
		coop_known.emit()
	_apply_coop()
	if first:
		message.emit("%s è entrato in partita" % info.get("name", "?"))


## Posa del giocatore id (vedi player.gd net_state()).
@rpc("any_peer", "unreliable_ordered")
func _state(s: Array) -> void:
	var av: Avatar = _avatars.get(multiplayer.get_remote_sender_id())
	if av:
		av.apply_state(s)


## Il giocatore id ha sparato: fiammata sulla sua arma e segno dove ha colpito.
@rpc("any_peer", "unreliable")
func _shot(to: Vector3, normal: Vector3, world: bool) -> void:
	var av: Avatar = _avatars.get(multiplayer.get_remote_sender_id())
	if av:
		av.show_shot(to, normal, world)


## Qualcuno mi ha colpito (head = in testa).
@rpc("any_peer", "reliable")
func _hit(amount: float, head := false) -> void:
	if player == null or not player.alive:
		return
	var from := multiplayer.get_remote_sender_id()
	var before: float = player.hp
	player.take_damage(amount)
	if punteggi:
		punteggi.record_damage(from, "p%d" % multiplayer.get_unique_id(), before - float(player.hp), head, not player.alive)
	if not player.alive:
		var who: String = _infos.get(from, {}).get("name", "qualcuno")
		message.emit("Ti ha steso %s!" % who)
		_ko.rpc(from)


## Il giocatore che manda il messaggio è stato steso da killer.
@rpc("any_peer", "reliable")
func _ko(killer: int) -> void:
	var victim := multiplayer.get_remote_sender_id()
	var vname: String = _infos.get(victim, {}).get("name", "?")
	if killer == multiplayer.get_unique_id():
		message.emit("Hai steso %s!" % vname)
	else:
		message.emit("%s è stato steso da %s" % [vname, _infos.get(killer, {}).get("name", "?")])


# ---------------------------------------------------------------- dal gioco locale

func _physics_process(delta: float) -> void:
	if _beacon and is_host:
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var msg := "%s|%s|%s|%d" % [BEACON_TAG, version(), my_info.get("name", "?"), player_count()]
			_beacon.put_packet(msg.to_utf8_buffer())
	if not online or player == null or multiplayer.multiplayer_peer == null:
		return
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = 1.0 / SEND_RATE
		_state.rpc(player.net_state())


## Collegato a player.fired da main.gd.
func on_player_fired(to: Vector3, normal: Vector3, world: bool) -> void:
	if online:
		_shot.rpc(to, normal, world)


func _on_avatar_hit(id: int, amount: float, head: bool) -> void:
	if online and not coop:
		_hit.rpc_id(id, amount * Config.PVP_DAMAGE, head)


## Omini degli altri giocatori (li usano i nemici in co-op come bersagli).
func avatars() -> Array:
	var out := []
	for av in _avatars.values():
		if is_instance_valid(av):
			out.append(av)
	return out


## In co-op gli amici non si colpiscono: i loro omini non fermano i colpi (passano ai nemici dietro).
func _apply_coop() -> void:
	if not coop:
		return
	for av in avatars():
		(av as Avatar).collision_layer = 0


func _remove_avatar(id: int) -> void:
	var av: Node = _avatars.get(id)
	if av:
		av.queue_free()
	_avatars.erase(id)
