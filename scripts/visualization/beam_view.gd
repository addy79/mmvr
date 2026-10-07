class_name BeamView
extends MeshInstance3D
## The beam itself: procedural mesh for the current section, displaced and stress-colored
## by beam_stress.gdshader from the shared BeamDataTexture. The parent's origin is the
## bottom fiber at support A, so the neutral axis sits c above it.

const SHADER: Shader = preload("res://shaders/beam_stress.gdshader")

var _material: ShaderMaterial = ShaderMaterial.new()
var _section: CrossSection
var _max_deflection: float = 0.0
var _exaggeration: float = 1.0


func _init(data: BeamDataTexture) -> void:
	_material.shader = SHADER
	_material.set_shader_parameter("beam_data", data.texture)
	_material.set_shader_parameter("samples", float(BeamDataTexture.SAMPLES))
	material_override = _material


func show_beam(beam: SimplySupportedBeam) -> void:
	if beam.section != _section:
		_section = beam.section
		mesh = BeamMeshBuilder.build(SectionProfile.for_section(_section), beam.length)
		_material.set_shader_parameter("half_depth", _section.y_max())
		_material.set_shader_parameter("beam_length", beam.length)
		position.y = _section.y_max()
	_max_deflection = beam.max_deflection()
	_update_deflection_scale()


func set_exaggeration(factor: float) -> void:
	_exaggeration = factor
	_update_deflection_scale()


## ratio = sigma_max / (stress at full color): 1 for auto range, 1/FS for "relative to yield".
func set_stress_ratio(ratio: float) -> void:
	_material.set_shader_parameter("stress_ratio", ratio)


func _update_deflection_scale() -> void:
	_material.set_shader_parameter("deflection_scale", _max_deflection * _exaggeration)
