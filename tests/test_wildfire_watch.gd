extends GutTest
## Runs shipped data end to end, so a data edit that breaks the sim shows up here.


func _design() -> MissionDesign:
	var d := MissionDesign.new()
	d.scenario_id = &"wildfire_watch"
	d.component_ids = [&"structure_6u", &"solar_6u_deployable", &"battery_43wh", &"radio_s_band", &"obc_32gb", &"adcs_small"]
	d.instrument_ids = [&"camera_thermal"]
	d.ground_station_ids = [&"svalbard", &"fairbanks"]
	d.launcher_id = &"rideshare_sso"
	d.orbit_id = &"sso_550"
	d.instrument_duty_cycle = 0.2
	return d


func _run(d: MissionDesign) -> RunResult:
	var scenario := Catalog.get_scenario(d.scenario_id)
	var input := SimInput.from_design(d, scenario, Catalog)
	var timeline := OrbitTimeline.build(Catalog.get_entry("orbits", d.orbit_id), d.ground_station_ids, input.duration_s)
	return Simulator.run(input, timeline)


func test_reference_design_launches_and_completes() -> void:
	var d := _design()
	assert_eq(LaunchCheck.check(d, Catalog.get_scenario(d.scenario_id), Catalog), [] as Array[Dictionary])
	var r := _run(d)
	assert_eq(r.end_reason, RunResult.EndReason.COMPLETED)
	assert_eq(r.step_count(), 30 * 1440)
	assert_gt(r.delivered_bits_total, 0.0)


func test_body_panels_cannot_feed_the_mwir_camera() -> void:
	var d := _design()
	d.component_ids[1] = &"solar_3u_body"
	d.instrument_ids = [&"camera_fire_mwir"]
	d.instrument_duty_cycle = 1.0
	var r := _run(d)
	assert_true(r.safe_entries > 0 or r.end_reason == RunResult.EndReason.POWER_LOST)


func test_iss_orbit_misses_the_northern_stations() -> void:
	var orbit := Catalog.get_entry("orbits", &"leo_400")
	var t := OrbitTimeline.build(orbit, [&"svalbard", &"fairbanks"], 86400.0)
	assert_eq(t.total_contact_s(), 0.0)
