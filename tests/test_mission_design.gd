extends GutTest


func test_round_trip_keeps_every_field() -> void:
	var d := MissionDesign.new()
	d.scenario_id = &"wildfire_watch"
	d.requirements = {&"resolution_m": 30}
	d.launcher_id = &"rocket_a"
	d.orbit_id = &"leo_400"
	d.component_ids = [&"panel_a", &"battery_a"]
	d.instrument_ids = [&"camera_a"]
	d.ground_station_ids = [&"station_a"]

	var back := MissionDesign.from_dict(d.to_dict())

	assert_eq(back.scenario_id, &"wildfire_watch")
	assert_eq(back.requirements, {&"resolution_m": 30})
	assert_eq(back.launcher_id, &"rocket_a")
	assert_eq(back.orbit_id, &"leo_400")
	assert_eq(back.component_ids, [&"panel_a", &"battery_a"] as Array[StringName])
	assert_eq(back.instrument_ids, [&"camera_a"] as Array[StringName])
	assert_eq(back.ground_station_ids, [&"station_a"] as Array[StringName])


func test_garbage_import_does_not_crash() -> void:
	var back := MissionDesign.from_dict({"component_ids": [1, null, "ok"], "requirements": "nope"})
	assert_eq(back.component_ids, [&"ok"] as Array[StringName])
	assert_eq(back.requirements, {})
