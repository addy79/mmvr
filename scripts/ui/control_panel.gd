class_name ControlPanel
extends PanelContainer
## Topic picker plus the current station's inputs, built from its ControlSpecs. Shown on a
## 3D screen in VR and docked on the left on desktop. Slider values are in display units;
## ControlSpec converts to SI.

signal topic_selected(index: int)
signal control_changed(id: StringName, si_value: float)

var _topic_buttons: Array[Button] = []
var _rows: VBoxContainer = VBoxContainer.new()
var _station_title: Label = Label.new()
var _captions: Dictionary[StringName, Label] = {}
var _row_boxes: Dictionary[StringName, VBoxContainer] = {}
var _sliders: Dictionary[StringName, HSlider] = {}
var _choices: Dictionary[StringName, Array] = {}


func setup(topic_titles: PackedStringArray, font_size: int, hint: String) -> void:
	theme = LabTheme.make(font_size)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	box.add_child(_heading("MMLabVR · Mechanics of Materials"))
	var grid := GridContainer.new()
	grid.columns = 2
	var group := ButtonGroup.new()
	for i: int in topic_titles.size():
		var b := Button.new()
		b.text = topic_titles[i]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(topic_selected.emit.bind(i))
		_topic_buttons.append(b)
		grid.add_child(b)
	box.add_child(grid)
	box.add_child(HSeparator.new())
	_station_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	box.add_child(_station_title)
	_rows.add_theme_constant_override("separation", 4)
	box.add_child(_rows)
	if not hint.is_empty():
		box.add_child(HSeparator.new())
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.add_theme_font_size_override("font_size", font_size - 3)
		hint_label.modulate = Color(0.75, 0.8, 0.9)
		box.add_child(hint_label)


## Rebuilds the input rows for a newly selected station.
func show_station(station: Station, index: int) -> void:
	for i: int in _topic_buttons.size():
		_topic_buttons[i].set_pressed_no_signal(i == index)
	_station_title.text = "Chapter %d · %s" % [station.chapter, station.title]
	for child: Node in _rows.get_children():
		child.queue_free()
	_captions.clear()
	_row_boxes.clear()
	_sliders.clear()
	_choices.clear()
	for c: ControlSpec in station.controls():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_rows.add_child(row)
		_row_boxes[c.id] = row
		var caption := Label.new()
		row.add_child(caption)
		_captions[c.id] = caption
		if c.kind == ControlSpec.Kind.SLIDER:
			var slider := HSlider.new()
			slider.min_value = c.min_display
			slider.max_value = c.max_display
			slider.step = c.step_display
			slider.custom_minimum_size.y = 28
			slider.value = c.display_value()
			slider.value_changed.connect(func(v: float) -> void: control_changed.emit(c.id, v / c.display_scale))
			row.add_child(slider)
			_sliders[c.id] = slider
		else:
			var grid := GridContainer.new()
			grid.columns = mini(c.options.size(), 3)
			var group := ButtonGroup.new()
			var buttons: Array[Button] = []
			for i: int in c.options.size():
				var b := Button.new()
				b.text = c.options[i]
				b.toggle_mode = true
				b.button_group = group
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(control_changed.emit.bind(c.id, float(i)))
				buttons.append(b)
				grid.add_child(b)
			row.add_child(grid)
			_choices[c.id] = buttons
	sync(station)


## Reflects current values (they may change from 3D knobs) without emitting signals.
func sync(station: Station) -> void:
	for c: ControlSpec in station.controls():
		if not _captions.has(c.id):
			continue
		_captions[c.id].text = c.caption()
		_row_boxes[c.id].visible = c.shown_in(station.step())
		if _sliders.has(c.id):
			_sliders[c.id].set_value_no_signal(c.display_value())
		elif _choices.has(c.id):
			var buttons: Array = _choices[c.id]
			for i: int in buttons.size():
				(buttons[i] as Button).set_pressed_no_signal(i == int(c.value))


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	return label
