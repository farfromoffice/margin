extends GutTest

const DAY_S := 86400.0


## Everything on, plenty of sun and contact. Tests tweak from here.
func _make_input(days := 1.0) -> SimInput:
	var s := SimInput.new()
	s.duration_s = days * DAY_S
	s.solar_power_w = 20.0
	s.bus_power_w = 2.0
	s.bus_safe_power_w = 1.0
	s.instrument_power_w = 4.0
	s.instrument_rate_bps = 1.0e6
	s.duty_cycle = 0.5
	s.radio_tx_power_w = 8.0
	s.radio_idle_power_w = 0.5
	s.downlink_rate_bps = 2.0e6
	s.battery_capacity_j = 40.0 * 3600.0
	s.safe_enter_fraction = 0.3
	s.safe_exit_fraction = 0.6
	s.storage_capacity_bits = 8.0e9
	s.initial_energy_j = s.battery_capacity_j
	return s


func _timeline(input: SimInput, fraction := 0.36, contacts := [[0.0, 480.0]], reference_s := 5700.0) -> OrbitTimeline:
	var orbit := {"altitude_m": 550000.0, "eclipse_fraction": fraction, "reference_duration_s": reference_s, "contacts_s": {"gs": contacts}}
	return OrbitTimeline.build(orbit, [&"gs"], input.duration_s)


func _check_data_invariant(r: RunResult) -> void:
	var accounted := r.delivered_bits_total + r.discarded_bits_total + r.stored_bits_end
	assert_almost_eq(r.generated_bits_total, accounted, 1e-6 * maxf(1.0, r.generated_bits_total))


func test_healthy_design_completes_with_one_value_per_step() -> void:
	var input := _make_input()
	var r := Simulator.run(input, _timeline(input))
	assert_eq(r.end_reason, RunResult.EndReason.COMPLETED)
	assert_eq(r.step_count(), 1440)
	assert_eq(r.end_t_s, DAY_S)
	assert_eq(r.safe_entries, 0)
	assert_gt(r.delivered_bits_total, 0.0)
	_check_data_invariant(r)


func test_data_invariant_holds_with_overflow() -> void:
	var input := _make_input(3.0)
	input.storage_capacity_bits = 1.0e9
	input.downlink_rate_bps = 1.0e4
	var r := Simulator.run(input, _timeline(input))
	assert_gt(r.discarded_bits_total, 0.0)
	assert_almost_eq(r.stored_bits_end, input.storage_capacity_bits, 1.0)
	_check_data_invariant(r)
	assert_lte(Array(r.stored_bits).max(), input.storage_capacity_bits)


func test_weak_solar_enters_and_leaves_safe_mode() -> void:
	var input := _make_input(2.0)
	# Normal load ~4.5 W, Safe load 1.5 W, average solar ~6.4 W x 0.64
	input.solar_power_w = 6.4
	var r := Simulator.run(input, _timeline(input))
	assert_eq(r.end_reason, RunResult.EndReason.COMPLETED)
	assert_gt(r.safe_entries, 0)
	assert_gt(r.safe_time_s, 0.0)
	assert_gt(r.missed_bits_total, 0.0)
	var kinds := r.events.map(func(e): return e["kind"])
	assert_has(kinds, &"safe_enter")
	assert_has(kinds, &"safe_exit")
	_check_data_invariant(r)


func test_no_sun_loses_the_mission() -> void:
	var input := _make_input(2.0)
	input.solar_power_w = 0.0
	var r := Simulator.run(input, _timeline(input))
	assert_eq(r.end_reason, RunResult.EndReason.POWER_LOST)
	assert_lt(r.end_t_s, input.duration_s)
	assert_eq(r.step_count(), int(r.end_t_s / input.dt_s))
	assert_eq(r.events.back()["kind"], &"power_lost")
	assert_eq(r.energy_j[r.step_count() - 1], 0.0)


func test_safe_mode_stops_science_and_downlink() -> void:
	var input := _make_input()
	# big pack, no sun: starts under the threshold and never climbs back out
	input.battery_capacity_j *= 10.0
	input.initial_energy_j = 0.29 * input.battery_capacity_j
	input.solar_power_w = 0.0
	var r := Simulator.run(input, _timeline(input))
	# first step Normal, then Safe for the rest of the day
	assert_eq(r.mode[0], RunResult.Mode.NORMAL)
	assert_eq(r.mode[1], RunResult.Mode.SAFE)
	assert_almost_eq(r.generated_bits_total, input.instrument_rate_bps * input.duty_cycle * 60.0, 1e-3)


func test_energy_is_capped_at_capacity() -> void:
	var input := _make_input()
	input.solar_power_w = 1000.0
	var r := Simulator.run(input, _timeline(input))
	for i in r.step_count():
		if r.energy_j[i] > input.battery_capacity_j:
			fail_test("step %d over capacity" % i)
			return
	assert_eq(r.energy_j[0], input.battery_capacity_j)


func test_same_input_same_result() -> void:
	var input := _make_input(2.0)
	input.solar_power_w = 6.4
	var a := Simulator.run(input, _timeline(input))
	var b := Simulator.run(input, _timeline(input))
	assert_eq(a.energy_j, b.energy_j)
	assert_eq(a.stored_bits, b.stored_bits)
	assert_eq(a.mode, b.mode)
	assert_eq(a.events, b.events)


func test_daily_summary_adds_up() -> void:
	var input := _make_input(3.0)
	input.solar_power_w = 6.4
	var r := Simulator.run(input, _timeline(input))
	var days := r.daily()
	assert_eq(days.size(), 3)
	var delivered := 0.0
	var safe := 0.0
	var events := 0
	for d in days:
		delivered += d.delivered_bits
		safe += d.safe_time_s
		events += d.events.size()
	assert_almost_eq(delivered, r.delivered_bits_total, 1.0)
	assert_almost_eq(safe, r.safe_time_s, 1e-6)
	assert_eq(events, r.events.size())


func test_thirty_days_runs_fast_enough() -> void:
	var input := _make_input(30.0)
	var start := Time.get_ticks_usec()
	var r := Simulator.run(input, _timeline(input))
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	gut.p("30 day run: %d steps in %.1f ms" % [r.step_count(), ms])
	assert_eq(r.step_count(), 43200)
	assert_lt(ms, 1000.0)
