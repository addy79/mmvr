class_name PhysicsTestCase
extends GutTest
## Base for physics tests: compares against hand-calculated values within 1%.

const REL_TOL: float = 0.01


func assert_within_1pct(got: float, expected: float, label: String) -> void:
	assert_almost_eq(got, expected, absf(expected) * REL_TOL, label)
