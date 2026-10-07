class_name PlaneStress
extends RefCounted
## Chapter 7: plane stress state (sigma_x, sigma_y, tau_xy) and its transformation [Pa].
## theta is measured counterclockwise from x. Mohr's circle follows Beer & Johnston:
## X plots at (sigma_x, -tau_xy), Y at (sigma_y, +tau_xy).

var sigma_x: float
var sigma_y: float
var tau_xy: float


func _init(sx: float = 0.0, sy: float = 0.0, txy: float = 0.0) -> void:
	sigma_x = sx
	sigma_y = sy
	tau_xy = txy


# sigma_avg = (sigma_x + sigma_y)/2 = centre of Mohr's circle
func average() -> float:
	return (sigma_x + sigma_y) / 2.0


# R = sqrt(((sigma_x - sigma_y)/2)^2 + tau_xy^2)
func radius() -> float:
	var half: float = (sigma_x - sigma_y) / 2.0
	return sqrt(half * half + tau_xy * tau_xy)


# Transformation equations:
#   sigma_x' = avg + (sx - sy)/2*cos(2t) + txy*sin(2t)
#   sigma_y' = avg - (sx - sy)/2*cos(2t) - txy*sin(2t)
#   tau_x'y' = -(sx - sy)/2*sin(2t) + txy*cos(2t)
func transformed(theta: float) -> Vector3:
	var half: float = (sigma_x - sigma_y) / 2.0
	var c: float = cos(2.0 * theta)
	var s: float = sin(2.0 * theta)
	return Vector3(average() + half * c + tau_xy * s, average() - half * c - tau_xy * s,
			-half * s + tau_xy * c)


# sigma_max = avg + R
func principal_1() -> float:
	return average() + radius()


# sigma_min = avg - R
func principal_2() -> float:
	return average() - radius()


# tan(2*theta_p) = 2*tau_xy/(sigma_x - sigma_y); returns the angle to the sigma_max direction
func principal_angle() -> float:
	return 0.5 * atan2(2.0 * tau_xy, sigma_x - sigma_y)


# tau_max (in plane) = R, on planes at 45 degrees to the principal planes
func max_inplane_shear() -> float:
	return radius()


func max_shear_angle() -> float:
	return principal_angle() - PI / 4.0


# Absolute maximum shear with sigma_3 = 0 (out of plane): max(|s1 - s2|, |s1|, |s2|)/2
func absolute_max_shear() -> float:
	var s1: float = principal_1()
	var s2: float = principal_2()
	return maxf(absf(s1 - s2), maxf(absf(s1), absf(s2))) / 2.0


# von Mises: sigma_vm = sqrt(s1^2 - s1*s2 + s2^2)
func von_mises() -> float:
	var s1: float = principal_1()
	var s2: float = principal_2()
	return sqrt(s1 * s1 - s1 * s2 + s2 * s2)


# Maximum-distortion-energy criterion: FS = sigma_Y/sigma_vm
func von_mises_safety(yield_strength: float) -> float:
	var vm: float = von_mises()
	return yield_strength / vm if vm > 0.0 else INF


# Maximum-shearing-stress (Tresca) criterion: FS = (sigma_Y/2)/tau_abs,max
func tresca_safety(yield_strength: float) -> float:
	var t: float = absolute_max_shear()
	return yield_strength / 2.0 / t if t > 0.0 else INF
