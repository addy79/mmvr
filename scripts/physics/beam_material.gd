class_name BeamMaterial
extends RefCounted
## Linear-elastic material. SI units: Pa.

var display_name: String
var youngs_modulus: float  ## E [Pa]
var yield_strength: float  ## sigma_Y [Pa]; for wood, the allowable bending stress


func _init(p_name: String, p_youngs_modulus: float, p_yield_strength: float) -> void:
	display_name = p_name
	youngs_modulus = p_youngs_modulus
	yield_strength = p_yield_strength


## Structural steel ASTM A36.
static func steel() -> BeamMaterial:
	return BeamMaterial.new("Steel (A36)", 200.0e9, 250.0e6)


## Aluminum alloy 6061-T6.
static func aluminum() -> BeamMaterial:
	return BeamMaterial.new("Aluminum (6061-T6)", 70.0e9, 240.0e6)


## Douglas fir; yield_strength holds an allowable bending stress (wood has no yield point).
static func wood() -> BeamMaterial:
	return BeamMaterial.new("Wood (Douglas fir)", 13.0e9, 40.0e6)
