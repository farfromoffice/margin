extends GutTest

const FakeCatalog := preload("res://tests/fake_catalog.gd")


func _catalog() -> FakeCatalog:
	var c := FakeCatalog.new()
	c.add("components", {"id": "frame", "category": "structure", "mass_kg": 1.0, "cost_kusd": 10.0, "power_w": 0.0, "safe_power_w": 0.0})
	c.add("components", {"id": "panel", "category": "solar", "mass_kg": 0.5, "cost_kusd": 20.0, "power_w": 0.0, "safe_power_w": 0.0, "generated_w_1au": 30.0, "sunlit_factor": 0.5})
	c.add("components", {"id": "pack", "category": "battery", "mass_kg": 0.3, "cost_kusd": 5.0, "power_w": 0.0, "safe_power_w": 0.0, "capacity_wh": 40.0, "safe_enter_fraction": 0.3, "safe_exit_fraction": 0.6})
	c.add("components", {"id": "radio", "category": "comms", "mass_kg": 0.2, "cost_kusd": 5.0, "power_w": 8.0, "safe_power_w": 1.0, "rate_bps": 2.0e6})
	c.add("components", {"id": "brain", "category": "obc", "mass_kg": 0.1, "cost_kusd": 5.0, "power_w": 1.0, "safe_power_w": 1.0, "storage_bytes": 1.0e9})
	c.add("components", {"id": "wheels", "category": "adcs", "mass_kg": 0.5, "cost_kusd": 5.0, "power_w": 1.5, "safe_power_w": 0.5})
	c.add("components", {"id": "cam", "category": "instrument", "mass_kg": 1.0, "cost_kusd": 50.0, "power_w": 5.0, "safe_power_w": 0.0, "data_rate_bps": 1.0e6})
	c.add("launchers", {"id": "rocket", "cost_kusd": 100.0, "capacity_kg": {"sso_550": 5.0}})
	return c


func _design() -> MissionDesign:
	var d := MissionDesign.new()
	d.component_ids = [&"frame", &"panel", &"pack", &"radio", &"brain", &"wheels", &"cam"]
	d.ground_station_ids = [&"gs"]
	d.launcher_id = &"rocket"
	d.orbit_id = &"sso_550"
	d.instrument_duty_cycle = 0.25
	return d


## goes through add_si_fields like shipped data, so duration_s exists
func _scenario(budget := 0.0, max_mass := 0.0) -> Scenario:
	var d := {"id": "s", "duration_days": 2, "budget_kusd": budget, "max_mass_kg": max_mass}
	Catalog.add_si_fields(d)
	return Scenario.from_dict(d)


func _kinds(violations: Array[Dictionary]) -> Array:
	return violations.map(func(v): return v["kind"])


func test_good_design_passes() -> void:
	assert_eq(LaunchCheck.check(_design(), _scenario(1000.0, 10.0), _catalog()), [] as Array[Dictionary])


func test_heavy_design_is_over_launcher_and_scenario() -> void:
	var c := _catalog()
	c.add("launchers", {"id": "rocket", "cost_kusd": 100.0, "capacity_kg": {"sso_550": 3.0}})
	var v := LaunchCheck.check(_design(), _scenario(0.0, 3.0), c)
	assert_eq(_kinds(v), [&"over_launcher_capacity", &"over_scenario_mass"])
	assert_almost_eq(float(v[0]["value"]), 3.6, 1e-9)
	assert_eq(v[0]["unit"], "kg")


## max_payload_kg is in the catalog for both frames and was never checked.
func test_parts_heavier_than_the_frame_carries_block_launch() -> void:
	var c := _catalog()
	c.add("components", {"id": "frame", "category": "structure", "mass_kg": 1.0, "cost_kusd": 10.0, "power_w": 0.0, "safe_power_w": 0.0, "max_payload_kg": 2.0})
	var v := LaunchCheck.check(_design(), _scenario(), c)
	assert_eq(_kinds(v), [&"over_structure_payload"])
	assert_almost_eq(float(v[0]["value"]), 2.6, 1e-9, "the frame's own kilogram is not payload")
	assert_eq(v[0]["limit"], 2.0)
	c.add("components", {"id": "frame", "category": "structure", "mass_kg": 1.0, "cost_kusd": 10.0, "power_w": 0.0, "safe_power_w": 0.0, "max_payload_kg": 2.6})
	assert_eq(LaunchCheck.check(_design(), _scenario(), c), [] as Array[Dictionary], "exactly full is fine")


func test_a_part_sized_for_a_bigger_frame_blocks_launch() -> void:
	var c := _catalog()
	c.add("components", {"id": "frame", "category": "structure", "mass_kg": 1.0, "cost_kusd": 10.0, "power_w": 0.0, "safe_power_w": 0.0, "volume_u": 3})
	c.add("components", {"id": "panel", "category": "solar", "mass_kg": 0.5, "cost_kusd": 20.0, "power_w": 0.0, "safe_power_w": 0.0, "generated_w_1au": 30.0, "sunlit_factor": 0.5, "min_structure_u": 6})
	var v := LaunchCheck.check(_design(), _scenario(), c)
	assert_eq(_kinds(v), [&"structure_too_small"])
	assert_eq(v[0]["value"], "panel")
	assert_eq(v[0]["limit"], 6)
	c.add("components", {"id": "frame", "category": "structure", "mass_kg": 1.0, "cost_kusd": 10.0, "power_w": 0.0, "safe_power_w": 0.0, "volume_u": 6})
	assert_eq(LaunchCheck.check(_design(), _scenario(), c), [] as Array[Dictionary], "fits a 6U frame")


## The shipped catalog: the 6U array is only for the 6U structure.
func test_the_6u_array_needs_the_6u_structure() -> void:
	var d := MissionDesign.new()
	d.component_ids = [&"structure_3u", &"solar_6u_deployable", &"battery_43wh", &"radio_s_band", &"obc_32gb", &"camera_thermal"]
	d.ground_station_ids = [&"svalbard"]
	d.launcher_id = &"rideshare_sso"
	d.orbit_id = &"sso_550"
	var s := Catalog.get_scenario(&"wildfire_watch")
	assert_eq(_kinds(LaunchCheck.check(d, s, Catalog)), [&"structure_too_small"])
	d.component_ids[0] = &"structure_6u"
	assert_eq(LaunchCheck.check(d, s, Catalog), [] as Array[Dictionary])
	d.component_ids[0] = &"structure_3u"
	d.component_ids[1] = &"solar_3u_deployable"
	assert_eq(LaunchCheck.check(d, s, Catalog), [] as Array[Dictionary], "a 3U array fits")


func test_unreachable_orbit_and_budget() -> void:
	var d := _design()
	d.orbit_id = &"leo_400"
	var v := LaunchCheck.check(d, _scenario(150.0), _catalog())
	assert_eq(_kinds(v), [&"orbit_unreachable", &"over_budget"])
	assert_almost_eq(float(v[1]["value"]), 200.0, 1e-9)


func test_missing_parts_block_launch() -> void:
	var d := MissionDesign.new()
	var v := LaunchCheck.check(d, _scenario(), _catalog())
	var missing := v.filter(func(x): return x["kind"] == &"missing_part").map(func(x): return x["value"])
	assert_eq(missing, ["structure", "solar", "battery", "comms", "obc", "instrument", "ground_station", "launcher"])


func test_sim_input_resolves_to_si() -> void:
	var s := SimInput.from_design(_design(), _scenario(), _catalog())
	assert_eq(s.duration_s, 2 * 86400.0)
	assert_almost_eq(s.solar_power_w, 15.0, 1e-9)
	assert_almost_eq(s.bus_power_w, 2.5, 1e-9)
	assert_almost_eq(s.bus_safe_power_w, 1.5, 1e-9)
	assert_almost_eq(s.battery_capacity_j, 40.0 * 3600.0, 1e-9)
	assert_almost_eq(s.storage_capacity_bits, 8.0e9, 1e-3)
	assert_eq(s.radio_tx_power_w, 8.0)
	assert_eq(s.radio_idle_power_w, 1.0)
	assert_eq(s.instrument_rate_bps, 1.0e6)
	assert_eq(s.duty_cycle, 0.25)
	assert_eq(s.initial_energy_j, s.battery_capacity_j)


func test_warnings_flag_starved_power_and_downlink() -> void:
	var s := SimInput.from_design(_design(), _scenario(), _catalog())
	var orbit := {"altitude_m": 550000.0, "eclipse_fraction": 0.36, "reference_duration_s": 86400.0, "contacts_s": {"gs": [[0.0, 60.0]]}}
	var t := OrbitTimeline.build(orbit, [&"gs"], s.duration_s)
	assert_eq(_kinds(Warnings.compute(s, t)), [&"downlink_short", &"storage_fills"])
	s.solar_power_w = 1.0
	assert_has(_kinds(Warnings.compute(s, t)), &"orbit_energy_negative")
