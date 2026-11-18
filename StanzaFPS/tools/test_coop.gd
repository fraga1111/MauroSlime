extends SceneTree
## TEST AUTOMATICO della CO-OP online (due copie del gioco sullo stesso computer, senza grafica).
## Lo lancia tools/test_coop.sh:
##   ... -s res://tools/test_coop.gd -- --ruolo=host     ospita in co-op (porta 7777)
##   ... -s res://tools/test_coop.gd -- --ruolo=client   si unisce a 127.0.0.1
## Controlla che:
##   host:   l'amico entra, arrivano i nemici, un nemico muore per i colpi dell'amico (punti > 0)
##   client: vede le copie dei nemici, le colpisce, il danno arriva a chi ospita e il nemico cade
## Stampa "TEST OK" oppure "TEST FALLITO: ..." (ed esce con codice 1).

var main
var role := "host"
var frames := 0
var done := false
var hit_sent := false
var host_ok := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ruolo="):
			role = a.substr(8)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _secs() -> float:
	return Time.get_ticks_msec() / 1000.0


func _end(ok: bool, why: String) -> void:
	if done:
		return
	done = true
	print("[%s] %s" % [role, "TEST OK" if ok else "TEST FALLITO: " + why])
	quit(0 if ok else 1)


func _tick() -> void:
	frames += 1
	if frames == 2:
		if role == "host":
			main.host_game(0, 0, "", "Host", true)
		else:
			main.join_game(3, 1, "", "Amico", "127.0.0.1")
		return
	if main.player:
		main.player.max_hp = 100000.0          # nessuno deve morire durante il test
		if main.player.hp > 1000.0 or frames < 10:
			main.player.hp = 100000.0
	var o = main.ondate
	if role == "host":
		if host_ok:
			return
		if o and o.score > 0 and main.rete.player_count() >= 2:
			print("[host] amici %d, ondata %d, punti %d" % [main.rete.player_count(), o.wave, o.score])
			# resta acceso ancora un po' perché l'amico riceva la morte del nemico
			if _secs() > 3.0:
				host_ok = true
				await create_timer(3.0).timeout
				_end(true, "")
		elif _secs() > 60.0:
			_end(false, "nessun nemico ucciso dall'amico (amici %d, ondate %s)" % [main.rete.player_count(), str(o != null)])
	else:
		if o and not o.is_host:
			var puppets: Array = o._enemies.values()
			if puppets.size() > 0 and not hit_sent:
				var e = puppets[0]
				print("[client] vedo %d nemici, colpisco %s" % [puppets.size(), e.name])
				e.take_hit(1000.0, e.global_position, Vector3.FORWARD)
				hit_sent = true
			if hit_sent and o.score > 0:
				print("[client] punti %d, ondata %d" % [o.score, o.wave])
				_end(true, "")
		if _secs() > 60.0:
			_end(false, "client: ondate %s, nemici visti %s, colpo mandato %s" % [
					str(o != null), str(o._enemies.size() if o else 0), str(hit_sent)])
