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
