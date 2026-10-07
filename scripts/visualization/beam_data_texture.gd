class_name BeamDataTexture
extends RefCounted
## Samples the beam into a small half-float texture read by the beam and diagram shaders.
## Values are normalized to [-1, 1]; their SI scales are passed as shader uniforms.
##   Row 0: R = v/v_max, G = sigma_top/sigma_max, B = sigma_bottom/sigma_max
##   Row 1: R = V/|V|max, G = M/|M|max
## Sample i sits at x = L*i/(SAMPLES - 1), so both supports are sampled exactly.

const SAMPLES: int = 128

var texture: ImageTexture
var _image: Image


func _init() -> void:
	_image = Image.create_empty(SAMPLES, 2, false, Image.FORMAT_RGBAH)
	texture = ImageTexture.create_from_image(_image)


func write(beam: BeamModel) -> void:
	var c: float = beam.section.y_max()
	var v_ref: float = absf(beam.max_deflection())
	var sigma_ref: float = beam.max_bending_stress()
	var shear_ref: float = beam.max_shear()
	var moment_ref: float = absf(beam.max_moment())
	for i: int in SAMPLES:
		var x: float = beam.length * i / (SAMPLES - 1)
		_image.set_pixel(i, 0, Color(
				_ratio(beam.deflection_at(x), v_ref),
				_ratio(beam.bending_stress(x, c), sigma_ref),
				_ratio(beam.bending_stress(x, -c), sigma_ref)))
		_image.set_pixel(i, 1, Color(
				_ratio(beam.shear_at(x), shear_ref),
				_ratio(beam.moment_at(x), moment_ref), 0.0))
	texture.update(_image)


## Any member: deflection(s), top-face and bottom-face stress(s) at s = x/L in [0, 1],
## each normalized by its largest magnitude. Used for columns.
func write_profile(deflection: Callable, top: Callable, bottom: Callable) -> void:
	var v_ref: float = 0.0
	var sigma_ref: float = 0.0
	for i: int in SAMPLES:
		var s: float = float(i) / (SAMPLES - 1)
		v_ref = maxf(v_ref, absf(deflection.call(s)))
		sigma_ref = maxf(sigma_ref, maxf(absf(top.call(s)), absf(bottom.call(s))))
	for i: int in SAMPLES:
		var s: float = float(i) / (SAMPLES - 1)
		_image.set_pixel(i, 0, Color(_ratio(deflection.call(s), v_ref), _ratio(top.call(s), sigma_ref),
				_ratio(bottom.call(s), sigma_ref)))
		_image.set_pixel(i, 1, Color(0.0, 0.0, 0.0))
	texture.update(_image)


## Normalized sample at index i of the given row (used by tests).
func sample(i: int, row: int) -> Color:
	return _image.get_pixel(i, row)


static func _ratio(value: float, reference: float) -> float:
	return value / reference if reference > 0.0 else 0.0
