class_name ControlPanel
extends PanelContainer
## Lab controls. Shown on a 3D screen in VR and as an overlay on desktop. Emits SI values;
## kN <-> N conversion happens here.

signal section_selected(index: int)
signal material_selected(index: int)
signal load_changed(newtons: float)
signal load_position_changed(meters: float)
signal exaggeration_changed(factor: float)
signal color_scale_changed(relative_to_yield: bool)

const DEFAULT_EXAGGERATION: float = 50.0
const DESKTOP_HINT: String = "WASD / Q E move · hold right mouse to look · "\
		+ "drag the yellow knob (or ← →) to move the load · Tab hides this panel · F12 screenshot"

var _section_buttons: Array[Button] = []
var _material_buttons: Array[Button] = []
var _load_label: Label = Label.new()
var _load_slider: HSlider = HSlider.new()
var _position_label: Label = Label.new()
var _position_slider: HSlider = HSlider.new()
var _exaggeration_label: Label = Label.new()
var _exaggeration_slider: HSlider = HSlider.new()


func setup(section_names: PackedStringArray, material_names: PackedStringArray,
		length: float, min_load: float, max_load: float, desktop: bool) -> void:
	theme = _make_theme(16 if desktop else 22)
	# Desktop: two columns in a short strip along the bottom of the window. VR: one column.
	var columns: BoxContainer = HBoxContainer.new() if desktop else VBoxContainer.new()
	columns.add_theme_constant_override("separation", 24 if desktop else 8)
	add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column: VBoxContainer in [left, right]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)

	left.add_child(_heading("MMLabVR · Simply supported beam"))
	left.add_child(_heading("Cross-section"))
	left.add_child(_button_grid(section_names, _section_buttons, 4 if desktop else 2))
	for i: int in _section_buttons.size():
		_section_buttons[i].pressed.connect(section_selected.emit.bind(i))
	left.add_child(_heading("Material"))
	left.add_child(_button_grid(material_names, _material_buttons, 3))
	for i: int in _material_buttons.size():
		_material_buttons[i].pressed.connect(material_selected.emit.bind(i))
	left.add_child(_heading("Stress colors: full color at"))
	var scale_buttons: Array[Button] = []
	left.add_child(_button_grid(PackedStringArray(["±σ_max (auto)", "±σ_Y (yield)"]), scale_buttons, 2))
	scale_buttons[0].button_pressed = true
	scale_buttons[0].pressed.connect(color_scale_changed.emit.bind(false))
	scale_buttons[1].pressed.connect(color_scale_changed.emit.bind(true))

	right.add_child(_load_label)
	_setup_slider(_load_slider, min_load / 1.0e3, max_load / 1.0e3, 0.5, right)
	_load_slider.value_changed.connect(func(kn: float) -> void: load_changed.emit(kn * 1.0e3))
	right.add_child(_position_label)
	_setup_slider(_position_slider, 0.0, length, 0.01, right)
	_position_slider.value_changed.connect(load_position_changed.emit)
	right.add_child(_exaggeration_label)
	_setup_slider(_exaggeration_slider, 1.0, 500.0, 1.0, right)
	_exaggeration_slider.exp_edit = true
	_exaggeration_slider.value_changed.connect(exaggeration_changed.emit)
	_exaggeration_slider.value = DEFAULT_EXAGGERATION

	if desktop:
		var hint := Label.new()
		hint.text = DESKTOP_HINT
		hint.add_theme_font_size_override("font_size", 13)
		hint.modulate = Color(0.75, 0.8, 0.9)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(hint)


## Reflects the model state without re-emitting signals.
func show_beam(beam: SimplySupportedBeam, section_index: int, material_index: int) -> void:
	for i: int in _section_buttons.size():
		_section_buttons[i].set_pressed_no_signal(i == section_index)
	for i: int in _material_buttons.size():
		_material_buttons[i].set_pressed_no_signal(i == material_index)
	_load_slider.set_value_no_signal(beam.load / 1.0e3)
	_position_slider.set_value_no_signal(beam.load_position)
	_load_label.text = "Load P = " + Units.force(beam.load)
	_position_label.text = "Load position a = " + Units.length(beam.load_position)


func show_exaggeration(requested: float, shown: float) -> void:
	_exaggeration_label.text = "Deflection exaggeration ×%.0f" % requested
	if shown < requested:
		_exaggeration_label.text += "  (drawn at ×%.1f to fit)" % shown


## Grid of toggle buttons of which only one can be pressed; appends them to buttons.
static func _button_grid(names: PackedStringArray, buttons: Array[Button], columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	var group := ButtonGroup.new()
	for i: int in names.size():
		var button := Button.new()
		button.text = names[i]
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(button)
		grid.add_child(button)
	return grid


static func _setup_slider(slider: HSlider, lo: float, hi: float, step: float, parent: Control) -> void:
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size.y = 30
	parent.add_child(slider)


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	return label


## Large controls so the laser pointer can hit them in VR.
static func _make_theme(font_size: int) -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", panel)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.3, 0.33, 0.4)
	groove.set_content_margin_all(5)
	t.set_stylebox("slider", "HSlider", groove)
	var filled := groove.duplicate() as StyleBoxFlat
	filled.bg_color = Color(0.3, 0.6, 0.95)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber: ImageTexture = _disc_texture(28, Color(0.95, 0.95, 1.0))
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	return t


static func _disc_texture(size: int, color: Color) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	for y: int in size:
		for x: int in size:
			var inside: float = clampf(size / 2.0 - Vector2(x + 0.5, y + 0.5).distance_to(center), 0.0, 1.0)
			image.set_pixel(x, y, Color(color, inside))
	return ImageTexture.create_from_image(image)
