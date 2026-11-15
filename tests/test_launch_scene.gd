extends GutTest
## The 3D launch: milestones arrive once and in order, whether it plays out or
## gets skipped, and the rocket takes its size from the launcher entry.


func _scene(launcher_id: StringName) -> LaunchScene:
	var s := LaunchScene.new()
	s.set_up(Catalog.get_entry("launchers", launcher_id), [Catalog.get_entry("components", &"solar_6u_deployable")])
	add_child_autofree(s)
	return s


func test_skip_fires_every_milestone_once_in_order() -> void:
	var s := _scene(&"rideshare_sso")
	var seen: Array[StringName] = []
	s.milestone.connect(func(id): seen.append(id))
	watch_signals(s)
	s.launch()
	await wait_process_frames(3)
	s.skip()
	s.skip()
	assert_eq(seen, LaunchScene.MILESTONES)
	assert_signal_emit_count(s, "finished", 1)


func test_playing_through_reaches_orbit_with_wings_open() -> void:
	var s := _scene(&"dedicated_small")
	var seen: Array[StringName] = []
	s.milestone.connect(func(id): seen.append(id))
	s.launch()
	# drive the clock by hand instead of waiting 26 real seconds for the sequence.
	while seen.size() < LaunchScene.MILESTONES.size():
		s._process(0.25)
	assert_eq(seen, LaunchScene.MILESTONES)
	assert_true(s._in_space)
	assert_false(s.payload.hinges.is_empty())
	await wait_seconds(SpacecraftView.WING_OPEN_S + 0.2)
	for h in s.payload.hinges:
		assert_almost_eq(h.rotation.y, 0.0, 0.01)


func test_rocket_size_comes_from_the_launcher() -> void:
	assert_eq(_scene(&"dedicated_small")._rocket.length_m, 18.0)
	assert_eq(_scene(&"rideshare_sso")._rocket.length_m, 70.0)
