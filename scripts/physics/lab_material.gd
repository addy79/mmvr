class_name LabMaterial
extends RefCounted
## Isotropic linear-elastic material with an idealized tension-test curve. SI units: Pa, 1/K.
## Values are typical textbook (Beer & Johnston appendix) properties.

## Shape of the stress-strain curve beyond the elastic range.
enum Behavior { YIELD_PLATEAU, GRADUAL_YIELD, BRITTLE }

var display_name: String
var youngs_modulus: float      ## E [Pa]
var yield_strength: float      ## sigma_Y [Pa]; for wood, the allowable bending stress
var ultimate_strength: float   ## sigma_U [Pa]
var poisson_ratio: float       ## nu
var thermal_expansion: float   ## alpha [1/K]
var behavior: Behavior
var hardening_strain: float    ## end of the yield plateau, eps_sh
var ultimate_strain: float     ## strain at sigma_U (necking starts), eps_u
var fracture_strain: float     ## eps_f


func _init(p_name: String, e: float, sigma_y: float, sigma_u: float, nu: float, alpha: float,
		p_behavior: Behavior, eps_sh: float, eps_u: float, eps_f: float) -> void:
	display_name = p_name
	youngs_modulus = e
	yield_strength = sigma_y
	ultimate_strength = sigma_u
	poisson_ratio = nu
	thermal_expansion = alpha
	behavior = p_behavior
	hardening_strain = eps_sh
	ultimate_strain = eps_u
	fracture_strain = eps_f


# G = E / (2(1 + nu)), isotropic materials
func shear_modulus() -> float:
	return youngs_modulus / (2.0 * (1.0 + poisson_ratio))


## The materials offered in the lab.
static func presets() -> Array[LabMaterial]:
	return [steel(), aluminum(), wood()]


## Structural steel ASTM A36.
static func steel() -> LabMaterial:
	return LabMaterial.new("Steel (A36)", 200.0e9, 250.0e6, 400.0e6, 0.30, 11.7e-6,
			Behavior.YIELD_PLATEAU, 0.015, 0.20, 0.30)


## Aluminum alloy 6061-T6.
static func aluminum() -> LabMaterial:
	return LabMaterial.new("Aluminum (6061-T6)", 70.0e9, 240.0e6, 260.0e6, 0.33, 23.6e-6,
			Behavior.GRADUAL_YIELD, 0.0, 0.08, 0.17)


## Douglas fir along the grain, idealized as isotropic. yield_strength holds an allowable
## bending stress (wood has no yield point); it fails brittly at sigma_U in tension.
static func wood() -> LabMaterial:
	return LabMaterial.new("Wood (Douglas fir)", 13.0e9, 40.0e6, 100.0e6, 0.30, 3.5e-6,
			Behavior.BRITTLE, 0.0, 0.0, 100.0e6 / 13.0e9)
