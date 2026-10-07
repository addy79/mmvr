class_name BeamController
extends Node
## Owns the beam model. Each input change updates the model once and emits beam_changed;
## views read their results from the beam in response.

signal beam_changed(beam: SimplySupportedBeam)

const LENGTH: float = 4.0            ## L [m]
const DEFAULT_LOAD: float = 10000.0  ## P [N]
const MIN_LOAD: float = 1000.0
const MAX_LOAD: float = 50000.0

var sections: Array[CrossSection] = SectionPresets.all()
var materials: Array[LabMaterial] = LabMaterial.presets()
var beam: SimplySupportedBeam = SimplySupportedBeam.new(
		LENGTH, DEFAULT_LOAD, LENGTH / 2.0, sections[0], materials[0])


func set_load_position(a: float) -> void:
	a = clampf(a, 0.0, LENGTH)
	if is_equal_approx(a, beam.load_position):
		return
	beam.load_position = a
	beam_changed.emit(beam)


func set_load(p: float) -> void:
	p = clampf(p, MIN_LOAD, MAX_LOAD)
	if is_equal_approx(p, beam.load):
		return
	beam.load = p
	beam_changed.emit(beam)


func set_section_index(index: int) -> void:
	if beam.section == sections[index]:
		return
	beam.section = sections[index]
	beam_changed.emit(beam)


func set_material_index(index: int) -> void:
	if beam.material == materials[index]:
		return
	beam.material = materials[index]
	beam_changed.emit(beam)
