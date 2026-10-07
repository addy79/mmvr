class_name IndeterminateShaft
extends RefCounted
## Chapter 3: a two-segment circular shaft fixed to walls at both ends A and C, loaded by a
## torque T at the junction B. Statics: T_A + T_C = T. Compatibility: the twists of the two
## segments cancel, T_A*g1 = T_C*g2 with torsional flexibilities g_i = L_i/(J_i*G).

var length_1: float = 0.6
var length_2: float = 0.9
var radius_1: float = 0.03
var radius_2: float = 0.02
var torque: float = 2.0e3
var material: LabMaterial = LabMaterial.steel()


# J_i = pi*c_i^4/2
func polar_moment_1() -> float:
	return PI * pow(radius_1, 4) / 2.0


func polar_moment_2() -> float:
	return PI * pow(radius_2, 4) / 2.0


func flexibility_1() -> float:
	return length_1 / (polar_moment_1() * material.shear_modulus())


func flexibility_2() -> float:
	return length_2 / (polar_moment_2() * material.shear_modulus())


# T_A = T*g2/(g1 + g2), T_C = T*g1/(g1 + g2): the stiffer segment takes more torque
func torque_a() -> float:
	return torque * flexibility_2() / (flexibility_1() + flexibility_2())


func torque_c() -> float:
	return torque * flexibility_1() / (flexibility_1() + flexibility_2())


# tau_max,i = T_i*c_i/J_i
func max_shear_1() -> float:
	return absf(torque_a()) * radius_1 / polar_moment_1()


func max_shear_2() -> float:
	return absf(torque_c()) * radius_2 / polar_moment_2()


# Rotation of B: phi_B = T_A*g1
func rotation_b() -> float:
	return torque_a() * flexibility_1()
