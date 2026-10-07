class_name InputSetup
extends RefCounted
## Registers desktop keyboard actions in code. Physical keycodes keep WASD in the same
## place on AZERTY keyboards.

const KEY_ACTIONS: Dictionary[String, Array] = {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_up": [KEY_E],
	"move_down": [KEY_Q],
	"sprint": [KEY_SHIFT],
	"load_left": [KEY_LEFT],
	"load_right": [KEY_RIGHT],
	"toggle_panel": [KEY_TAB],
	"screenshot": [KEY_F12],
}


static func register() -> void:
	for action: String in KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in KEY_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
