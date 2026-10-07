class_name EulerColumn
extends RefCounted
## Chapter 10: a column of length L under an axial load P applied with eccentricity e.
## Buckling happens about the weak axis, the centroidal axis with the smaller I.

enum Ends { PINNED_PINNED, FIXED_FREE, FIXED_PINNED, FIXED_FIXED }

## Effective-length factors K (L_e = K*L), Beer & Johnston Fig. 10.18.
const K_FACTORS: Array[float] = [1.0, 2.0, 0.699, 0.5]
## Fixed-pinned first mode: k*L solves tan(kL) = kL.
const FIXED_PINNED_KL: float = 4.4934

var length: float = 3.0
var ends: Ends = Ends.PINNED_PINNED
var load: float = 50.0e3          ## P [N], compression positive
var eccentricity: float = 0.0     ## e [m]
var section: CrossSection = RectSection.new(0.05, 0.1)
var material: LabMaterial = LabMaterial.steel()


# I_min = smaller of the two centroidal moments of inertia
func min_inertia() -> float:
	return minf(section.moment_of_inertia(), section.moment_of_inertia_vertical())


## Extreme-fiber distance measured across the weak axis (the c of the secant formula).
func weak_axis_c() -> float:
	if section.moment_of_inertia() <= section.moment_of_inertia_vertical():
		return section.y_max()
	return section.z_max()


# L_e = K*L
func effective_length() -> float:
	return K_FACTORS[ends] * length


# Radius of gyration about the weak axis: r = sqrt(I_min/A)
func radius_of_gyration() -> float:
	return sqrt(min_inertia() / section.area())


# Slenderness ratio: L_e/r
func slenderness() -> float:
	return effective_length() / radius_of_gyration()


# Euler's formula: P_cr = pi^2*E*I_min/L_e^2
func critical_load() -> float:
	var le: float = effective_length()
	return PI * PI * material.youngs_modulus * min_inertia() / (le * le)


# sigma_cr = P_cr/A = pi^2*E/(L_e/r)^2
func critical_stress() -> float:
	return critical_load() / section.area()


# Slenderness where sigma_cr = sigma_Y: (L_e/r)_c = pi*sqrt(E/sigma_Y); stockier columns yield first
func transition_slenderness() -> float:
	return PI * sqrt(material.youngs_modulus / material.yield_strength)


# Squash load: the whole section yields, P_Y = sigma_Y*A
func squash_load() -> float:
	return material.yield_strength * section.area()


## AISC (ASD) column design for structural steel:
##   sigma_e = pi^2*E/(L_e/r)^2
##   L_e/r <= 4.71*sqrt(E/sigma_Y): sigma_cr = 0.658^(sigma_Y/sigma_e) * sigma_Y  (inelastic)
##   otherwise:                     sigma_cr = 0.877*sigma_e                        (elastic)
##   allowable sigma_all = sigma_cr/1.67
func aisc_critical_stress() -> float:
	var sigma_e: float = critical_stress()
	var sy: float = material.yield_strength
	if slenderness() <= 4.71 * sqrt(material.youngs_modulus / sy):
		return pow(0.658, sy / sigma_e) * sy
	return 0.877 * sigma_e


func aisc_allowable_load() -> float:
	return aisc_critical_stress() / 1.67 * section.area()


# FS against buckling = P_cr/P
func buckling_safety() -> float:
	return critical_load() / load if load > 0.0 else INF


# Secant formula, lateral deflection: y_max = e*[sec(pi/2*sqrt(P/P_cr)) - 1] (INF at P >= P_cr)
func max_deflection() -> float:
	var arg: float = _secant_argument()
	if arg >= PI / 2.0:
		return INF
	return eccentricity * (1.0 / cos(arg) - 1.0)


# Secant formula: sigma_max = (P/A)*[1 + (e*c/r^2)*sec(pi/2*sqrt(P/P_cr))]
func max_stress() -> float:
	var arg: float = _secant_argument()
	if arg >= PI / 2.0:
		return INF
	var r: float = radius_of_gyration()
	return load / section.area() * (1.0 + eccentricity * weak_axis_c() / (r * r) / cos(arg))


## Lateral deflection [m] at s = x/L under the eccentric load (0 when e = 0).
## Pinned-pinned: exact secant curve y = e*[tan(kL/2)*sin(kLs) + cos(kLs) - 1], kL = pi*sqrt(P/P_cr).
## Other end conditions: y_max from the secant formula times the buckling mode shape.
func lateral_deflection_at(s: float) -> float:
	var y_max: float = max_deflection()
	if eccentricity == 0.0 or is_inf(y_max):
		return 0.0
	if ends == Ends.PINNED_PINNED:
		var kl: float = 2.0 * _secant_argument()
		return eccentricity * (tan(kl / 2.0) * sin(kl * s) + cos(kl * s) - 1.0)
	return y_max * mode_shape(s)


## Axial stress [Pa] on one face (side = +1: the side the load is offset toward, which bends
## into compression; side = -1: the other face). Compression negative:
# sigma = -P/A - side*P*(e + y)*c/I_min
func stress_at(s: float, side: float) -> float:
	var bending: float = load * (eccentricity + lateral_deflection_at(s)) * weak_axis_c() / min_inertia()
	return -load / section.area() - side * bending


## First buckling mode at s = x/L (0 at the base), scaled to a peak of 1.
func mode_shape(s: float) -> float:
	match ends:
		Ends.PINNED_PINNED:
			return sin(PI * s)                       # v = sin(pi*x/L)
		Ends.FIXED_FREE:
			return 1.0 - cos(PI * s / 2.0)           # v = 1 - cos(pi*x/(2L))
		Ends.FIXED_FIXED:
			return (1.0 - cos(TAU * s)) / 2.0        # v = (1 - cos(2*pi*x/L))/2
	return _fixed_pinned_shape(s) / _fixed_pinned_peak


# Fixed (x = 0) / pinned (x = L): v = sin(kx) - kx + kL*(1 - cos(kx)), with tan(kL) = kL
static func _fixed_pinned_shape(s: float) -> float:
	var b: float = FIXED_PINNED_KL
	return sin(b * s) - b * s + b * (1.0 - cos(b * s))


## Peak of the unscaled fixed-pinned shape (at s ~ 0.4), found once by sampling.
static var _fixed_pinned_peak: float = _sampled_peak()


static func _sampled_peak() -> float:
	var peak: float = 0.0
	for i: int in 2001:
		peak = maxf(peak, absf(_fixed_pinned_shape(i / 2000.0)))
	return peak


# pi/2*sqrt(P/P_cr) = (L_e/2)*sqrt(P/(E*I))
func _secant_argument() -> float:
	return PI / 2.0 * sqrt(maxf(load, 0.0) / critical_load())
