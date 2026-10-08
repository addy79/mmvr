class_name ShearMomentRig
extends RefCounted
## Lab 9's shear force and bending moment device: a simply supported beam of span L, cut at
## x = c, where a mechanism lets two hangers balance the internal forces at the cut. A load
## of mass m hangs at x from the left support. Balancing masses:
##   shear hanger:          W1*g = Q          (Q = shear force at the cut)
##   bending moment hanger: W2*g*a = M        (M = bending moment at the cut, arm a)

const GRAVITY: float = 9.81  ## g [m/s^2]

var span: float = 0.44           ## L [m]
var cut: float = 0.30            ## c [m] from the left support
var moment_arm: float = 0.105    ## a [m]
var load_mass: float = 0.2       ## m [kg]
var load_position: float = 0.15  ## x [m] from the left support


func beam() -> SimplySupportedBeam:
	return SimplySupportedBeam.new(span, load_mass * GRAVITY, load_position, RectSection.new(0.02, 0.006), LabMaterial.steel())


# Shear at the cut, from the right-hand part: Q = R_B = W*x/L when the load is left of the cut
# (magnitude; with the B&J convention V = -R_B there)
func theoretical_shear() -> float:
	return absf(beam().shear_at(cut))


# Moment at the cut: M = R_B*(L - c) = W*x*(L - c)/L for a load left of the cut
func theoretical_moment() -> float:
	return absf(beam().moment_at(cut))


# W1 = Q/g
func shear_hanger_mass() -> float:
	return theoretical_shear() / GRAVITY


# W2 = M/(g*a)
func moment_hanger_mass() -> float:
	return theoretical_moment() / (GRAVITY * moment_arm)


# Q = W1*g
static func shear_from_mass(mass: float) -> float:
	return mass * GRAVITY


# M = W2*g*a
func moment_from_mass(mass: float) -> float:
	return mass * GRAVITY * moment_arm
