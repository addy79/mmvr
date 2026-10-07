class_name Station
extends Node3D
## One chapter's lab bench. A station owns its physics model and 3D scene, declares its
## inputs (ControlSpec) and its lesson (steps of BBCode text plus figures). Inputs arrive via
## set_control (panel) or the station's own knobs; either way `changed` is emitted once.

signal changed

var chapter: int = 0
var title: String = ""
var _controls: Array[ControlSpec] = []
var _step: int = 0


func controls() -> Array[ControlSpec]:
	return _controls


func control(id: StringName) -> ControlSpec:
	for c: ControlSpec in _controls:
		if c.id == id:
			return c
	push_error("Unknown control " + id)
	return null


## Value of a control (SI units, or option index).
func value(id: StringName) -> float:
	return control(id).value


func set_control(id: StringName, new_value: float) -> void:
	var c: ControlSpec = control(id)
	if c.kind == ControlSpec.Kind.SLIDER:
		new_value = clampf(new_value, c.min_display / c.display_scale, c.max_display / c.display_scale)
	if is_equal_approx(c.value, new_value):
		return
	c.value = new_value
	_apply()
	changed.emit()


func step() -> int:
	return _step


func set_step(index: int) -> void:
	_step = clampi(index, 0, step_titles().size() - 1)
	_show_step()
	changed.emit()


## Called after construction (in the tree) and after every input change.
func refresh() -> void:
	_apply()
	_show_step()


## --- Overridden by each station -------------------------------------------------------

## Push control values into the model and update the 3D scene.
func _apply() -> void:
	pass


## Show or hide the parts of the scene the current lesson step is about.
func _show_step() -> void:
	pass


func step_titles() -> PackedStringArray:
	return PackedStringArray()


## BBCode for the current step: explanation, live equations, "Try this".
func lesson_text() -> String:
	return ""


## Fill the lesson panel's plots for the current step (leave untouched to show none).
func fill_figures(_figures: FigureArea) -> void:
	pass


## World points the desktop camera should keep in view.
func frame_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-2, 0.5, 0), Vector3(2, 2.2, 0)])
