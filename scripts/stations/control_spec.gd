class_name ControlSpec
extends RefCounted
## One adjustable input of a station: a slider (value in SI, shown in display units) or a
## choice between named options (value = option index).

enum Kind { SLIDER, CHOICE }

var id: StringName
var label: String
var kind: Kind
var value: float              ## SI value, or option index for a choice
var unit: String = ""         ## display unit, e.g. "kN"
var display_scale: float = 1.0  ## display value = SI value * display_scale
var min_display: float = 0.0
var max_display: float = 1.0
var step_display: float = 0.01
var decimals: int = 2
var options: PackedStringArray = PackedStringArray()
## Lesson steps (0-based) where this input matters; empty = all steps.
var steps: PackedInt32Array = PackedInt32Array()


static func slider(p_id: StringName, p_label: String, p_unit: String, scale: float,
		lo: float, hi: float, step: float, si_value: float, p_decimals: int = 2) -> ControlSpec:
	var c := ControlSpec.new()
	c.id = p_id
	c.label = p_label
	c.kind = Kind.SLIDER
	c.unit = p_unit
	c.display_scale = scale
	c.min_display = lo
	c.max_display = hi
	c.step_display = step
	c.value = si_value
	c.decimals = p_decimals
	return c


static func choice(p_id: StringName, p_label: String, p_options: PackedStringArray, index: int) -> ControlSpec:
	var c := ControlSpec.new()
	c.id = p_id
	c.label = p_label
	c.kind = Kind.CHOICE
	c.options = p_options
	c.value = index
	return c


## Restricts the input to some lesson steps; returns self for chaining.
func only_in(step_list: Array[int]) -> ControlSpec:
	steps = PackedInt32Array(step_list)
	return self


func shown_in(step: int) -> bool:
	return steps.is_empty() or steps.has(step)


func display_value() -> float:
	return value * display_scale


## "Load P = 10.00 kN"
func caption() -> String:
	if kind == Kind.CHOICE:
		return label
	return "%s = %s %s" % [label, String.num(display_value(), decimals), unit]
