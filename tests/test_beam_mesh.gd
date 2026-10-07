extends GutTest
## Quest budget: each procedural beam mesh stays under 2000 vertices.

const VERTEX_BUDGET: int = 2000


func test_every_preset_section_is_under_budget() -> void:
	for section: CrossSection in SectionPresets.all():
		var mesh: ArrayMesh = BeamMeshBuilder.build(SectionProfile.for_section(section), 4.0)
		var count: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert_lt(count, VERTEX_BUDGET, "%s: %d vertices" % [section.display_name, count])


# The mesh spans the beam and the section depth exactly.
func test_mesh_bounds_match_section() -> void:
	var section := RectSection.new(0.1, 0.2)
	var aabb: AABB = BeamMeshBuilder.build(SectionProfile.for_section(section), 4.0).get_aabb()
	assert_almost_eq(aabb.size.x, 4.0, 1e-5, "length")
	assert_almost_eq(aabb.size.y, 0.2, 1e-5, "depth h")
	assert_almost_eq(aabb.size.z, 0.1, 1e-5, "width b")


# Drawn 3x larger and turned a quarter turn: a 100 x 200 rectangle spans 600 (y) x 300 (z)
# becomes 300 (y) x 600 (z).
func test_transformed_profile() -> void:
	var profile := SectionProfile.for_section(RectSection.new(0.1, 0.2)).transformed(
			Transform2D(PI / 2.0, Vector2.ZERO).scaled(Vector2(3.0, 3.0)))
	var aabb: AABB = BeamMeshBuilder.build(profile, 1.0).get_aabb()
	assert_almost_eq(aabb.size.y, 0.3, 1e-4, "depth after the turn")
	assert_almost_eq(aabb.size.z, 0.6, 1e-4, "width after the turn")
