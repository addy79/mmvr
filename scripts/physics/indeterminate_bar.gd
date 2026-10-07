class_name IndeterminateBar
extends RefCounted
## Chapter 2: a two-segment round bar held between rigid walls at A and C, with an axial
## load P applied at the junction B (positive toward C) and a uniform temperature change.
## Statics alone gives one equation for two unknown reactions; compatibility (the total
## length cannot change) gives the second. Internal forces N are tension-positive.

var length_1: float = 0.4      ## L1 (A to B) [m]
var length_2: float = 0.6      ## L2 (B to C) [m]
var diameter_1: float = 0.03
var diameter_2: float = 0.02
var load: float = 100.0e3      ## P at B [N]
var temperature_change: float = 0.0
var material: LabMaterial = LabMaterial.steel()


func area_1() -> float:
	return PI * diameter_1 * diameter_1 / 4.0


func area_2() -> float:
	return PI * diameter_2 * diameter_2 / 4.0


# Flexibilities f_i = L_i/(A_i*E): elongation per unit axial force
func flexibility_1() -> float:
	return length_1 / (area_1() * material.youngs_modulus)


func flexibility_2() -> float:
	return length_2 / (area_2() * material.youngs_modulus)


# Equilibrium at B: N2 = N1 - P. Compatibility: N1*f1 + N2*f2 + alpha*dT*(L1 + L2) = 0
#   => N1 = (P*f2 - alpha*dT*(L1 + L2)) / (f1 + f2)
func force_1() -> float:
	var thermal: float = material.thermal_expansion * temperature_change * (length_1 + length_2)
	return (load * flexibility_2() - thermal) / (flexibility_1() + flexibility_2())


func force_2() -> float:
	return force_1() - load


# sigma_i = N_i/A_i
func stress_1() -> float:
	return force_1() / area_1()


func stress_2() -> float:
	return force_2() / area_2()


# Wall reactions: R_A = N1 (pulls A toward B when positive), R_C = -N2
func reaction_a() -> float:
	return force_1()


func reaction_c() -> float:
	return -force_2()


# Displacement of B (toward C): u_B = N1*f1 + alpha*dT*L1
func displacement_b() -> float:
	return force_1() * flexibility_1() + material.thermal_expansion * temperature_change * length_1
