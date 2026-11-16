extends CanvasLayer
## Interfaccia: barra della vita in alto, mirino, munizioni, messaggi.

var _root: Control
var _hp: Label
var _hp_bg: Panel
var _hp_fill: Panel
var _hp_shown := 100.0
var _hp_target := 100.0
const HP_W := 420.0
var _ammo: Label
var _weapon: Label
var _msg: Label
var _hitmark: Label
var _hint: Label                 # in basso: "E sali sulla macchinina" oppure i comandi del veicolo
var _dmg: ColorRect
var _cross: Control
var _bars: Array[ColorRect] = []
var _msg_t := 0.0
var _hit_t := 0.0
var _gap := 8.0


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dmg = ColorRect.new()
	_dmg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg.color = Color(0.8, 0.0, 0.0, 0.0)
	_dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dmg)

	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cross)
	for i in 4:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.9)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross.add_child(r)
		_bars.append(r)
	_layout_cross()

	_hitmark = _label(30, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_hitmark.text = "X"
	_hitmark.visible = false
	_build_health_bar()
	_ammo = _label(40, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_weapon = _label(22, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_weapon.offset_bottom = -68.0
	_weapon.modulate = Color(1, 1, 1, 0.85)
	_msg = _label(34, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_msg.offset_bottom = -220.0
	_hint = _label(24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_hint.offset_bottom = -110.0
	_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	var title := _label(20, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	title.text = "MauroSlime  v0.4 · bozza · %s" % preload("res://scripts/game/rete.gd").version()
	title.modulate = Color(1, 1, 1, 0.6)

	set_health(100.0)
	set_ammo(30, 180, false)


## Barra della vita in alto al centro: fondo scuro, riempimento verde -> giallo -> rosso, numero sopra.
func _build_health_bar() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -HP_W / 2.0
	holder.offset_right = HP_W / 2.0
	holder.offset_top = 18.0
	holder.offset_bottom = 18.0 + 34.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	_hp_bg = Panel.new()
	_hp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07, 0.7)
	bg.border_color = Color(1, 1, 1, 0.8)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	_hp_bg.add_theme_stylebox_override("panel", bg)
	holder.add_child(_hp_bg)
	_hp_fill = Panel.new()
	_hp_fill.position = Vector2(4, 4)
	_hp_fill.size = Vector2(HP_W - 8, 26)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.3, 0.9, 0.35)
	fs.set_corner_radius_all(6)
	_hp_fill.add_theme_stylebox_override("panel", fs)
	holder.add_child(_hp_fill)
	_hp = Label.new()
	_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp.add_theme_font_size_override("font_size", 20)
	_hp.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp.add_theme_constant_override("outline_size", 6)
	holder.add_child(_hp)


func _label(font_size: int, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 30.0
	l.offset_right = -30.0
	l.offset_top = 20.0
	l.offset_bottom = -20.0
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_root.add_child(l)
	return l


func _process(delta: float) -> void:
	if absf(_hp_shown - _hp_target) > 0.05:
		_hp_shown = lerpf(_hp_shown, _hp_target, clampf(delta * 10.0, 0.0, 1.0))
		_draw_health()
	if _dmg.color.a > 0.0:
		_dmg.color.a = maxf(_dmg.color.a - delta * 1.2, 0.0)
	if _hit_t > 0.0:
		_hit_t -= delta
		_hitmark.visible = _hit_t > 0.0
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""


func update_crosshair(spread: float) -> void:
	var g := 6.0 + spread * 400.0
	if absf(g - _gap) > 0.3:
		_gap = lerpf(_gap, g, 0.3)
		_layout_cross()


func _layout_cross() -> void:
	var l := 10.0
	_bars[0].position = Vector2(_gap, -1)
	_bars[0].size = Vector2(l, 2)
	_bars[1].position = Vector2(-_gap - l, -1)
	_bars[1].size = Vector2(l, 2)
	_bars[2].position = Vector2(-1, _gap)
	_bars[2].size = Vector2(2, l)
	_bars[3].position = Vector2(-1, -_gap - l)
	_bars[3].size = Vector2(2, l)


func set_health(hp: float) -> void:
	_hp_target = clampf(hp, 0.0, 100.0)
	_hp.text = "VITA  %d" % int(ceil(hp))
	_draw_health()


func _draw_health() -> void:
	var k := _hp_shown / 100.0
	_hp_fill.size.x = maxf((HP_W - 8.0) * k, 0.0)
	_hp_fill.visible = k > 0.005
	var c := Color(0.3, 0.9, 0.35)
	if k < 0.35:
		c = Color(0.95, 0.25, 0.2)
	elif k < 0.65:
		c = Color(0.95, 0.8, 0.2)
	(_hp_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = c


func set_ammo(mag: int, reserve: int, reloading: bool) -> void:
	if reloading:
		_ammo.text = "RICARICA...   / %d" % reserve
	else:
		_ammo.text = "%d / %d" % [mag, reserve]
	_ammo.add_theme_color_override("font_color", Color(1, 0.8, 0.3) if mag <= 5 else Color.WHITE)


## Nome dell'arma in mano, sopra le munizioni (cambia con 1-4, rotellina o Q).
func set_weapon(weapon_name: String) -> void:
	_weapon.text = weapon_name


## Visuale frontale: il mirino al centro non ha senso (la telecamera guarda l'omino), quindi si nasconde.
func set_front_view(front: bool) -> void:
	_cross.visible = not front
	show_message("VISUALE FRONTALE  (V per tornare dietro)" if front else "", 1.5 if front else 0.0)


## Scritta in basso al centro (veicoli: "E sali sulla macchinina", comandi di guida). "" = niente.
func set_hint(text: String) -> void:
	_hint.text = text


## In macchinina o in aeroplanino non si spara: via il mirino e le munizioni.
func set_driving(on: bool) -> void:
	_cross.visible = not on
	_ammo.visible = not on
	_weapon.visible = not on


func show_message(text: String, duration := 0.0) -> void:
	_msg.text = text
	_msg_t = duration


func hit(killed: bool) -> void:
	_hit_t = 0.12
	_hitmark.visible = true
	_hitmark.add_theme_color_override("font_color", Color(1, 0.25, 0.25) if killed else Color.WHITE)


func damage_flash() -> void:
	_dmg.color.a = 0.35
