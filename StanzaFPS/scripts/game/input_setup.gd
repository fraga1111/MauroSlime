extends RefCounted
## TASTI DEL GIOCO. Per cambiare un comando basta cambiare il tasto qui.
## Si usano i tasti FISICI (posizione sulla tastiera), quindi WASD funziona con qualsiasi layout.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"super_jump": [KEY_B],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],      # tenuto = accovacciato; premuto mentre corri = scivolata
	"prone": [KEY_Z],                 # premi una volta = a terra (strisci), di nuovo = in piedi
	"front_view": [KEY_V],            # visuale frontale sì/no
	"reload": [KEY_R],
	"weapon_next": [KEY_Q],           # arma successiva (anche rotellina del mouse)
	"weapon_1": [KEY_1, KEY_KP_1],    # evidenziatore   (l'ordine è quello di data/weapons.gd)
	"weapon_2": [KEY_2, KEY_KP_2],    # spillatrice
	"weapon_3": [KEY_3, KEY_KP_3],    # telefono
	"weapon_4": [KEY_4, KEY_KP_4],    # spillatrice a pinza
}

## Più tasti del mouse per la stessa azione: lista di pulsanti
const MOUSE := {
	"fire": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
	"sprint": [MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2],   # tasti laterali del mouse (pollice)
}


static func setup() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b in MOUSE[action]:
			var e := InputEventMouseButton.new()
			e.button_index = b
			if not InputMap.action_has_event(action, e):
				InputMap.action_add_event(action, e)
