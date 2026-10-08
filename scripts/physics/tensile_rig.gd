class_name TensileRig
extends RefCounted
## The Mechanical Tensile Testing Unit (MTTU) of labs 1 and 2. Turning the wheel raises the
## upper anchor by L_up (1/3 turn = 0.5 mm). The specimen and the calibrated springs are in
## series, so they carry the same force F:
##   springs:  F = k*dL      (dL read on the dial gauge: dL = RC0 - RC)
##   specimen: F = sigma(eps)*A,  delta = eps*L0
##   travel:   L_up = delta + dL
## Rectangular specimen: A = e*a at the middle section.

const TRAVEL_PER_STEP: float = 0.5e-3  ## one third of a wheel turn raises the anchor 0.5 mm

var material: LabMaterial = LabMaterial.pure_aluminum()
var thickness: float = 2.0e-3          ## e [m]
var width: float = 5.0e-3              ## a [m]
var gauge_length: float = 50.0e-3      ## L0 [m]
var spring_stiffness: float = 200.0e3  ## k [N/m] of the spring pack (from the MTTU description)
var dial_zero: float = 10.0e-3         ## RC0, dial gauge reading with no load [m]


# A = e*a
func area() -> float:
	return thickness * width


## Everything the student reads or computes after `steps` thirds of a wheel turn.
## Keys: travel (L_up), spring (dL), dial (RC), force, stress, elongation (delta), strain, broken.
func state_at(steps: int) -> Dictionary:
	return state_at_travel(steps * TRAVEL_PER_STEP)


## Same, for any travel L_up [m] of the upper anchor.
func state_at_travel(travel: float) -> Dictionary:
	var curve := StressStrainCurve.new(material)
	var eps_f: float = material.fracture_strain
	# Travel needed at strain eps: L_up(eps) = sigma(eps)*A/k + eps*L0, increasing in eps.
	var travel_at := func(eps: float) -> float:
		return curve.stress_at(eps) * area() / spring_stiffness + eps * gauge_length
	if travel >= travel_at.call(eps_f):
		return {"travel": travel, "spring": 0.0, "dial": dial_zero, "force": 0.0, "stress": 0.0,
				"elongation": travel, "strain": travel / gauge_length, "broken": true}
	var lo: float = 0.0
	var hi: float = eps_f
	for i: int in 80:
		var mid: float = 0.5 * (lo + hi)
		if travel_at.call(mid) < travel:
			lo = mid
		else:
			hi = mid
	var eps: float = 0.5 * (lo + hi)
	var sigma: float = curve.stress_at(eps)
	var force: float = sigma * area()
	var spring: float = force / spring_stiffness
	return {"travel": travel, "spring": spring, "dial": dial_zero - spring, "force": force,
			"stress": sigma, "elongation": travel - spring, "strain": (travel - spring) / gauge_length,
			"broken": false}


## Wheel steps until the specimen breaks (first step at which it is broken).
func steps_to_fracture() -> int:
	var s: int = 0
	while not state_at(s).broken and s < 2000:
		s += 1
	return s


# Specimen stiffness EA/L0 vs spring stiffness k: the fraction of the travel taken by the
# specimen while elastic is (1/(EA/L0)) / (1/k + 1/(EA/L0)) = k/(k + EA/L0).
func elastic_share_of_travel() -> float:
	var specimen_k: float = material.youngs_modulus * area() / gauge_length
	return spring_stiffness / (spring_stiffness + specimen_k)
