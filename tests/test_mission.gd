extends GutTest

const DAY_S := 86400.0


func _make_input(days := 2.0) -> SimInput:
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


## _timeline builds an orbit with one 8 minute pass per 95 minute orbit.
func _timeline(input: SimInput) -> OrbitTimeline:
	var orbit := {"altitude_m": 550000.0, "eclipse_fraction": 0.36, "reference_duration_s": 5700.0, "contacts_s": {"gs": [[600.0, 1080.0]]}}
	return OrbitTimeline.build(orbit, [&"gs"], input.duration_s)


func _no_pauses(m: Mission) -> Mission:
	for t in AutoPause.TRIGGERS:
		m.auto_pause.enabled[t] = false
	return m


func _assert_same_run(a: RunResult, b: RunResult) -> void:
	assert_eq(a.energy_j, b.energy_j, "energy series")
	assert_eq(a.stored_bits, b.stored_bits, "stored series")
	assert_eq(a.delivered_bits, b.delivered_bits, "delivered series")
	assert_eq(a.discarded_bits, b.discarded_bits, "discarded series")
	assert_eq(a.mode, b.mode, "mode series")
	assert_eq(a.events, b.events, "events")
	assert_eq(a.end_reason, b.end_reason)
	assert_eq(a.missed_bits_total, b.missed_bits_total)
	assert_eq(a.safe_time_s, b.safe_time_s)


func test_stepping_in_any_chunks_matches_the_uninterrupted_run() -> void:
	var input := _make_input()
	input.solar_power_w = 6.4  # weak enough to go in and out of Safe mode
	var expected := Simulator.run(input, _timeline(input))
	assert_gt(expected.safe_entries, 0, "the case exercises Safe mode")
	for chunk in [1, 7, 1000, 100000]:
		var m := _no_pauses(Mission.new(input, _timeline(input)))
		while not m.state.done:
			m.advance(chunk)
		_assert_same_run(m.state.result, expected)


func test_lower_duty_cycle_makes_less_data_and_saves_energy() -> void:
	var input := _make_input(1.0)
	var m := _no_pauses(Mission.new(input, _timeline(input)))
	m.advance(100)
	var generated_before := m.state.result.generated_bits_total
	m.set_control(Controls.DUTY_CYCLE, 0.0)
	m.advance(100)
	assert_eq(m.state.result.generated_bits_total, generated_before, "camera off makes no data")
	var untouched := Simulator.run(input, _timeline(input))
	assert_gt(m.state.result.energy_j[199], untouched.energy_j[199], "and the battery keeps the camera's share")


func test_radio_off_keeps_data_on_board_and_saves_transmit_power() -> void:
	var input := _make_input(1.0)
	var m := _no_pauses(Mission.new(input, _timeline(input)))
	m.set_control(Controls.RADIO_ENABLED, false)
	m.finish()
	var r := m.state.result
	var untouched := Simulator.run(input, _timeline(input))
	assert_eq(r.delivered_bits_total, 0.0)
	assert_almost_eq(r.stored_bits_end, r.generated_bits_total - r.discarded_bits_total, 1.0)
	assert_gt(untouched.delivered_bits_total, 0.0, "the case has passes to miss")
	for i in r.step_count():
		if r.energy_j[i] < untouched.energy_j[i]:
			fail_test("radio off drew more power at step %d" % i)
			return


func test_controls_do_nothing_in_safe_mode() -> void:
	var input := _make_input(1.0)
	input.solar_power_w = 0.0
	input.battery_capacity_j *= 10.0
	input.initial_energy_j = 0.29 * input.battery_capacity_j
	var a := _no_pauses(Mission.new(input, _timeline(input)))
	var b := _no_pauses(Mission.new(input, _timeline(input)))
	a.advance(1)
	b.advance(1)
	assert_eq(a.state.mode, RunResult.Mode.SAFE)
	b.set_control(Controls.DUTY_CYCLE, 1.0)
	b.set_control(Controls.RADIO_ENABLED, false)
	a.advance(500)
	b.advance(500)
	assert_eq(a.state.result.energy_j, b.state.result.energy_j)


func test_replaying_the_command_log_reproduces_the_mission() -> void:
	var input := _make_input()
	input.solar_power_w = 7.0
	var m := Mission.new(input, _timeline(input))
	m.advance(300)
	m.set_control(Controls.DUTY_CYCLE, 0.9)
	m.advance(400)
	m.set_control(Controls.RADIO_ENABLED, false)
	m.advance(250)
	m.set_control(Controls.RADIO_ENABLED, true)
	m.set_control(Controls.DUTY_CYCLE, 0.2)
	while not m.state.done:
		m.advance(500)
	var r := m.state.result
	assert_eq(r.commands.size(), 4)
	assert_eq(r.commands[0], {"t_s": 300 * 60.0, "control": Controls.DUTY_CYCLE, "value": 0.9})
	var replay := Simulator.run(input, _timeline(input), r.commands)
	_assert_same_run(replay, r)
	assert_eq(replay.commands, r.commands)


func test_setting_the_current_value_logs_nothing() -> void:
	var input := _make_input(1.0)
	var m := Mission.new(input, _timeline(input))
	m.set_control(Controls.DUTY_CYCLE, 0.5)
	m.set_control(Controls.RADIO_ENABLED, true)
	assert_eq(m.state.result.commands.size(), 0)


func test_storage_pause_fires_once_on_the_crossing() -> void:
	var input := _make_input(2.0)
	input.downlink_rate_bps = 0.0
	input.storage_capacity_bits = 2.0e9
	var m := Mission.new(input, _timeline(input))
	var fired := m.advance(100000)
	assert_eq(fired, [AutoPause.STORAGE_HIGH] as Array[StringName])
	var i := m.state.step - 1
	assert_gte(m.state.result.stored_bits[i], 0.8 * input.storage_capacity_bits)
	assert_lt(m.state.result.stored_bits[i - 1], 0.8 * input.storage_capacity_bits)
	assert_eq(m.advance(100000), [] as Array[StringName], "full memory stays full, no second pause")
	assert_true(m.state.done)


func test_storage_pause_rearms_after_draining() -> void:
	var p := AutoPause.new()
	var input := _make_input()
	var s := SimState.new()
	s.energy_j = input.battery_capacity_j
	var c := Controls.initial(input)
	var cap := input.storage_capacity_bits
	var fired_at := []
	for f in [0.5, 0.85, 0.9, 0.7, 0.5, 0.85]:
		s.stored_bits = f * cap
		fired_at.append(not p.check(s, input, c, RunResult.Mode.NORMAL).is_empty())
	assert_eq(fired_at, [false, true, false, false, false, true])


func test_low_battery_pause_sits_above_safe_mode_and_rearms() -> void:
	var p := AutoPause.new()
	var input := _make_input()
	var s := SimState.new()
	var c := Controls.initial(input)
	assert_almost_eq(AutoPause.low_battery_fraction(input), 0.4, 1e-9)
	var fired_at := []
	var levels := [0.9, 0.45, 0.39, 0.35, 0.5, 0.62, 0.39]
	for i in levels.size():
		s.t_s = i * 0.5 * DAY_S  # half a day apart. The one day cooldown has passed by the recharge
		s.energy_j = levels[i] * input.battery_capacity_j
		fired_at.append(p.check(s, input, c, RunResult.Mode.NORMAL) == ([AutoPause.LOW_BATTERY] as Array[StringName]))
	assert_eq(fired_at, [false, false, true, false, false, false, true])
	# In Safe mode the controls can't change the power draw. The pause does not fire there.
	p = AutoPause.new()
	s.energy_j = 0.35 * input.battery_capacity_j
	assert_eq(p.check(s, input, c, RunResult.Mode.SAFE), [] as Array[StringName])


func test_low_battery_pause_waits_a_day_before_rearming() -> void:
	var p := AutoPause.new()
	var input := _make_input()
	var s := SimState.new()
	var c := Controls.initial(input)
	var fired := 0
	# The battery drops and recharges every orbit for half a day, like a design that
	# cycles through Safe mode.
	for orbit in 8:
		for f in [0.39, 0.62]:
			s.t_s = orbit * 5700.0
			s.energy_j = f * input.battery_capacity_j
			fired += p.check(s, input, c, RunResult.Mode.NORMAL).size()
	assert_eq(fired, 1, "one stop, not one per orbit")
	s.t_s = 1.2 * DAY_S
	s.energy_j = 0.62 * input.battery_capacity_j
	p.check(s, input, c, RunResult.Mode.NORMAL)
	s.energy_j = 0.39 * input.battery_capacity_j
	assert_eq(p.check(s, input, c, RunResult.Mode.NORMAL), [AutoPause.LOW_BATTERY] as Array[StringName], "re-armed after a day")


func test_contact_pause_only_with_the_radio_off_and_once_per_choice() -> void:
	var p := AutoPause.new()
	var input := _make_input()
	var s := SimState.new()
	s.energy_j = input.battery_capacity_j
	s.contact_starts = 1
	var c := Controls.initial(input)
	assert_eq(p.check(s, input, c, RunResult.Mode.NORMAL), [] as Array[StringName], "radio on: it just transmits")
	c.radio_enabled = false
	assert_eq(p.check(s, input, c, RunResult.Mode.NORMAL), [AutoPause.CONTACT_BEGIN] as Array[StringName])
	assert_eq(p.check(s, input, c, RunResult.Mode.NORMAL), [] as Array[StringName], "left off: next pass stays quiet")
	p.rearm_contact()
	assert_eq(p.check(s, input, c, RunResult.Mode.SAFE), [] as Array[StringName], "no downlink in Safe mode")
	assert_eq(p.check(s, input, c, RunResult.Mode.NORMAL), [AutoPause.CONTACT_BEGIN] as Array[StringName])


func test_mission_pauses_when_a_pass_begins_with_the_radio_off() -> void:
	var input := _make_input(1.0)
	var m := Mission.new(input, _timeline(input))
	m.set_control(Controls.RADIO_ENABLED, false)
	assert_eq(m.advance(100000), [AutoPause.CONTACT_BEGIN] as Array[StringName])
	assert_eq(m.state.contact_starts, 1)
	assert_eq(m.state.t_s, 11 * 60.0, "the pass starts at 600 s, inside step 10")


func test_safe_mode_entry_pause_is_off_by_default_but_logged() -> void:
	var input := _make_input(1.0)
	input.solar_power_w = 0.0
	var m := Mission.new(input, _timeline(input))
	m.auto_pause.enabled[AutoPause.LOW_BATTERY] = false
	var fired := m.advance(100000)
	assert_does_not_have(fired, AutoPause.SAFE_ENTER)
	assert_has(m.state.result.events.map(func(e): return e["kind"]), &"safe_enter")
	var n := Mission.new(input, _timeline(input))
	n.auto_pause.enabled[AutoPause.LOW_BATTERY] = false
	n.auto_pause.enabled[AutoPause.SAFE_ENTER] = true
	assert_eq(n.advance(100000), [AutoPause.SAFE_ENTER] as Array[StringName])


func test_baseline_of_an_untouched_mission_is_identical() -> void:
	var input := _make_input()
	var m := _no_pauses(Mission.new(input, _timeline(input)))
	m.finish()
	var base := m.baseline()
	_assert_same_run(base, m.state.result)
	var scenario := Scenario.from_dict({"id": "s", "objectives": {"delivered_mb": 1.0}})
	var cmp := Outcome.compare_runs(m.state.result, base, scenario)
	assert_false(cmp["intervened"])
	for key in ["delivered_bits", "discarded_bits", "safe_time_s"]:
		assert_eq(cmp[key]["verdict"], &"same", key)


func test_baseline_shows_what_operations_cost() -> void:
	var input := _make_input()
	var m := _no_pauses(Mission.new(input, _timeline(input)))
	m.set_control(Controls.RADIO_ENABLED, false)
	m.finish()
	var scenario := Scenario.from_dict({"id": "s", "objectives": {"delivered_mb": 1.0}})
	var cmp := Outcome.compare_runs(m.state.result, m.baseline(), scenario)
	assert_true(cmp["intervened"])
	assert_eq(cmp["delivered_bits"]["verdict"], &"less")
	assert_false(cmp["objectives_met"]["operated"])
	assert_true(cmp["objectives_met"]["baseline"])


func test_tiny_differences_count_as_the_same() -> void:
	var a := RunResult.new()
	var b := RunResult.new()
	a.delivered_bits_total = 1.0e12
	b.delivered_bits_total = 1.0e12 + 5.0e8  # 0.05 %, under the 0.1 % bar
	var cmp := Outcome.compare_runs(a, b, Scenario.new())
	assert_eq(cmp["delivered_bits"]["verdict"], &"same")


func test_forecast_follows_the_controls_and_the_state() -> void:
	var input := _make_input()
	var t := _timeline(input)
	var m := Mission.new(input, t)
	var on := Warnings.forecast(input, m.controls, t, m.state)
	m.set_control(Controls.RADIO_ENABLED, false)
	var off := Warnings.forecast(input, m.controls, t, m.state)
	assert_eq(off["sendable_bits_per_day"], 0.0)
	assert_gt(off["energy_per_orbit_j"], on["energy_per_orbit_j"], "no transmitting saves energy")
	assert_lt(off["storage_full_in_s"], INF)
	m.state.stored_bits = input.storage_capacity_bits
	assert_eq(Warnings.forecast(input, m.controls, t, m.state)["storage_full_in_s"], 0.0, "already full")


func test_break_even_duty_balances_an_orbit() -> void:
	var input := _make_input()
	input.instrument_power_w = 40.0
	var t := _timeline(input)
	var m := Mission.new(input, t)
	var be := Warnings.break_even_duty(input, t, m.controls, m.state)
	assert_between(be, 0.01, 0.99)
	var c := Controls.new()
	c.radio_enabled = true
	c.duty_cycle = be
	assert_almost_eq(Warnings.orbit_energy_j(input, t, c), 0.0, 1.0, "no gain, no loss at break-even")
	m.set_control(Controls.RADIO_ENABLED, false)
	assert_gt(Warnings.break_even_duty(input, t, m.controls, m.state), be, "a silent radio leaves more for the camera")


## The goal projection is what the operations screen shows as "on track" or
## "short". It has to agree with the real run, with and without Safe mode cycles.
func test_projection_matches_the_run_with_and_without_safe_mode() -> void:
	for instrument_w in [4.0, 40.0]:
		var input := _make_input(10.0)
		input.instrument_power_w = instrument_w
		var t := _timeline(input)
		var m := Mission.new(input, t)
		var projected := Warnings.projected_delivered_bits(input, t, m.controls, m.state)
		var r := Simulator.run(input, _timeline(input))
		if instrument_w > 4.0:
			assert_gt(r.safe_time_s, 0.0, "the hungry camera does cycle through Safe mode")
		assert_almost_eq(projected, r.delivered_bits_total, 0.03 * r.delivered_bits_total, "camera at %.0f W" % instrument_w)


func test_projection_halfway_counts_what_is_home_already() -> void:
	var input := _make_input(10.0)
	var t := _timeline(input)
	var m := _no_pauses(Mission.new(input, t))
	m.advance(m.state.total_steps / 2)
	var home := m.state.result.delivered_bits_total
	var projected := Warnings.projected_delivered_bits(input, t, m.controls, m.state)
	assert_gt(projected, home)
	m.finish()
	assert_almost_eq(projected, m.state.result.delivered_bits_total, 0.03 * m.state.result.delivered_bits_total)
	m = _no_pauses(Mission.new(input, _timeline(input)))
	m.advance(m.state.total_steps / 2)
	m.set_control(Controls.RADIO_ENABLED, false)
	assert_eq(Warnings.projected_delivered_bits(input, t, m.controls, m.state), m.state.result.delivered_bits_total,
			"a silent radio sends nothing more")


func test_low_battery_offers_a_camera_time_that_balances_power() -> void:
	var input := _make_input()
	input.instrument_power_w = 40.0
	var t := _timeline(input)
	var m := Mission.new(input, t)
	m.set_control(Controls.DUTY_CYCLE, 1.0)
	var fired: Array[StringName] = [AutoPause.LOW_BATTERY]
	var offered := Warnings.choices(fired, input, t, m.controls, m.state)
	var duty := offered.filter(func(c): return c["kind"] == &"duty")
	assert_eq(duty.size(), 1)
	var c := Controls.new()
	c.duty_cycle = duty[0]["value"]
	assert_gte(Warnings.orbit_energy_j(input, t, c), 0.0, "the suggestion really balances an orbit")
	c.duty_cycle += Warnings.DUTY_STEP
	assert_lt(Warnings.orbit_energy_j(input, t, c), 0.0, "and it is the highest step that does")


func test_choices_follow_the_reason() -> void:
	var input := _make_input()
	var t := _timeline(input)
	var m := Mission.new(input, t)
	var low: Array[StringName] = [AutoPause.LOW_BATTERY]
	assert_eq(Warnings.choices(low, input, t, m.controls, m.state), [] as Array[Dictionary],
			"a battery that gains every orbit needs no change")
	m.set_control(Controls.RADIO_ENABLED, false)
	var pass_off: Array[StringName] = [AutoPause.CONTACT_BEGIN]
	assert_eq(Warnings.choices(pass_off, input, t, m.controls, m.state), [{"kind": &"radio", "value": true}] as Array[Dictionary])
	m.state.radio_hung = true
	m.set_control(Controls.RADIO_ENABLED, true)
	var broke: Array[StringName] = [AutoPause.FAILURE]
	assert_eq(Warnings.choices(broke, input, t, m.controls, m.state), [{"kind": &"restart", "value": Controls.RADIO_ENABLED}] as Array[Dictionary])


func test_full_memory_offers_a_camera_time_the_radio_keeps_up_with() -> void:
	var input := _make_input()
	input.downlink_rate_bps = 0.5e6
	var t := _timeline(input)
	var m := Mission.new(input, t)
	m.set_control(Controls.DUTY_CYCLE, 1.0)
	var full: Array[StringName] = [AutoPause.STORAGE_HIGH]
	var duty := Warnings.choices(full, input, t, m.controls, m.state).filter(func(c): return c["kind"] == &"duty")
	assert_eq(duty.size(), 1)
	var c := Controls.new()
	c.duty_cycle = duty[0]["value"]
	assert_lte(Warnings.generated_bits_per_day(input, c), Warnings.deliverable_bits_per_day(input, t, c), "memory stops filling")
