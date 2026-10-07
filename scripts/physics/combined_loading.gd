class_name CombinedLoading
extends RefCounted
## Chapter 8: a sign-post style circular pipe, fixed at its base section and loaded at an
## arm length L by a transverse load P (downward), a torque T and an axial force N.
## Stresses are evaluated at four surface points of the fixed section:
## TOP and BOTTOM (bending, no transverse shear), FRONT and BACK (on the neutral axis,
## where torsion and transverse shear add on the FRONT and subtract on the BACK).

enum Point { TOP, BOTTOM, FRONT, BACK }

var load: float = 5.0e3            ## P [N]
var torque: float = 1.5e3          ## T [N*m]
var axial_load: float = 0.0        ## N [N], tension positive
var arm: float = 1.2               ## L [m] from the load to the section
var outer_radius: float = 0.05     ## c [m]
var inner_radius: float = 0.04     ## [m]
var material: LabMaterial = LabMaterial.steel()


# A = pi*(r_o^2 - r_i^2)
func area() -> float:
	return PI * (outer_radius * outer_radius - inner_radius * inner_radius)


# I = pi*(r_o^4 - r_i^4)/4
func moment_of_inertia() -> float:
	return PI * (pow(outer_radius, 4) - pow(inner_radius, 4)) / 4.0


# J = 2I for a circular section
func polar_moment() -> float:
	return 2.0 * moment_of_inertia()


# M = P*L at the fixed section (hogging: the top is in tension)
func bending_moment() -> float:
	return load * arm


# sigma = N/A + M*c/I at TOP, N/A - M*c/I at BOTTOM, N/A on the sides
func normal_stress(point: Point) -> float:
	var axial: float = axial_load / area()
	var bending: float = bending_moment() * outer_radius / moment_of_inertia()
	match point:
		Point.TOP:
			return axial + bending
		Point.BOTTOM:
			return axial - bending
	return axial


# Torsion: tau_T = T*c/J (same at every surface point)
func torsion_shear() -> float:
	return torque * outer_radius / polar_moment()


# Transverse shear at the neutral axis: tau_V = V*Q/(I*t), Q = 2(r_o^3 - r_i^3)/3,
# t = 2(r_o - r_i), V = P
func transverse_shear() -> float:
	var q: float = 2.0 * (pow(outer_radius, 3) - pow(inner_radius, 3)) / 3.0
	return load * q / (moment_of_inertia() * 2.0 * (outer_radius - inner_radius))


# tau = tau_T (top/bottom), tau_T + tau_V (front), tau_T - tau_V (back)
func shear_stress(point: Point) -> float:
	match point:
		Point.FRONT:
			return torsion_shear() + transverse_shear()
		Point.BACK:
			return torsion_shear() - transverse_shear()
	return torsion_shear()


# Design of a solid transmission shaft under M and T: tau_max = (c/J)*sqrt(M^2 + T^2) with
# J/c = pi*c^3/2, so c_min = (2*sqrt(M^2 + T^2)/(pi*tau_all))^(1/3)
func design_radius(tau_all: float) -> float:
	var m: float = bending_moment()
	return pow(2.0 * sqrt(m * m + torque * torque) / (PI * tau_all), 1.0 / 3.0)


## Stress element at the point: x along the pipe axis, y around the circumference.
func stress_state(point: Point) -> PlaneStress:
	return PlaneStress.new(normal_stress(point), 0.0, shear_stress(point))
