class_name LessonPanel
extends PanelContainer
## The current station's lesson: step tabs, figures, and explanation text with the live
## numbers substituted into each equation. Re-rendered whenever the station changes.

signal step_selected(index: int)

var figures: FigureArea
var _title: Label = Label.new()
var _steps: HFlowContainer = HFlowContainer.new()
var _text: RichTextLabel = RichTextLabel.new()
var _prev: Button = Button.new()
var _next: Button = Button.new()
var _step_buttons: Array[Button] = []
var _station: Station
var _scroll: ScrollContainer


func setup(font_size: int) -> void:
	theme = LabTheme.make(font_size)
	figures = FigureArea.new(font_size - 2)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_title.add_theme_font_size_override("font_size", font_size + 4)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_steps.add_theme_constant_override("h_separation", 4)
	_steps.add_theme_constant_override("v_separation", 4)
	box.add_child(_steps)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_scroll = scroll
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	content.add_child(figures)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", font_size)
	_text.add_theme_font_size_override("bold_font_size", font_size)
	_text.add_theme_font_size_override("italics_font_size", font_size)
	content.add_child(_text)
	var nav := HBoxContainer.new()
	_prev.text = "◀ Previous"
	_next.text = "Next ▶"
	for b: Button in [_prev, _next]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
	_prev.pressed.connect(func() -> void: step_selected.emit(_station.step() - 1))
	_next.pressed.connect(func() -> void: step_selected.emit(_station.step() + 1))
	box.add_child(nav)


func show_station(station: Station) -> void:
	_station = station
	for b: Button in _step_buttons:
		b.queue_free()
	_step_buttons.clear()
	var group := ButtonGroup.new()
	var titles: PackedStringArray = station.step_titles()
	for i: int in titles.size():
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, titles[i]]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(step_selected.emit.bind(i))
		_step_buttons.append(b)
		_steps.add_child(b)
	refresh()


## Scrolls the lesson body (VR thumbstick), in pixels.
func scroll_by(pixels: float) -> void:
	_scroll.scroll_vertical += int(pixels)


## Re-renders the text and figures of the station's current step.
func refresh() -> void:
	var s: int = _station.step()
	var titles: PackedStringArray = _station.step_titles()
	_title.text = "%s — %s" % [_station.heading(), titles[s]]
	for i: int in _step_buttons.size():
		_step_buttons[i].set_pressed_no_signal(i == s)
	_prev.disabled = s == 0
	_next.disabled = s == titles.size() - 1
	_text.text = _station.lesson_text()
	figures.begin()
	_station.fill_figures(figures)
	figures.end()
