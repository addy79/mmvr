class_name FigureArea
extends VBoxContainer
## Holds the lesson's plots. A station asks for plot(0), plot(1)...; plots it doesn't use
## for the current step are hidden by end().

var _plots: Array[PlotFigure] = []
var _used: int = 0
var _font_size: int


func _init(font_size: int) -> void:
	_font_size = font_size
	add_theme_constant_override("separation", 6)


func begin() -> void:
	_used = 0


func plot(index: int) -> PlotFigure:
	while _plots.size() <= index:
		var p := PlotFigure.new(_font_size)
		_plots.append(p)
		add_child(p)
	_used = maxi(_used, index + 1)
	_plots[index].visible = true
	return _plots[index]


func end() -> void:
	for i: int in _plots.size():
		_plots[i].visible = i < _used
		_plots[i].queue_redraw()
	visible = _used > 0
