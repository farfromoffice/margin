extends GutTest


func _result() -> RunResult:
	var r := RunResult.new()
	r.generated_bits_total = 100.0
	r.delivered_bits_total = 100.0
	return r


func test_clean_run_has_no_limits() -> void:
	assert_eq(Outcome.limiting_factors(_result()), [] as Array[StringName])


func test_safe_mode_discard_and_backlog_are_reported() -> void:
	var r := _result()
	r.safe_time_s = 60.0
	r.delivered_bits_total = 70.0
	r.discarded_bits_total = 20.0
	r.stored_bits_end = 10.0
	assert_eq(Outcome.limiting_factors(r), [&"power", &"storage", &"downlink"] as Array[StringName])


func test_small_backlog_is_not_a_downlink_limit() -> void:
	var r := _result()
	r.delivered_bits_total = 95.0
	r.stored_bits_end = 5.0
	assert_eq(Outcome.limiting_factors(r), [] as Array[StringName])


func test_objective_needs_a_completed_mission() -> void:
	var s := Scenario.from_dict({"id": "x", "objectives": {"delivered_mb": 1.0, "mystery": 3}})
	var r := _result()
	r.delivered_bits_total = 2.0 * Outcome.BITS_PER_MB
	var rows := Outcome.objectives(s, r)
	assert_true(rows[0]["met"])
	assert_almost_eq(float(rows[0]["actual"]), 2.0, 1e-9)
	assert_null(rows[1]["actual"])
	assert_false(rows[1]["met"])
	r.end_reason = RunResult.EndReason.POWER_LOST
	assert_false(Outcome.objectives(s, r)[0]["met"])


func test_prediction_split() -> void:
	var c := Outcome.compare_prediction([&"power", &"storage"] as Array[StringName], [&"storage", &"downlink"] as Array[StringName])
	assert_eq(c["hit"], [&"storage"] as Array[StringName])
	assert_eq(c["missed"], [&"downlink"] as Array[StringName])
	assert_eq(c["wrong"], [&"power"] as Array[StringName])
