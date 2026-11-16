extends CanvasLayer
## Menu: prima si sceglie il personaggio (una scheda per ogni voce di data/characters.gd),
## poi l'arma (un pulsante per ogni voce di data/weapons.gd).
## Per le persone vere (MATTEO, BROSKI) il pulsante ASPETTO sceglie lo stile: BLENDER o MINECRAFT.
## In alto a destra il pannello MULTIPLAYER: OSPITA apre la partita su questo computer (gli amici
## sulla stessa rete scrivono il tuo IP), UNISCITI entra nella partita di chi ospita.
## Le partite aperte sulla rete compaiono da sole come pulsanti "ENTRA" (le annuncia game/rete.gd);
## nome e ultimo IP vengono salvati (user://multiplayer.cfg) e ritrovati alla prossima apertura.
## Tasti: numeri o frecce sx/dx = personaggio, Q/E o frecce su/giu = arma, T = aspetto, Invio per giocare.

signal selected(index: int)
signal weapon_selected(weapon: int)
signal style_changed(index: int, stile: String)
signal start_game(index: int, weapon: int, stile: String)
signal host_game(index: int, weapon: int, stile: String, player_name: String)
signal join_game(index: int, weapon: int, stile: String, player_name: String, ip: String)

const Characters := preload("res://scripts/data/characters.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const Rete := preload("res://scripts/game/rete.gd")
const LooksMinecraft := preload("res://scripts/data/looks_minecraft.gd")

var index := 0
var weapon := 0
var stili := {}          # indice del personaggio -> "blender" | "minecraft" (solo persone vere)

var _cards: Array[Button] = []
var _weapon_btns: Array[Button] = []
var _play_btn: Button
var _style_btn: Button
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _net_status: Label
var _net_btns: Array[Button] = []
## ultimi nome e IP usati (restano quando si torna al menu)
static var last_name := ""
static var last_ip := ""
const SAVE := "user://multiplayer.cfg"
var _found_box: VBoxContainer
var _found := {}                  # ip -> {"name", "ver", "count", "t", "btn"}
var _listen: PacketPeerUDP


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -270.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var title := _label(root, 78, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "MAUROSLIME"
	title.offset_top = 26.0
	title.add_theme_color_override("font_color", Color(0.35, 0.95, 0.4))
	title.add_theme_constant_override("outline_size", 14)
	var sub := _label(root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	sub.text = "Scegli il tuo omino da 10 cm"
	sub.offset_top = 128.0

	# schede dei personaggi
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -258.0
	bar.offset_bottom = -188.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for i in Characters.LIST.size():
		var card := _make_card(i)
		bar.add_child(card)
		_cards.append(card)

	# armi: si sceglie dopo il personaggio
	var wrow := HBoxContainer.new()
	wrow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrow.offset_top = -172.0
	wrow.offset_bottom = -118.0
	wrow.alignment = BoxContainer.ALIGNMENT_CENTER
	wrow.add_theme_constant_override("separation", 16)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrow)
	for i in Weapons.LIST.size():
		var wb := _button(wrow, Vector2(260, 54))
		wb.text = String(Weapons.LIST[i]["name"])
		wb.add_theme_font_size_override("font_size", 19)
		wb.pressed.connect(select_weapon.bind(i))
		_weapon_btns.append(wb)

	# pulsanti in basso
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -98.0
	row.offset_bottom = -44.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	_play_btn = _button(row, Vector2(300, 54))
	_play_btn.text = "GIOCA  (Invio)"
	_play_btn.pressed.connect(_play)
	_style_btn = _button(row, Vector2(330, 54))
	_style_btn.pressed.connect(toggle_style)

	var help := _label(root, 13, HORIZONTAL_ALIGNMENT_CENTER)
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -40.0
	help.offset_bottom = -3.0
	help.text = "WASD muovi · Shift (o tasto laterale del mouse) corri · Spazio salta · B super salto · Ctrl accovacciati, correndo scivoli · Z a terra\nClick sx spara · Click dx mira · R ricarica · 1-4, rotellina o Q cambia arma · T aspetto (Matteo, Broski) · V visuale frontale · E sali in macchinina o sull'aeroplanino · Esc libera il mouse"
	help.modulate = Color(1, 1, 1, 0.75)

	_build_net_panel(root)
	_refresh()


## Pannello MULTIPLAYER in alto a destra: nome, il tuo IP, OSPITA, IP dell'amico + UNISCITI.
func _build_net_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -420.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	var st := _style(Color(0.35, 0.95, 0.4), 0.8, 2)
	st.content_margin_left = 16.0
	st.content_margin_right = 16.0
	st.content_margin_top = 12.0
	st.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", st)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_load_settings()
	var ips := Rete.local_ips()
	var title := Label.new()
	title.text = "MULTIPLAYER  ·  il tuo IP: %s" % (ips[0] if ips.size() > 0 else "nessuna rete")
	title.tooltip_text = "Tutti i tuoi IP: %s
Gli amici sulla stessa rete scrivono questo IP e premono UNISCITI" % ", ".join(ips)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.35, 0.95, 0.4))
	box.add_child(title)

	_name_edit = _edit(box, "Il tuo nome")
	if last_name == "":
		last_name = OS.get_environment("USERNAME").capitalize()
	_name_edit.text = last_name
	_name_edit.max_length = 16

	var host_btn := _button(box, Vector2(0, 46))
	host_btn.text = "OSPITA PARTITA"
	host_btn.pressed.connect(_host)
	_net_btns.append(host_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_ip_edit = _edit(row, "IP di chi ospita")
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text = last_ip
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _join())
	var join_btn := _button(row, Vector2(130, 46))
	join_btn.text = "UNISCITI"
	join_btn.pressed.connect(_join)
	_net_btns.append(join_btn)

	# partite trovate sulla rete: un pulsante per ognuna
	_found_box = VBoxContainer.new()
	_found_box.add_theme_constant_override("separation", 6)
	box.add_child(_found_box)

	var ver := Label.new()
	ver.text = "versione del gioco: %s" % Rete.version()
	ver.add_theme_font_size_override("font_size", 13)
	ver.modulate = Color(1, 1, 1, 0.55)
	box.add_child(ver)

	_listen = PacketPeerUDP.new()
	if _listen.bind(Rete.BEACON_PORT) != OK:
		_listen = null                # porta occupata (altra copia del gioco nel menu): pazienza

	_net_status = Label.new()
	_net_status.add_theme_font_size_override("font_size", 15)
	_net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_net_status.custom_minimum_size = Vector2(340, 0)
	_net_status.visible = false
	box.add_child(_net_status)


func _process(_delta: float) -> void:
	if _listen == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	while _listen.get_available_packet_count() > 0:
		var parts := _listen.get_packet().get_string_from_utf8().split("|")
		var ip := _listen.get_packet_ip()
		if parts.size() < 4 or parts[0] != Rete.BEACON_TAG or ip == "":
			continue
		if not _found.has(ip):
			var b := _button(_found_box, Vector2(0, 46))
			b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(func() -> void:
				_ip_edit.text = ip
				_join())
			_net_btns.append(b)
			_found[ip] = {"btn": b}
		var f: Dictionary = _found[ip]
		f["t"] = now
		var same := parts[1] == Rete.version()
		(f["btn"] as Button).text = "ENTRA: partita di %s  (%s giocatori)%s" % [parts[2], parts[3], "" if same else "  ⚠ versione diversa"]
		if _ip_edit.text.strip_edges() == "":
			_ip_edit.text = ip
	for ip in _found.keys():                          # partite chiuse: via il pulsante
		if now - float(_found[ip]["t"]) > 4.0:
			var b: Button = _found[ip]["btn"]
			_net_btns.erase(b)
			b.queue_free()
			_found.erase(ip)


func _exit_tree() -> void:
	if _listen:
		_listen.close()


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	if last_name == "":
		last_name = String(cf.get_value("rete", "nome", ""))
	if last_ip == "":
		last_ip = String(cf.get_value("rete", "ip", ""))


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("rete", "nome", last_name)
	cf.set_value("rete", "ip", last_ip)
	cf.save(SAVE)


func _edit(parent: Control, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 44)
	e.add_theme_font_size_override("font_size", 18)
	e.add_theme_stylebox_override("normal", _style(Color(0.5, 0.5, 0.55), 0.9, 2))
	e.add_theme_stylebox_override("focus", _style(Color(0.35, 0.95, 0.4), 0.95, 2))
	parent.add_child(e)
	return e


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = String(Characters.LIST[index]["name"])
	last_name = n
	return n


func _host() -> void:
	set_net_status("Apro la partita...")
	var n := _player_name()
	_save_settings()
	host_game.emit(index, weapon, style_of(index), n)


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		set_net_status("Scrivi l'IP di chi ospita (lo vede nel suo menu)")
		_ip_edit.grab_focus()
		return
	last_ip = ip
	var n := _player_name()
	_save_settings()
	set_net_status("Mi collego a %s..." % ip)
	_net_status.visible = true
	for b in _net_btns:
		b.disabled = true
	join_game.emit(index, weapon, style_of(index), n, ip)


## Messaggio sotto i pulsanti del multiplayer (riattiva i pulsanti: il tentativo è finito).
func set_net_status(text: String) -> void:
	_net_status.text = text
	_net_status.visible = text != ""
	for b in _net_btns:
		b.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var n := Characters.LIST.size()
	var key: int = event.keycode
	# tasti numerici 1..9 = personaggio corrispondente
	if key >= KEY_1 and key <= KEY_9 and key - KEY_1 < n:
		select(key - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if key >= KEY_KP_1 and key <= KEY_KP_9 and key - KEY_KP_1 < n:
		select(key - KEY_KP_1)
		get_viewport().set_input_as_handled()
		return
	var nw := Weapons.LIST.size()
	match key:
		KEY_E, KEY_DOWN:
			select_weapon((weapon + 1) % nw)
		KEY_Q, KEY_UP:
			select_weapon((weapon + nw - 1) % nw)
		KEY_LEFT, KEY_A:
			select((index + n - 1) % n)
		KEY_RIGHT, KEY_D:
			select((index + 1) % n)
		KEY_T:
			toggle_style()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_play()
		_:
			return
	get_viewport().set_input_as_handled()


func select(i: int) -> void:
	index = i
	_refresh()
	selected.emit(i)


func select_weapon(w: int) -> void:
	weapon = w
	_refresh()
	weapon_selected.emit(w)


## Stile del personaggio i: "blender" (default) o "minecraft"; "" per chi non è una persona vera
## o non ha una versione Minecraft (es. ANTONINO, che è solo la scansione 3D).
func style_of(i: int) -> String:
	if not Characters.LIST[i].has("look") or not LooksMinecraft.LOOKS.has(Characters.LIST[i]["look"]):
		return ""
	return String(stili.get(i, "blender"))


func toggle_style() -> void:
	if style_of(index) == "":
		return
	stili[index] = "minecraft" if style_of(index) == "blender" else "blender"
	_refresh()
	style_changed.emit(index, style_of(index))


func _play() -> void:
	start_game.emit(index, weapon, style_of(index))


func _refresh() -> void:
	for i in _cards.size():
		var accent: Color = Characters.LIST[i]["accent"]
		var on := i == index
		var b := _cards[i]
		b.add_theme_stylebox_override("normal", _style(accent if on else Color(0.35, 0.35, 0.4), 0.88 if on else 0.7, 4 if on else 2))
		b.add_theme_stylebox_override("hover", _style(accent if on else Color(0.6, 0.6, 0.65), 0.9, 4 if on else 3))
		b.add_theme_stylebox_override("pressed", _style(accent, 0.95, 4))
		b.scale = Vector2.ONE * (1.04 if on else 1.0)
	var acc: Color = Characters.LIST[index]["accent"]
	var dark := Color(0.05, 0.06, 0.08)
	for i in _weapon_btns.size():
		var on := i == weapon
		var wb := _weapon_btns[i]
		wb.add_theme_stylebox_override("normal", _style(acc if on else Color(0.35, 0.35, 0.4), 0.9 if on else 0.7, 4 if on else 2, acc.darkened(0.6) if on else dark))
		wb.add_theme_stylebox_override("hover", _style(acc if on else Color(0.6, 0.6, 0.65), 0.9, 4 if on else 3, acc.darkened(0.5) if on else dark))
		wb.add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.7))
	var st := style_of(index)
	_style_btn.visible = st != ""
	_style_btn.text = "ASPETTO:  %s  (T)" % st.to_upper()
	_style_btn.add_theme_stylebox_override("normal", _style(acc, 0.9, 2, dark))
	_style_btn.add_theme_stylebox_override("hover", _style(acc, 0.95, 3, acc.darkened(0.6)))
	_play_btn.add_theme_stylebox_override("normal", _style(acc, 0.9, 3, acc.darkened(0.55)))
	_play_btn.add_theme_stylebox_override("hover", _style(acc, 0.95, 4, acc.darkened(0.4)))
	_play_btn.add_theme_stylebox_override("pressed", _style(acc, 1.0, 4, acc.darkened(0.3)))


func _make_card(i: int) -> Button:
	var d: Dictionary = Characters.LIST[i]
	var accent: Color = d["accent"]
	var b := Button.new()
	# le schede si stringono quando i personaggi sono tanti (devono stare in 1600 px)
	var count := Characters.LIST.size()
	var w := minf(300.0, floorf((1560.0 - 24.0 * (count - 1)) / count))
	b.custom_minimum_size = Vector2(w, 70)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(w / 2.0, 35)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(select.bind(i))
	b.text = "%d  %s" % [i + 1, d["name"]]
	b.add_theme_font_size_override("font_size", 28)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, accent)
	return b


func _button(parent: Control, min_size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", _style(Color(0.5, 0.5, 0.55), 0.8, 2))
	b.add_theme_stylebox_override("hover", _style(Color(0.8, 0.8, 0.85), 0.85, 2))
	b.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1), 0.9, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b


func _label(parent: Control, font_size: int, h: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.horizontal_alignment = h
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _style(border: Color, alpha: float, width: int, bg := Color(0.05, 0.06, 0.08)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg.r, bg.g, bg.b, alpha)
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(12)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	return s
