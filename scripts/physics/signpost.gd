class_name Signpost
extends RefCounted
## Lab 4 (handout figure 3): a solid steel post (w along x, t along y, height h1) with a rigid
## sign (b2 = L along x, h2 high, t thick) on top, running from the post toward +x, so its
## center is sign_offset from the post's axis. z is vertical, measured from the fixed base.
## Loads: sign weight W_z1 per unit length of sign (eccentric: it bends the post), wind
## W_x2 = rate*z [N/m] along x over the post (and the sign's height), wind force F_y1 on the
## sign face at (x1, z1) (eccentric: it twists the post), and the support's weight F_z1 on
## the post's axis. wind_factor scales both wind loads.

var sign_length: float = 4.0        ## L [m]
var post_height: float = 8.5        ## h1 [m]
var thickness: float = 0.5          ## t [m] (post and sign)
var sign_height: float = 2.5        ## h2 [m]
var post_width: float = 0.5         ## w [m]
var sign_weight_per_length: float = 1340.0  ## W_z1 [N/m]
var wind_x_rate: float = 700.0      ## W_x2 = rate*z [N/m per m of height]
var wind_y_force: float = 3600.0    ## F_y1 [N]
var support_weight: float = 11000.0 ## F_z1 [N]
var wind_factor: float = 1.0
var wind_x_on_sign: bool = true     ## W_x2 also acts along the sign's height (as drawn)
var sign_offset: float = 2.0        ## x of the sign's center from the post axis [m] (L/2)
var force_x: float = 2.0            ## x1: F_y1's distance from the post axis [m]
var force_z: float = 1.25           ## z1: F_y1's height above the post top [m]
var material: LabMaterial = LabMaterial.steel()

const STEPS: int = 2000


# A = w*t
func area() -> float:
	return post_width * thickness


# Bending by x-loads (about the y-axis): I = t*w^3/12, S = t*w^2/6
func inertia_for_x() -> float:
	return thickness * pow(post_width, 3) / 12.0


# Bending by y-loads (about the x-axis): I = w*t^3/12
func inertia_for_y() -> float:
	return post_width * pow(thickness, 3) / 12.0


# Compression at the base: N = F_z1 + W_z1*L
func base_axial_force() -> float:
	return support_weight + sign_weight_per_length * sign_length


## Top of the x-wind load: the post top, or the sign top.
func _wind_x_top() -> float:
	return post_height + (sign_height if wind_x_on_sign else 0.0)


# w_x(z) = factor*rate*z
func wind_x_at(z: float) -> float:
	return wind_factor * wind_x_rate * z if z <= _wind_x_top() else 0.0


# V_x = integral of w_x dz = factor*rate*z_top^2/2
func base_shear_x() -> float:
	return wind_factor * wind_x_rate * pow(_wind_x_top(), 2) / 2.0


# V_y = factor*F_y1
func base_shear_y() -> float:
	return wind_factor * wind_y_force


## Bending moment in the post (z <= h1) in the x-z plane: the x-wind plus the eccentric
## sign weight (both bend the top toward +x):
# M_x(z) = integral from z to z_top of w_x(s)*(s - z) ds + W_z1*L*e
#        = factor*rate*(z_top^3/3 - z*z_top^2/2 + z^3/6) + W_z1*L*e
func moment_x_at(z: float) -> float:
	var top: float = _wind_x_top()
	var m: float = sign_weight_per_length * sign_length * sign_offset if z <= post_height else 0.0
	if z < top:
		m += wind_factor * wind_x_rate * (pow(top, 3) / 3.0 - z * top * top / 2.0 + pow(z, 3) / 6.0)
	return m


# M_y(z) = F_y1*(h1 + z1 - z)
func moment_y_at(z: float) -> float:
	return base_shear_y() * maxf(post_height + force_z - z, 0.0)


# Torque on the post: T = F_y1*x1 (the wind on the sign acts off the post's axis)
func torque() -> float:
	return base_shear_y() * force_x


## Rectangular post a x b (a >= b) in torsion (B&J 3.12, approximations of the tabulated c1, c2):
# tau_max = T/(c1*a*b^2), c1 = 1/(3 + 1.8*b/a)
func torsion_stress() -> float:
	var a: float = maxf(post_width, thickness)
	var b: float = minf(post_width, thickness)
	return absf(torque()) * (3.0 + 1.8 * b / a) / (a * b * b)


# phi = T*L/(c2*a*b^3*G), c2*a*b^3 = J = a*b^3*(1/3 - 0.21*(b/a)*(1 - b^4/(12a^4)))
func twist_angle() -> float:
	var a: float = maxf(post_width, thickness)
	var b: float = minf(post_width, thickness)
	var j: float = a * pow(b, 3) * (1.0 / 3.0 - 0.21 * b / a * (1.0 - pow(b / a, 4) / 12.0))
	return torque() * post_height / (j * material.shear_modulus())


# Base corner stresses: sigma = -N/A +- M_x*c_x/I_x +- M_y*c_y/I_y (both moments add at two corners)
func max_tension_stress() -> float:
	return -base_axial_force() / area() + _bending_x_stress() + _bending_y_stress()


func max_compression_stress() -> float:
	return -base_axial_force() / area() - _bending_x_stress() - _bending_y_stress()


func _bending_x_stress() -> float:
	return moment_x_at(0.0) * (post_width / 2.0) / inertia_for_x()


func _bending_y_stress() -> float:
	return moment_y_at(0.0) * (thickness / 2.0) / inertia_for_y()


# Transverse shear on a rectangle: tau_max = 1.5*V/A (on the neutral axis)
func max_transverse_shear() -> float:
	return 1.5 * maxf(base_shear_x(), base_shear_y()) / area()


# Largest von Mises stress at the base. Candidates: the corners (sigma only: neither torsion
# nor transverse shear stress exists at a corner), and the face midpoints, where one bending
# stress is maximal and the torsion stress (conservatively tau_max on both faces) adds to the
# other load's transverse shear 1.5*V/A: sigma_v = sqrt(sigma^2 + 3*tau^2).
func max_von_mises() -> float:
	var n: float = base_axial_force() / area()
	var corner: float = maxf(absf(max_tension_stress()), absf(max_compression_stress()))
	var face_x: float = sqrt(pow(n + _bending_x_stress(), 2) + 3.0 * pow(torsion_stress() + 1.5 * base_shear_y() / area(), 2))
	var face_y: float = sqrt(pow(n + _bending_y_stress(), 2) + 3.0 * pow(torsion_stress() + 1.5 * base_shear_x() / area(), 2))
	return maxf(corner, maxf(face_x, face_y))


# FS = sigma_Y / sigma_v,max
func factor_of_safety() -> float:
	return material.yield_strength / max_von_mises()


## Lateral deflection [m] of the post at height z <= h1 along x (0) or y (1):
## v'' = M/(EI) integrated twice from the fixed base (v = v' = 0 at z = 0), midpoint rule.
func post_deflection(z: float, direction: int) -> float:
	return _integrate(z, direction).y


## Post slope at height z (rad).
func post_slope(z: float, direction: int) -> float:
	return _integrate(z, direction).x


func _integrate(z_end: float, direction: int) -> Vector2:
	var ei: float = material.youngs_modulus * (inertia_for_x() if direction == 0 else inertia_for_y())
	var h: float = z_end / STEPS
	var slope: float = 0.0
	var v: float = 0.0
	for i: int in STEPS:
		var z: float = (i + 0.5) * h
		var m: float = moment_x_at(z) if direction == 0 else moment_y_at(z)
		var new_slope: float = slope + m / ei * h
		v += 0.5 * (slope + new_slope) * h
		slope = new_slope
	return Vector2(slope, v)


## Displacement of the sign's top edge (rigid sign on the post top): v(h1) + theta(h1)*h2.
func sign_top_displacement() -> Vector2:
	var out := Vector2.ZERO
	for d: int in 2:
		var r: Vector2 = _integrate(post_height, d)
		out[d] = r.y + r.x * sign_height
	return out


## The sign's far top corner (x = L from the post): add the twist, which moves it along y by phi*L.
func sign_corner_displacement() -> Vector2:
	return sign_top_displacement() + Vector2(0.0, twist_angle() * sign_length)


# Largest equivalent strain ~ sigma_v/E (linear elastic)
func max_strain() -> float:
	return max_von_mises() / material.youngs_modulus
