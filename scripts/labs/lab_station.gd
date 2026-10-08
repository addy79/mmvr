class_name LabStation
extends Station
## A lab experiment bench, following its handout (labs handouts/Lab Handout N°...):
## objective and theory, the apparatus and procedure, simulated readings in the handout's
## tables, the analysis plots, and guidance for the report questions.
## Simulated readings come from the physics models, rounded to the instrument's resolution
## and, when "realistic scatter" is on, given a small repeatable error (seeded, so the
## numbers do not jump around while the student reads them).

const READINGS: PackedStringArray = ["Ideal", "Realistic scatter"]

var handout: String = ""


## A simulated measurement. Ideal: the true value. Realistic: the true value with a
## repeatable relative error of up to +-spread, rounded to the instrument resolution.
func reading(true_value: float, key: int, spread: float, resolution: float) -> float:
	if not realistic():
		return true_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(lab * 7919 + key, 12345))
	var v: float = true_value * (1.0 + rng.randf_range(-spread, spread))
	return snappedf(v, resolution) if resolution > 0.0 else v


func realistic() -> bool:
	return has_control(&"readings") and value(&"readings") == 1.0


func has_control(id: StringName) -> bool:
	for c: ControlSpec in _controls:
		if c.id == id:
			return true
	return false


## Where the handout lives and a reminder that the numbers here are simulated.
func handout_note() -> String:
	return LessonFormat.note("Handout: labs handouts/%s. The readings on this bench are simulated from the theory (with the scatter you choose); use your own measurements in your report." % handout)


# Percent error: |measured - theory| / |theory| * 100
static func percent_error(measured: float, theory: float) -> float:
	return absf(measured - theory) / absf(theory) * 100.0 if theory != 0.0 else 0.0
