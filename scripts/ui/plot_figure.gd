class_name PlotFigure
extends Control
## A small 2D chart drawn with _draw: lines, filled areas, circles, markers and reference
## lines, with automatic "nice" axis ticks. Data are in display units (MPa, mm, ...).

const MARGIN_LEFT: float = 64.0
const MARGIN_RIGHT: float = 16.0
const MARGIN_TOP: float = 30.0
const MARGIN_BOTTOM: float = 40.0
const AXIS_COLOR := Color(0.75, 0.78, 0.85)
const GRID_COLOR := Color(1, 1, 1, 0.07)
const TEXT_COLOR := Color(0.9, 0.92, 0.95)

var title: String = ""
var x_label: String = ""
var y_label: String = ""
## Keep 1:1 data scaling (needed for Mohr's circle).
var equal_aspect: bool = false
## Plot y downward-positive data upward-negative (beam deflections hang down).
var flip_y: bool = false

var _lines: Array[Dictionary] = []
var _circles: Array[Dictionary] = []
var _markers: Array[Dictionary] = []
var _vlines: Array[Dictionary] = []
var _hlines: Array[Dictionary] = []
var _range := Rect2()
var _fixed_range: bool = false
var _font_size: int = 15


func _init(font_size: int = 15) -> void:
	_font_size = font_size
	custom_minimum_size = Vector2(300, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func begin(p_title: String, p_x_label: String, p_y_label: String) -> void:
	title = p_title
	x_label = p_x_label
	y_label = p_y_label
	equal_aspect = false
	flip_y = false
	_fixed_range = false
	_lines.clear()
	_circles.clear()
	_markers.clear()
	_vlines.clear()
	_hlines.clear()
	queue_redraw()


func set_range(x0: float, x1: float, y0: float, y1: float) -> void:
	_range = Rect2(x0, y0, x1 - x0, y1 - y0)
	_fixed_range = true


func line(points: PackedVector2Array, color: Color, width: float = 2.5, fill: bool = false) -> void:
	_lines.append({"points": points, "color": color, "width": width, "fill": fill})


func circle(center: Vector2, radius: float, color: Color) -> void:
	_circles.append({"center": center, "radius": radius, "color": color})


func marker(point: Vector2, color: Color, text: String = "") -> void:
	_markers.append({"point": point, "color": color, "text": text})


func vline(x: float, color: Color, text: String = "") -> void:
	_vlines.append({"x": x, "color": color, "text": text})


func hline(y: float, color: Color, text: String = "") -> void:
	_hlines.append({"y": y, "color": color, "text": text})


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var area := Rect2(MARGIN_LEFT, MARGIN_TOP, size.x - MARGIN_LEFT - MARGIN_RIGHT,
			size.y - MARGIN_TOP - MARGIN_BOTTOM)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.9))
	draw_string(font, Vector2(MARGIN_LEFT, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size + 1, TEXT_COLOR)
	if area.size.x <= 10.0 or area.size.y <= 10.0:
		return
	var r: Rect2 = _range if _fixed_range else _auto_range()
	if equal_aspect:
		r = _equalize(r, area.size)
	var to_px := func(p: Vector2) -> Vector2:
		var t := Vector2((p.x - r.position.x) / r.size.x, (p.y - r.position.y) / r.size.y)
		if flip_y:
			t.y = 1.0 - t.y
		return Vector2(area.position.x + t.x * area.size.x, area.end.y - t.y * area.size.y)

	for tick: float in _ticks(r.position.x, r.end.x):
		var px: float = to_px.call(Vector2(tick, r.position.y)).x
		draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), GRID_COLOR)
		draw_string(font, Vector2(px - 30, area.end.y + 16), _fmt(tick), HORIZONTAL_ALIGNMENT_CENTER, 60, _font_size - 2, AXIS_COLOR)
	for tick: float in _ticks(r.position.y, r.end.y):
		var py: float = to_px.call(Vector2(r.position.x, tick)).y
		draw_line(Vector2(area.position.x, py), Vector2(area.end.x, py), GRID_COLOR)
		draw_string(font, Vector2(2, py + 5), _fmt(tick), HORIZONTAL_ALIGNMENT_RIGHT, MARGIN_LEFT - 6, _font_size - 2, AXIS_COLOR)
	# Zero axes when in range, otherwise the frame edges.
	var origin: Vector2 = to_px.call(Vector2(clampf(0.0, r.position.x, r.end.x), clampf(0.0, r.position.y, r.end.y)))
	draw_line(Vector2(area.position.x, origin.y), Vector2(area.end.x, origin.y), AXIS_COLOR, 1.5)
	draw_line(Vector2(origin.x, area.position.y), Vector2(origin.x, area.end.y), AXIS_COLOR, 1.5)
	draw_string(font, Vector2(area.position.x, size.y - 4), x_label, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x, _font_size - 1, TEXT_COLOR)
	draw_string(font, Vector2(MARGIN_LEFT + 4, MARGIN_TOP + 12), y_label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size - 1, TEXT_COLOR)

	for c: Dictionary in _circles:
		var center: Vector2 = to_px.call(c.center)
		var edge: Vector2 = to_px.call(c.center + Vector2(c.radius, 0.0))
		draw_arc(center, absf(edge.x - center.x), 0.0, TAU, 96, c.color, 2.0, true)
	for l: Dictionary in _lines:
		var px_points := PackedVector2Array()
		for p: Vector2 in l.points:
			px_points.append(to_px.call(p))
		if l.fill and px_points.size() > 1:
			var poly := px_points.duplicate()
			poly.append(Vector2(px_points[-1].x, origin.y))
			poly.append(Vector2(px_points[0].x, origin.y))
			var fill_color: Color = l.color
			fill_color.a = 0.25
			_draw_filled(poly, fill_color)
		if px_points.size() > 1:
			draw_polyline(px_points, l.color, l.width, true)
	for v: Dictionary in _vlines:
		var px: float = to_px.call(Vector2(v.x, 0)).x
		draw_dashed_line(Vector2(px, area.position.y), Vector2(px, area.end.y), v.color, 1.5, 6.0)
		draw_string(font, Vector2(px + 4, area.position.y + 14), v.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size - 2, v.color)
	for h: Dictionary in _hlines:
		var py: float = to_px.call(Vector2(0, h.y)).y
		draw_dashed_line(Vector2(area.position.x, py), Vector2(area.end.x, py), h.color, 1.5, 6.0)
		draw_string(font, Vector2(area.end.x - 220, py - 4), h.text, HORIZONTAL_ALIGNMENT_RIGHT, 216, _font_size - 2, h.color)
	for m: Dictionary in _markers:
		var p: Vector2 = to_px.call(m.point)
		draw_circle(p, 6.0, m.color)
		draw_string(font, p + Vector2(8, -8), m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size - 1, m.color)


## Area between the curve and the axis, drawn as two triangles per segment so curves that
## cross the axis or jump vertically still fill correctly.
func _draw_filled(poly: PackedVector2Array, color: Color) -> void:
	var n: int = poly.size() - 2
	var axis_y: float = poly[n].y
	for i: int in n - 1:
		var p0: Vector2 = poly[i]
		var p1: Vector2 = poly[i + 1]
		var b0 := Vector2(p0.x, axis_y)
		var b1 := Vector2(p1.x, axis_y)
		for tri: PackedVector2Array in [PackedVector2Array([p0, p1, b1]), PackedVector2Array([p0, b1, b0])]:
			if absf((tri[1] - tri[0]).cross(tri[2] - tri[0])) > 0.5:
				draw_colored_polygon(tri, color)


func _auto_range() -> Rect2:
	var pts := PackedVector2Array([Vector2.ZERO])  # keep the origin's axes in view
	for l: Dictionary in _lines:
		pts.append_array(l.points)
	for c: Dictionary in _circles:
		pts.append(c.center - Vector2.ONE * c.radius)
		pts.append(c.center + Vector2.ONE * c.radius)
	for m: Dictionary in _markers:
		pts.append(m.point)
	for v: Dictionary in _vlines:
		pts.append(Vector2(v.x, 0.0))
	for h: Dictionary in _hlines:
		pts.append(Vector2(pts[-1].x, h.y))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(p)
	if r.size.x <= 0.0:
		r = r.grow_individual(1.0, 0.0, 1.0, 0.0)
	if r.size.y <= 0.0:
		r = r.grow_individual(0.0, 1.0, 0.0, 1.0)
	return r.grow_individual(r.size.x * 0.03, r.size.y * 0.12, r.size.x * 0.03, r.size.y * 0.12)


func _equalize(r: Rect2, px: Vector2) -> Rect2:
	var scale: float = maxf(r.size.x / px.x, r.size.y / px.y)
	var c: Vector2 = r.get_center()
	var half := Vector2(px.x, px.y) * scale / 2.0
	return Rect2(c - half, half * 2.0)


static func _ticks(lo: float, hi: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var span: float = hi - lo
	if span <= 0.0:
		return out
	var raw: float = span / 5.0
	var mag: float = pow(10.0, floor(log(raw) / log(10.0)))
	var stepv: float = mag
	for f: float in [1.0, 2.0, 5.0, 10.0]:
		if raw <= f * mag:
			stepv = f * mag
			break
	var t: float = ceil(lo / stepv) * stepv
	while t <= hi + stepv * 1e-6:
		out.append(0.0 if absf(t) < stepv * 1e-6 else t)
		t += stepv
	return out


static func _fmt(v: float) -> String:
	var a: float = absf(v)
	if a == 0.0:
		return "0"
	if a >= 100.0:
		return "%.0f" % v
	if a >= 1.0:
		return String.num(v, 1).trim_suffix(".0")
	if a >= 0.01:
		return String.num(v, 3)
	return "%.1e" % v
