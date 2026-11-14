extends GutTest


func _design() -> MissionDesign:
	var d := MissionDesign.new()
	d.scenario_id = &"wildfire_watch"
	d.component_ids = [&"structure_6u", &"solar_6u_deployable", &"battery_43wh", &"radio_s_band", &"obc_32gb", &"adcs_small", &"camera_thermal"]
	d.ground_station_ids = [&"svalbard", &"fairbanks"]
	d.launcher_id = &"rideshare_sso"
	d.orbit_id = &"sso_550"
	d.instrument_duty_cycle = 0.2
	return d


func _row(rows: Array[Dictionary], key: String) -> Dictionary:
	return rows.filter(func(r): return r["key"] == key)[0]


func test_same_design_changes_nothing() -> void:
	var rows := DesignCompare.rows(_design(), _design(), Catalog)
	assert_eq(DesignCompare.changed_count(rows), 0)
	assert_false(rows.any(func(r): return r["changed"]))


func test_swapped_parts_show_up_with_their_names() -> void:
	var after := _design()
	after.component_ids[2] = &"battery_100wh"
	after.instrument_duty_cycle = 0.5
	var rows := DesignCompare.rows(_design(), after, Catalog)
	var battery := _row(rows, "battery")
	assert_true(battery["changed"])
	assert_eq(battery["after"], Catalog.get_entry("components", &"battery_100wh")["name"])
	assert_true(_row(rows, "duty_cycle")["changed"])
	assert_true(_row(rows, "mass_kg")["changed"], "a bigger battery weighs more")
	assert_eq(DesignCompare.changed_count(rows), 2, "mass and cost follow the parts, not counted")


func test_station_order_does_not_count_as_a_change() -> void:
	var after := _design()
	after.ground_station_ids = [&"fairbanks", &"svalbard"]
	assert_false(_row(DesignCompare.rows(_design(), after, Catalog), "ground_station")["changed"])


func test_dropped_optional_part_reads_as_empty() -> void:
	var after := _design()
	after.component_ids.erase(&"adcs_small")
	var adcs := _row(DesignCompare.rows(_design(), after, Catalog), "adcs")
	assert_true(adcs["changed"])
	assert_eq(adcs["after"], "")
