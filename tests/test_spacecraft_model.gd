extends GutTest


func _parts(ids: Array) -> Array:
	return ids.map(func(id): return Catalog.get_entry("components", StringName(id)))


func test_every_shipped_part_has_a_known_look() -> void:
	for c in Catalog.all("components"):
		assert_true(c.has("model"), c["id"])


func test_deployable_array_gets_two_wings() -> void:
	var m: SpacecraftModel = autofree(SpacecraftModel.new())
	m.rebuild(_parts(["structure_6u", "solar_6u_deployable"]))
	assert_eq(m.hinges.size(), 2)
	assert_almost_eq(m.body.x, 0.226, 1e-6)


func test_body_panels_have_no_wings() -> void:
	var m: SpacecraftModel = autofree(SpacecraftModel.new())
	m.rebuild(_parts(["structure_3u", "solar_3u_body"]))
	assert_eq(m.hinges.size(), 0)


func test_empty_design_shows_a_ghost() -> void:
	var m: SpacecraftModel = autofree(SpacecraftModel.new())
	m.rebuild([])
	assert_false(m.has_structure)
	assert_gt(m.get_child_count(), 0)


func test_inside_view_hides_the_skin() -> void:
	var m: SpacecraftModel = autofree(SpacecraftModel.new())
	m.rebuild(_parts(["structure_3u", "solar_3u_body", "battery_43wh", "obc_32gb"]))
	var shown_before := m.get_children().filter(func(n): return n.visible).size()
	m.inside_view = true
	var shown_after := m.get_children().filter(func(n): return n.visible).size()
	assert_lt(shown_after, shown_before)
	m.inside_view = false
	assert_eq(m.get_children().filter(func(n): return n.visible).size(), shown_before)
