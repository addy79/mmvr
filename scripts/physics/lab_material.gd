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
var ultimate_compressive_strength: float  ## sigma_UC [Pa] (brittle materials are stronger in compression)


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
	ultimate_compressive_strength = sigma_u


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


## Commercially pure aluminum 1050-O (annealed): soft and very ductile (lab 1).
static func pure_aluminum() -> LabMaterial:
	return LabMaterial.new("Pure aluminum (1050-O)", 69.0e9, 28.0e6, 76.0e6, 0.33, 24.0e-6,
			Behavior.GRADUAL_YIELD, 0.0, 0.25, 0.39)


## Aluminum-magnesium alloy 5754 in the H111 temper (slightly strain-hardened) (lab 1).
static func aluminum_h111() -> LabMaterial:
	return LabMaterial.new("Aluminum 5754-H111", 70.0e9, 80.0e6, 190.0e6, 0.33, 23.7e-6,
			Behavior.GRADUAL_YIELD, 0.0, 0.15, 0.20)


## Stainless steel AISI 304 (lab 7's bars), E = 193 GPa as given in the handout.
static func stainless_304() -> LabMaterial:
	return LabMaterial.new("Stainless steel (AISI 304)", 193.0e9, 215.0e6, 505.0e6, 0.29, 17.3e-6,
			Behavior.GRADUAL_YIELD, 0.0, 0.45, 0.55)


## Yellow brass, cold-rolled (B&J appendix B) (lab 7's rod).
static func brass() -> LabMaterial:
	return LabMaterial.new("Brass (yellow, cold-rolled)", 105.0e9, 410.0e6, 510.0e6, 0.34, 20.9e-6,
			Behavior.GRADUAL_YIELD, 0.0, 0.06, 0.08)


## Gray cast iron: brittle, much stronger in compression than in tension.
static func cast_iron() -> LabMaterial:
	var m := LabMaterial.new("Gray cast iron", 69.0e9, 170.0e6, 170.0e6, 0.25, 12.1e-6,
			Behavior.BRITTLE, 0.0, 0.0, 170.0e6 / 69.0e9)
	m.ultimate_compressive_strength = 655.0e6
	return m


## Douglas fir along the grain, idealized as isotropic. yield_strength holds an allowable
## bending stress (wood has no yield point); it fails brittly at sigma_U in tension.
static func wood() -> LabMaterial:
	return LabMaterial.new("Wood (Douglas fir)", 13.0e9, 40.0e6, 100.0e6, 0.30, 3.5e-6,
			Behavior.BRITTLE, 0.0, 0.0, 100.0e6 / 13.0e9)
