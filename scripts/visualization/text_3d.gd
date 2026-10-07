class_name Text3D
extends RefCounted
## Readable floating labels: outlined, optionally always facing the viewer.


static func make(font_size: int = 36, billboard: bool = true, color := Color(0.96, 0.96, 0.98)) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.002
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = billboard
	label.render_priority = 2
	label.double_sided = true
	return label
