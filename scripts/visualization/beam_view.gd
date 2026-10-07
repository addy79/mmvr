class_name BeamView
extends MeshInstance3D
## A prismatic member along local +X: procedural mesh for its section, displaced and
## stress-colored by beam_stress.gdshader from a BeamDataTexture. The parent's origin is
## the bottom fiber at x = 0, so the neutral axis sits c above it.

const SHADER: Shader = preload("res://shaders/beam_stress.gdshader")

var _material: ShaderMaterial = ShaderMaterial.new()
var _key: String = ""
var _drawn_deflection: float = 0.0


func _init(data: BeamDataTexture) -> void:
	_material.shader = SHADER
	_material.set_shader_parameter("beam_data", data.texture)
	_material.set_shader_parameter("samples", float(BeamDataTexture.SAMPLES))
	material_override = _material


## Rebuilds the mesh only when the section, length or drawing changes. `turned` draws the
## section a quarter turn around so its weak (vertical-axis) direction bends visibly;
## `draw_scale` draws the section larger than life.
func set_shape(section: CrossSection, length: float, turned: bool = false, draw_scale: float = 1.0) -> void:
	var key: String = "%d %.3f %s %.2f" % [section.get_instance_id(), length, turned, draw_scale]
	if key == _key:
		return
	_key = key
	var basis := Transform2D(PI / 2.0 if turned else 0.0, Vector2.ZERO).scaled(Vector2(draw_scale, draw_scale))
	mesh = BeamMeshBuilder.build(SectionProfile.for_section(section).transformed(basis), length)
	var half_depth: float = (section.z_max() if turned else section.y_max()) * draw_scale
	_material.set_shader_parameter("half_depth", half_depth)
	_material.set_shader_parameter("beam_length", length)
	position.y = half_depth


## Displacement drawn where the data texture's normalized deflection is 1 [m].
func set_drawn_deflection(meters: float) -> void:
	_drawn_deflection = meters
	_material.set_shader_parameter("deflection_scale", meters)


## Hides everything beyond x (shows the left part of a section cut); INF shows it all.
func set_cut(x: float) -> void:
	_material.set_shader_parameter("cut_x", x if is_finite(x) else 1.0e6)


## ratio = sigma_max / (stress at full color): 1 for auto range, 1/FS for "relative to yield".
func set_stress_ratio(ratio: float) -> void:
	_material.set_shader_parameter("stress_ratio", ratio)
