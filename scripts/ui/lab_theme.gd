class_name LabTheme
extends RefCounted
## Shared look of the 2D panels: dark, high contrast, large hit targets for the VR laser.


static func make(font_size: int) -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.09, 0.13, 0.94)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.3, 0.33, 0.4)
	groove.set_content_margin_all(4)
	t.set_stylebox("slider", "HSlider", groove)
	var filled := groove.duplicate() as StyleBoxFlat
	filled.bg_color = Color(0.3, 0.6, 0.95)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber: ImageTexture = _disc_texture(int(font_size * 1.3), Color(0.95, 0.95, 1.0))
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {
			"normal": Color(0.14, 0.17, 0.23), "hover": Color(0.2, 0.25, 0.33),
			"pressed": Color(0.18, 0.42, 0.75), "hover_pressed": Color(0.22, 0.48, 0.82),
			"focus": Color(0, 0, 0, 0)}[state]
		box.set_corner_radius_all(6)
		box.set_content_margin_all(6)
		if state == "focus":
			box.draw_center = false
		t.set_stylebox(state, "Button", box)
	return t


static func _disc_texture(size: int, color: Color) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	for y: int in size:
		for x: int in size:
			var inside: float = clampf(size / 2.0 - Vector2(x + 0.5, y + 0.5).distance_to(center), 0.0, 1.0)
			image.set_pixel(x, y, Color(color, inside))
	return ImageTexture.create_from_image(image)
