extends GutTest
## Inputs reach the model once and announce the change; out-of-range inputs are clamped.

var _controller: BeamController


func before_each() -> void:
	_controller = autofree(BeamController.new())
	watch_signals(_controller)


func test_moving_the_load_emits_once() -> void:
	_controller.set_load_position(1.0)
	assert_signal_emit_count(_controller, "beam_changed", 1)
	assert_eq(_controller.beam.load_position, 1.0)
	_controller.set_load_position(1.0)
	assert_signal_emit_count(_controller, "beam_changed", 1, "no recompute without a change")


func test_inputs_are_clamped() -> void:
	_controller.set_load_position(9.0)
	assert_eq(_controller.beam.load_position, BeamController.LENGTH)
	_controller.set_load(1.0e9)
	assert_eq(_controller.beam.load, BeamController.MAX_LOAD)


func test_section_and_material_switch() -> void:
	_controller.set_section_index(3)
	_controller.set_material_index(2)
	assert_true(_controller.beam.section is ISection)
	assert_eq(_controller.beam.material.youngs_modulus, 13.0e9)
	assert_signal_emit_count(_controller, "beam_changed", 2)
