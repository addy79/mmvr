extends PhysicsTestCase
## The shaders draw what this texture holds, so check it against the reference beam
## (L = 4 m, P = 10 kN at a = 1 m, steel rectangle 100 x 200 mm).


func _written() -> BeamDataTexture:
	var data := BeamDataTexture.new()
	data.write(SimplySupportedBeam.new(4.0, 10000.0, 1.0, RectSection.new(0.1, 0.2), BeamMaterial.steel()))
	return data


# Supports never move: v(0) = v(L) = 0.
func test_supports_have_zero_deflection() -> void:
	var data := _written()
	assert_almost_eq(data.sample(0, 0).r, 0.0, 1e-4, "v(0)")
	assert_almost_eq(data.sample(BeamDataTexture.SAMPLES - 1, 0).r, 0.0, 1e-4, "v(L)")


# Top fiber in compression, bottom in tension, equal magnitude (doubly symmetric section).
# At x = 1.0079 m (sample 32 of 127; M = 2500*(4 - 1.0079) = 7480 N*m) sigma/sigma_max = 7480/7500.
func test_stress_signs_and_value_near_load() -> void:
	var s: Color = _written().sample(32, 0)
	assert_lt(s.g, 0.0, "top fiber compression")
	assert_gt(s.b, 0.0, "bottom fiber tension")
	assert_almost_eq(s.b, 7480.3 / 7500.0, 0.002, "sigma_bottom / sigma_max (half-float)")
	assert_almost_eq(s.g, -s.b, 1e-3, "symmetric")


# V/|V|max = +1 left of the load and -2500/7500 right of it; M/M_max = 0 at both supports.
func test_shear_and_moment_rows() -> void:
	var data := _written()
	assert_almost_eq(data.sample(10, 1).r, 1.0, 1e-3, "V left")
	assert_almost_eq(data.sample(100, 1).r, -1.0 / 3.0, 1e-3, "V right")
	assert_almost_eq(data.sample(0, 1).g, 0.0, 1e-4, "M(0)")
	assert_almost_eq(data.sample(BeamDataTexture.SAMPLES - 1, 1).g, 0.0, 1e-4, "M(L)")


# Unloaded beam: all zeros, no division by zero.
func test_unloaded_beam_is_all_zero() -> void:
	var data := BeamDataTexture.new()
	data.write(SimplySupportedBeam.new(4.0, 0.0, 1.0, RectSection.new(0.1, 0.2), BeamMaterial.steel()))
	assert_eq(data.sample(50, 0), Color(0.0, 0.0, 0.0, 1.0))
