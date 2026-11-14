extends GutTest


func _orbit(contacts: Dictionary, reference_s: float, fraction := 0.0) -> Dictionary:
	return {"altitude_m": 400000.0, "eclipse_fraction": fraction, "reference_duration_s": reference_s, "contacts_s": contacts}


func test_period_at_400_km_is_about_92_minutes() -> void:
	assert_almost_eq(OrbitTimeline.period_for_altitude_s(400000.0) / 60.0, 92.6, 0.1)


func test_one_eclipse_per_orbit_at_the_end_of_it() -> void:
	var t := OrbitTimeline.build(_orbit({}, 0.0, 0.4), [], 3 * 5553.6)
	assert_eq(t.eclipses.size(), 6)
	assert_almost_eq(t.eclipses[0], 0.6 * t.period_s, 1e-6)
	assert_almost_eq(t.eclipses[1], t.period_s, 1e-6)


func test_contacts_tile_merge_and_clip() -> void:
	var o := _orbit({"a": [[100.0, 200.0]], "b": [[150.0, 260.0], [900.0, 950.0]]}, 1000.0)
	var t := OrbitTimeline.build(o, [&"a", &"b"], 1890.0)
	# a and b overlap, one radio, so they merge; b's 1900 pass starts after the run
	assert_eq(Array(t.contacts), [100.0, 260.0, 900.0, 950.0, 1100.0, 1260.0])
	assert_almost_eq(t.total_contact_s(), 160.0 + 50.0 + 160.0, 1e-9)


func test_unselected_station_adds_nothing() -> void:
	var t := OrbitTimeline.build(_orbit({"a": [[0.0, 10.0]]}, 100.0), [&"b"], 1000.0)
	assert_eq(t.contacts.size(), 0)


func test_advance_returns_partial_overlap_not_whole_steps() -> void:
	var t := OrbitTimeline.build(_orbit({"a": [[30.0, 100.0]]}, 10000.0), [&"a"], 1000.0)
	t.advance(0.0, 60.0)
	assert_almost_eq(t.contact_s, 30.0, 1e-9)
	t.advance(60.0, 60.0)
	assert_almost_eq(t.contact_s, 40.0, 1e-9)
	t.advance(120.0, 60.0)
	assert_eq(t.contact_s, 0.0)
	assert_eq(t.sunlit_s, 60.0)


func test_shipped_orbits_have_gmat_data() -> void:
	for o in Catalog.all("orbits"):
		assert_between(float(o["eclipse_fraction"]), 0.0, 1.0, o["id"])
		assert_gt(float(o["reference_duration_s"]), 0.0, o["id"])
		assert_true(o["contacts_s"] is Dictionary, o["id"])
		for station in o["contacts_s"]:
			assert_false(Catalog.get_entry("ground_stations", StringName(station)).is_empty(), "%s knows %s" % [o["id"], station])
