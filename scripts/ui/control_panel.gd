class_name ControlPanel
extends PanelContainer
## Topic picker (the chapters, then the lab experiments with their done / to-do status) plus
## the current station's inputs, built from its ControlSpecs. Shown on a 3D screen in VR and
## docked on the left on desktop. Slider values are in display units; ControlSpec converts to SI.
## Topic indices: chapters first, then one per lab entry.

signal topic_selected(index: int)
signal control_changed(id: StringName, si_value: float)

const DONE_COLOR := Color(0.5, 0.92, 0.55)
const TODO_COLOR := Color(1.0, 0.78, 0.4)

var _topic_buttons: Array[Button] = []
var _labs: Array[Dictionary] = []
var _lab_buttons: Array[Button] = []
var _lab_summary: Label = Label.new()
var _done_box: CheckBox = CheckBox.new()
var _current_lab: int = 0
var _topics: VBoxContainer = VBoxContainer.new()  ## chapter grid + lab list, can be folded away
var _fold: Button = Button.new()
var _fold_on_select: bool = false
var _rows: VBoxContainer = VBoxContainer.new()
var _station_title: Label = Label.new()
var _captions: Dictionary[StringName, Label] = {}
var _row_boxes: Dictionary[StringName, VBoxContainer] = {}
var _sliders: Dictionary[StringName, HSlider] = {}
var _choices: Dictionary[StringName, Array] = {}


## labs: one {number, title, available} per lab experiment; unavailable ones (no handout yet)
## are listed but cannot be opened. fold_on_select hides the lists once a topic is picked
## (VR, where the panel cannot show everything at once).
func setup(topic_titles: PackedStringArray, labs: Array[Dictionary], font_size: int, hint: String, fold_on_select: bool = false) -> void:
	_labs = labs
	_fold_on_select = fold_on_select
	theme = LabTheme.make(font_size)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	box.add_child(_heading("MMLabVR · Mechanics of Materials"))
	_fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fold.pressed.connect(func() -> void: _set_folded(_topics.visible))
	box.add_child(_fold)
	_topics.add_theme_constant_override("separation", 6)
	box.add_child(_topics)
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
	_topics.add_child(grid)
	_topics.add_child(HSeparator.new())
	_topics.add_child(_lab_summary)
	_lab_summary.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	var lab_list := VBoxContainer.new()
	lab_list.add_theme_constant_override("separation", 3)
	for i: int in labs.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not labs[i].available
		b.pressed.connect(topic_selected.emit.bind(topic_titles.size() + i))
		_lab_buttons.append(b)
		_topic_buttons.append(b)
		lab_list.add_child(b)
	_topics.add_child(lab_list)
	_set_folded(false)
	_refresh_labs()
	box.add_child(HSeparator.new())
	_station_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	box.add_child(_station_title)
	_done_box.text = "I have done this lab"
	_done_box.toggled.connect(func(on: bool) -> void:
		LabProgress.set_done(_current_lab, on)
		_refresh_labs())
	box.add_child(_done_box)
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
	if _fold_on_select:
		_set_folded(true)
	for i: int in _topic_buttons.size():
		_topic_buttons[i].set_pressed_no_signal(i == index)
	_station_title.text = station.heading()
	_current_lab = station.lab
	_done_box.visible = station.lab > 0
	_done_box.set_pressed_no_signal(station.lab > 0 and LabProgress.is_done(station.lab))
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
				b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # long names must not widen the panel
				b.tooltip_text = c.options[i]
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


## Lab list: "Lab 7 · Bending of beams · done" (green) or "· to do" (amber), and the count.
func _refresh_labs() -> void:
	var numbers := PackedInt32Array()
	for i: int in _labs.size():
		var lab: Dictionary = _labs[i]
		numbers.append(lab.number)
		var done: bool = LabProgress.is_done(lab.number)
		var b: Button = _lab_buttons[i]
		b.text = "Lab %d · %s · %s" % [lab.number, lab.title, "done" if done else "to do"]
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, DONE_COLOR if done else TODO_COLOR)
	var done_n: int = LabProgress.done_count(numbers)
	_lab_summary.text = "Lab experiments · %d done, %d to do" % [done_n, _labs.size() - done_n]


func _set_folded(folded: bool) -> void:
	_topics.visible = not folded
	_fold.text = "▶ Show chapters and labs" if folded else "▼ Hide chapters and labs"


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	return label
