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
	"turn_left": [KEY_LEFT],
	"turn_right": [KEY_RIGHT],
	"look_up": [KEY_UP],
	"look_down": [KEY_DOWN],
	"reset_view": [KEY_R],
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


## The key cap printed on the user's keyboard for an action (e.g. "Z" for move_forward on AZERTY).
static func key_label(action: String) -> String:
	var key := InputMap.action_get_events(action)[0] as InputEventKey
	var printed: Key = DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
	return OS.get_keycode_string(printed if printed != KEY_NONE else key.physical_keycode)
