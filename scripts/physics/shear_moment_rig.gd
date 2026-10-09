class_name ShearMomentRig
extends RefCounted
## Lab 9's shear force and bending moment unit (Edibon MMF, handout figure 4): the beam is cut
## at section x-x; the free arm on the left carries the load W at distance x from the cut,
## and the mechanism at the cut balances it with two hangers:
##   shear hanger (3):          W1 = W            Q_x = -W = W1
##   bending moment hanger (4): W2*a = W*x        M_x = -W*x = W2*a
## The free arm is a cantilever built in at the cut: Q is the same everywhere between the
## load and the cut, and M grows linearly from 0 at the load to W*x at the cut.

const GRAVITY: float = 9.81  ## g [m/s^2]
const ARM_LENGTH: float = 0.18  ## free arm, from the cut to its free end [m] (beyond X1 = 0.15 m)

var moment_arm: float = 0.105    ## a [m]
var load_mass: float = 0.2       ## m [kg]
var load_position: float = 0.15  ## x [m] from the cut


## The free arm as a cantilever fixed at the cut (s = 0) with W at s = x.
func arm() -> CantileverBeam:
	return CantileverBeam.new(ARM_LENGTH, load_mass * GRAVITY, load_position, RectSection.new(0.02, 0.006), LabMaterial.aluminum())


# W = m*g
func load_weight() -> float:
	return load_mass * GRAVITY


# Shear at the cut: |Q| = W, whatever the load's position
func theoretical_shear() -> float:
	return load_weight()


# Moment at the cut: |M| = W*x
func theoretical_moment() -> float:
	return load_weight() * load_position


# W1 = Q/g = m
func shear_hanger_mass() -> float:
	return theoretical_shear() / GRAVITY


# W2 = M/(g*a) = m*x/a
func moment_hanger_mass() -> float:
	return theoretical_moment() / (GRAVITY * moment_arm)


# Q = W1*g
static func shear_from_mass(mass: float) -> float:
	return mass * GRAVITY


# M = W2*g*a
func moment_from_mass(mass: float) -> float:
	return mass * GRAVITY * moment_arm
