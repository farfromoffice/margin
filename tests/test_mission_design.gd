extends GutTest


func test_json_round_trip_keeps_every_field() -> void:
	var d := MissionDesign.new()
	d.scenario_id = &"wildfire_watch"
	d.requirements = {&"resolution_m": 30.0}
	d.launcher_id = &"rocket_a"
	d.orbit_id = &"leo_400"
	d.component_ids = [&"panel_a", &"battery_a", &"camera_a"]
	d.ground_station_ids = [&"station_a"]

	var back := MissionDesign.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))

	assert_eq(back.scenario_id, &"wildfire_watch")
	assert_eq(back.requirements, d.requirements)
	assert_eq(back.launcher_id, &"rocket_a")
	assert_eq(back.orbit_id, &"leo_400")
	assert_eq(back.component_ids, [&"panel_a", &"battery_a", &"camera_a"] as Array[StringName])
	assert_eq(back.ground_station_ids, [&"station_a"] as Array[StringName])


func test_garbage_import_does_not_crash() -> void:
	var back := MissionDesign.from_dict({"component_ids": [1, null, "ok"], "requirements": "nope"})
	assert_eq(back.component_ids, [&"ok"] as Array[StringName])
	assert_eq(back.requirements, {})


func test_requirement_values_become_float_and_bad_values_are_dropped() -> void:
	var back := MissionDesign.from_dict({"requirements": {"resolution_m": 30, "name": "x", "on": true}})
	assert_eq(back.requirements.keys(), [&"resolution_m"])
	assert_typeof(back.requirements[&"resolution_m"], TYPE_FLOAT)
