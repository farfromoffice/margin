extends GutTest


func test_non_si_fields_get_an_si_twin() -> void:
	var e := {"capacity_wh": 10, "altitude_km": 550, "storage_bytes": 2, "duration_days": 1, "mass_kg": 3.0}
	Catalog.add_si_fields(e)
	assert_almost_eq(e["capacity_j"], 36000.0, 1e-9)
	assert_almost_eq(e["altitude_m"], 550000.0, 1e-9)
	assert_almost_eq(e["storage_bits"], 16.0, 1e-9)
	assert_almost_eq(e["duration_s"], 86400.0, 1e-9)
	assert_eq(e["capacity_wh"], 10, "original stays for the UI")
	assert_false(e.has("mass_g"))


func test_mbps_is_not_mistaken_for_mb() -> void:
	var e := {"rate_mbps": 2.0, "size_mb": 1.0}
	Catalog.add_si_fields(e)
	assert_almost_eq(e["rate_bps"], 2.0e6, 1e-6)
	assert_almost_eq(e["size_bits"], 8.0e6, 1e-6)


func test_shipped_data_is_labelled() -> void:
	for table in ["components", "launchers", "orbits", "ground_stations"]:
		for e in Catalog.all(table):
			assert_has(Catalog.PROVENANCE, str(e["provenance"]), "%s %s" % [table, e["id"]])
			for field in e.get("provenance_fields", {}):
				assert_has(Catalog.PROVENANCE, str(e["provenance_fields"][field]), "%s %s.%s" % [table, e["id"], field])


func test_wildfire_catalog_has_at_most_three_per_category() -> void:
	var counts := {}
	for c in Catalog.all("components"):
		counts[c["category"]] = counts.get(c["category"], 0) + 1
	for category in counts:
		assert_lte(counts[category], 3, category)
