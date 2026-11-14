extends GutTest
## Live failures: the plan draw, what each kind does to a step, and the power
## cycle that clears a hang.

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


func _timeline(input: SimInput) -> OrbitTimeline:
	var orbit := {"altitude_m": 550000.0, "eclipse_fraction": 0.36, "reference_duration_s": 5700.0, "contacts_s": {"gs": [[600.0, 1080.0]]}}
	return OrbitTimeline.build(orbit, [&"gs"], input.duration_s)


func _quiet(m: Mission) -> Mission:
	for t in AutoPause.TRIGGERS:
		m.auto_pause.enabled[t] = false
	return m


func _plan(kind: StringName, t_s: float, magnitude := 0.0) -> Array[Dictionary]:
	return [{"t_s": t_s, "kind": kind, "magnitude": magnitude}]


func test_plan_is_the_same_for_the_same_seed_and_stays_in_bounds() -> void:
	var entries := Catalog.all("failures")
	assert_eq(entries.size(), 4, "every failures.json row loads")
	for seed in range(40):
		var a := FailurePlan.generate(seed, 30.0 * DAY_S, 60.0, entries)
		assert_eq(a, FailurePlan.generate(seed, 30.0 * DAY_S, 60.0, entries))
		assert_between(a.size(), 1, 3, "training always brings a failure")
		var kinds := {}
		var last := -1.0
		for f in a:
			assert_false(kinds.has(f["kind"]), "a kind strikes once")
			kinds[f["kind"]] = true
			assert_between(float(f["t_s"]), 3.0 * DAY_S - 1.0, 27.0 * DAY_S + 1.0)
			assert_eq(fmod(float(f["t_s"]), 60.0), 0.0, "on a step boundary")
			assert_gte(float(f["t_s"]), last)
			last = float(f["t_s"])


func test_each_mode_draws_its_own_count() -> void:
	var entries := Catalog.all("failures")
	var uncertain_sizes := {}
	for seed in range(200):
		assert_eq(FailurePlan.generate(seed, 30.0 * DAY_S, 60.0, entries, FailurePlan.Mode.NONE), [] as Array[Dictionary])
		var u := FailurePlan.generate(seed, 30.0 * DAY_S, 60.0, entries, FailurePlan.Mode.UNCERTAIN)
		assert_eq(u, FailurePlan.generate(seed, 30.0 * DAY_S, 60.0, entries, FailurePlan.Mode.UNCERTAIN), "same seed, same plan")
		uncertain_sizes[u.size()] = true
	for n in uncertain_sizes:
		assert_between(n, 0, 3)
	assert_true(uncertain_sizes.has(0), "an uncertain mission can fly without failures")
	assert_true(uncertain_sizes.has(3), "and can meet three")


func test_no_entries_means_no_failures() -> void:
	assert_eq(FailurePlan.generate(1, DAY_S, 60.0, []), [] as Array[Dictionary])


func test_hung_radio_sends_nothing_until_power_cycled() -> void:
	var input := _make_input()
	var m := _quiet(Mission.new(input, _timeline(input), _plan(&"radio_hang", 0.0)))
	m.advance(int(DAY_S / 60.0))
	assert_true(m.state.radio_hung)
	assert_eq(m.state.result.delivered_bits_total, 0.0)
	m.power_cycle(Controls.RADIO_ENABLED)
	assert_false(m.controls.radio_enabled, "off for the cycle")
	m.advance(1)
	assert_false(m.state.radio_hung)
	assert_true(m.controls.radio_enabled, "back on after one step")
	m.finish()
	assert_gt(m.state.result.delivered_bits_total, 0.0)
	var kinds := m.state.result.events.map(func(e): return e["kind"])
	assert_has(kinds, &"failure")
	assert_has(kinds, &"recovered")


func test_replay_with_commands_and_failures_matches_the_flown_mission() -> void:
	var input := _make_input()
	var plan := _plan(&"radio_hang", 3600.0)
	var m := _quiet(Mission.new(input, _timeline(input), plan))
	m.advance(200)
	m.power_cycle(Controls.RADIO_ENABLED)
	m.finish()
	var r := m.state.result
	var replay := Simulator.run(input, _timeline(input), r.commands, plan)
	assert_eq(replay.delivered_bits, r.delivered_bits)
	assert_eq(replay.events, r.events)


func test_baseline_meets_the_failure_and_never_fixes_it() -> void:
	var input := _make_input()
	var m := _quiet(Mission.new(input, _timeline(input), _plan(&"radio_hang", 3600.0)))
	m.advance(200)
	m.power_cycle(Controls.RADIO_ENABLED)
	m.finish()
	var base := m.baseline()
	assert_lt(base.delivered_bits_total, m.state.result.delivered_bits_total)
	assert_false(base.events.any(func(e): return e["kind"] == &"recovered"))


func test_frozen_camera_draws_power_but_makes_no_data() -> void:
	var input := _make_input()
	var healthy := Simulator.run(input, _timeline(input))
	var frozen := Simulator.run(input, _timeline(input), [], _plan(&"instrument_hang", 0.0))
	assert_eq(frozen.generated_bits_total, 0.0)
	assert_eq(frozen.energy_j, healthy.energy_j, "same load as a working camera")


func test_camera_power_cycle_restores_the_duty_cycle() -> void:
	var input := _make_input()
	var m := _quiet(Mission.new(input, _timeline(input), _plan(&"instrument_hang", 0.0)))
	m.advance(10)
	m.power_cycle(Controls.DUTY_CYCLE)
	assert_eq(m.controls.duty_cycle, 0.0)
	m.advance(1)
	assert_false(m.state.instrument_hung)
	assert_eq(m.controls.duty_cycle, 0.5)


func test_battery_fade_caps_the_charge_and_moves_safe_mode_up() -> void:
	var input := _make_input()
	var m := _quiet(Mission.new(input, _timeline(input), _plan(&"battery_fade", 0.0, 0.25)))
	m.advance(1)
	assert_almost_eq(m.state.battery_health, 0.75, 1e-9)
	assert_lte(m.state.energy_j, 0.75 * input.battery_capacity_j)
	m.finish()
	for e in m.state.result.energy_j:
		assert_lte(e, 0.75 * input.battery_capacity_j + 1e-6)


func test_solar_loss_charges_less() -> void:
	var input := _make_input()
	var healthy := Simulator.run(input, _timeline(input))
	var hurt := Simulator.run(input, _timeline(input), [], _plan(&"solar_loss", 0.0, 0.5))
	var sum_h := 0.0
	var sum_x := 0.0
	for i in healthy.energy_j.size():
		sum_h += healthy.energy_j[i]
		sum_x += hurt.energy_j[i]
	assert_lt(sum_x, sum_h)


func test_failure_pauses_the_clock() -> void:
	var input := _make_input()
	var m := Mission.new(input, _timeline(input), _plan(&"solar_loss", 600.0, 0.2))
	var fired := m.advance(100)
	assert_has(fired, AutoPause.FAILURE)
	assert_eq(m.state.t_s, 660.0, "stops after the step it struck in")
