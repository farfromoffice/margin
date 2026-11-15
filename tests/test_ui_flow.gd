extends GutTest
## Clicks through every screen headless. Catches screens that fail to build,
## not layout problems; those need eyes on a real window.

var app: Control


func before_each() -> void:
	# random failures would make the pause tests flaky, the ones that want a
	# failure plant their own
	GameState.failure_mode = FailurePlan.Mode.NONE
	app = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	await wait_process_frames(1)


func _reference_design() -> void:
	GameState.new_mission(&"wildfire_watch", 1)
	var d := GameState.design
	d.component_ids = [&"structure_6u", &"solar_6u_deployable", &"battery_43wh", &"radio_s_band", &"obc_32gb", &"adcs_small", &"camera_thermal"]
	d.ground_station_ids = [&"svalbard", &"fairbanks"]
	d.launcher_id = &"rideshare_sso"
	d.orbit_id = &"sso_550"
	d.instrument_duty_cycle = 0.2


func _go(screen: StringName) -> Control:
	EventBus.screen_requested.emit(screen)
	await wait_process_frames(2)
	return app.current


func test_menu_play_opens_briefing() -> void:
	assert_eq(app.current.name, "main_menu")
	app.current.find_child("PlayButton", true, false).pressed.emit()
	# the menu plays its press and fade first
	await wait_seconds(0.5)
	assert_eq(app.current.name, "briefing")
	assert_eq(GameState.scenario_id, &"wildfire_watch")


func test_empty_design_blocks_launch() -> void:
	GameState.new_mission(&"wildfire_watch", 1)
	var design: Control = await _go(&"design")
	assert_true(design._next.disabled)


func test_full_flow_reaches_the_report() -> void:
	_reference_design()
	var design: Control = await _go(&"design")
	assert_false(design._next.disabled)
	var prediction: Control = await _go(&"prediction")
	prediction._boxes[&"power"].button_pressed = true
	prediction._launch()
	await wait_process_frames(2)
	var launch: Control = app.current
	assert_eq(launch.name, "launch")
	assert_null(GameState.mission, "nothing flies before operations start")
	assert_false(launch._go.disabled)
	assert_true(launch._ops.disabled)
	launch._begin()
	launch.skip_sequence()
	assert_false(launch._ops.disabled)
	assert_eq(launch._seq.get_child_count(), LaunchScene.MILESTONES.size(), "every milestone logged once")
	launch._start_ops()
	await wait_process_frames(2)
	var run: Control = app.current
	assert_eq(run.name, "run")
	assert_not_null(GameState.mission)
	assert_true(run._report.disabled, "no report while the mission flies")
	run._finish_now()
	assert_false(run._report.disabled)
	assert_not_null(GameState.last_result)
	assert_not_null(GameState.baseline_result)
	var report: Control = await _go(&"report")
	assert_eq(report.name, "report")
	assert_eq(GameState.prediction, [&"power"] as Array[StringName])


func _launch() -> Control:
	_reference_design()
	GameState.start_mission()
	return await _go(&"run")


func test_operations_clock_runs_and_auto_pauses_on_a_pass_with_the_radio_off() -> void:
	var run: Control = await _launch()
	var m: Mission = GameState.mission
	var battery: LineChart = run._charts[0]
	assert_eq(battery.threshold, m.input.safe_enter_fraction * m.input.battery_capacity_j, "Safe mode line on the battery chart")
	# The screen also ticks on the frames GUT waited through. Pausing and resuming
	# clears any partial step and the next second is measured exactly.
	run._set_speed(0)
	run._set_speed(1)
	var before := m.state.step
	run._process(1.0)
	assert_eq(m.state.step - before, 240, "1x: 1 s of real time is 4 mission hours")
	run._radio.button_pressed = false
	run._process(6.0)
	assert_true(run._clock.paused, "the next pass stops the clock")
	var pressed: Array = run._speed_buttons.keys().filter(func(k): return run._speed_buttons[k].button_pressed)
	assert_eq(pressed, [0], "only Pause shows as selected")
	assert_true(run._decision.visible, "the decision panel opens")
	var titles: Array = run._options.get_children().map(func(b): return b.text.get_slice("\n", 0))
	assert_has(titles, "Radio on", "the obvious fix is offered")
	assert_has(titles, "Resume as is", "and so is changing nothing")
	assert_eq(run._decision_title.text, "Pass begins, radio off")
	assert_true(run._cards[&"radio"][1].visible, "the radio card is marked")
	assert_eq(run._cards[&"radio"][1].text, "On: sends data home")
	assert_false(run._cards[&"camera"][1].visible, "the camera does not matter for a pass")
	assert_false(run._log_parts[1].visible, "the log makes room for it")
	assert_gt(m.state.contact_starts, 0)
	var at := m.state.step
	run._process(1.0)
	assert_eq(m.state.step, at, "paused means paused")


func test_in_flight_change_reaches_the_report() -> void:
	var run: Control = await _launch()
	run._process(0.5)
	run._duty.value = 0.6
	assert_eq(GameState.mission.state.result.commands.size(), 1)
	run._finish_now()
	assert_eq(GameState.last_result.commands.size(), 1)
	var report: Control = await _go(&"report")
	var texts := report.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_true(texts.any(func(t): return t.contains("camera on 60 %")), "the change is listed")
	assert_true(texts.any(func(t): return t.contains("left alone")), "and compared with the untouched design")


func test_second_flight_compares_with_the_first() -> void:
	var run: Control = await _launch()
	run._finish_now()
	assert_null(GameState.previous_design, "nothing to compare after one flight")
	GameState.design.component_ids[2] = &"battery_100wh"
	GameState.start_mission()
	run = await _go(&"run")
	run._finish_now()
	assert_not_null(GameState.previous_design)
	assert_has(GameState.previous_design.component_ids, &"battery_43wh", "the copy kept the old battery")
	var report: Control = await _go(&"report")
	var texts := report.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(texts, "Last flight vs. this flight")
	assert_has(texts, "1 choice changed.")
	assert_has(texts, "No failures on either flight.")


func test_new_failures_make_the_comparison_part_luck() -> void:
	GameState.failure_mode = FailurePlan.Mode.TRAINING
	_reference_design()
	GameState.run_seed = 1
	GameState.start_mission()
	var run: Control = await _go(&"run")
	run._finish_now()
	GameState.start_mission()
	run = await _go(&"run")
	run._finish_now()
	var texts: Array = await _report_lines()
	assert_has(texts, "Both flights met the same failures.", "the same seed brings the same failures back")
	assert_false(GameState.baseline_result.events.filter(func(e): return e["kind"] == &"failure").is_empty(), "the baseline meets the failures")
	assert_true(GameState.design_result.events.filter(func(e): return e["kind"] == &"failure").is_empty(), "the prediction is checked without them")
	GameState.run_seed = 2
	GameState.start_mission()
	run = await _go(&"run")
	run._finish_now()
	assert_ne(GameState.last_failures, GameState.previous_failures)
	texts = await _report_lines()
	assert_has(texts, "The flights met different failures, so part of the difference is luck.")


func test_launch_waits_for_accepted_warnings() -> void:
	_reference_design()
	var parts := GameState.design.component_ids
	parts[parts.find(&"radio_s_band")] = &"radio_uhf"
	var launch: Control = await _go(&"launch")
	assert_not_null(launch._accept, "a UHF radio can't keep up, so there is something to accept")
	assert_true(launch._go.disabled, "no countdown before the risks are accepted")
	launch._accept.button_pressed = true
	assert_false(launch._go.disabled)
	launch._accept.button_pressed = false
	assert_true(launch._go.disabled)


func test_launch_pad_picks_the_failure_mode_and_draws_new_failures() -> void:
	_reference_design()
	var launch: Control = await _go(&"launch")
	var pick: OptionButton = launch._failure_pick
	assert_eq(pick.get_selected_id(), FailurePlan.Mode.NONE, "shows the current mode")
	assert_false(launch._redraw.visible, "nothing to redraw on a nominal flight")
	var i := pick.get_item_index(FailurePlan.Mode.TRAINING)
	pick.select(i)
	pick.item_selected.emit(i)
	assert_eq(GameState.failure_mode, FailurePlan.Mode.TRAINING)
	assert_true(launch._redraw.visible)
	var seed := GameState.run_seed
	launch._redraw.pressed.emit()
	assert_ne(GameState.run_seed, seed, "a new draw")
	assert_between(GameState.start_mission().failures.size(), 1, 3)
	launch._begin()
	assert_true(pick.disabled, "locked once the countdown starts")


func test_failure_mode_is_a_player_setting_that_outlives_a_mission() -> void:
	GameState.failure_mode = FailurePlan.Mode.UNCERTAIN
	_reference_design()
	assert_eq(GameState.failure_mode, FailurePlan.Mode.UNCERTAIN, "new_mission keeps it")
	var launch: Control = await _go(&"launch")
	assert_eq(launch._failure_pick.get_selected_id(), FailurePlan.Mode.UNCERTAIN, "and the launch pad shows it")


func test_launch_without_warnings_needs_no_acceptance() -> void:
	_reference_design()
	var launch: Control = await _go(&"launch")
	assert_null(launch._accept)
	assert_false(launch._go.disabled)


func _report_lines() -> Array:
	var report: Control = await _go(&"report")
	return report.find_children("*", "Label", true, false).map(func(l): return l.text)


func test_report_blames_a_downlink_limit_on_the_design() -> void:
	_reference_design()
	GameState.design.instrument_duty_cycle = 1.0
	GameState.start_mission()
	var run: Control = await _go(&"run")
	run._finish_now()
	var texts: Array = await _report_lines()
	assert_true(texts.any(func(t): return t.begins_with("Downlink:") and "minutes over the ground stations" in t), "explained with the pass time")
	assert_true(texts.any(func(t): return "comes from the design" in t))
	assert_has(texts, "Mission complete, goal met")


func test_report_blames_a_limit_on_the_changes_in_flight() -> void:
	var run: Control = await _launch()
	run._radio.button_pressed = false
	run._finish_now()
	var texts: Array = await _report_lines()
	assert_true(texts.any(func(t): return t.begins_with("Memory:")), "a silent radio fills the memory")
	assert_true(texts.any(func(t): return "came from the changes in flight" in t), "the design alone was fine")
	assert_has(texts, "Mission complete, goal missed", "surviving is not meeting the goal")
	assert_true(texts.any(func(t): return t.begins_with("In flight, your changes also brought: ") and Explain.factor(&"storage") in t), "the full memory came from the flying, not the design")
	assert_false(texts.any(func(t): return t.begins_with("Did not see coming")), "so it does not count against the guess")


func test_report_blames_a_limit_on_the_failures_not_the_guess() -> void:
	_reference_design()
	GameState.prediction.assign([] as Array[StringName])
	GameState.start_mission()
	# a solar loss far beyond failures.json, therefore the power limit is certain
	var plan: Array[Dictionary] = [{"t_s": 86400.0, "kind": &"solar_loss", "magnitude": 0.9}]
	GameState.mission = Mission.new(GameState.mission.input, GameState.mission.timeline, plan)
	var run: Control = await _go(&"run")
	run._finish_now()
	assert_false(&"power" in Outcome.limiting_factors(GameState.design_result), "the design alone has power to spare")
	var texts: Array = await _report_lines()
	assert_true(texts.any(func(t): return t.begins_with("Power:")))
	assert_true(texts.any(func(t): return "the failures in flight brought it" in t))
	assert_true(texts.any(func(t): return t.begins_with("In flight, failures or your changes also brought: ")), "named apart from the guess")
	assert_false(texts.any(func(t): return t.begins_with("Did not see coming")), "no guess could have seen it")


func test_picking_a_part_replaces_the_old_one() -> void:
	_reference_design()
	var design: Control = await _go(&"design")
	design._pick("battery", &"battery_100wh")
	assert_has(GameState.design.component_ids, &"battery_100wh")
	assert_does_not_have(GameState.design.component_ids, &"battery_43wh")
	design._pick("adcs", &"")
	assert_does_not_have(GameState.design.component_ids, &"adcs_small")


func test_menu_earth_turns_when_dragged() -> void:
	var orbit: OrbitView = app.current.find_children("*", "OrbitView", true, false)[0]
	await wait_process_frames(2)
	var center := orbit.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	orbit._gui_input(press)
	var spin_before := orbit._earth_spin
	var drag := InputEventMouseMotion.new()
	drag.position = center + Vector2(40, 20)
	drag.relative = Vector2(40, 20)
	orbit._gui_input(drag)
	assert_lt(orbit._earth_spin, spin_before, "dragging right turns the globe")
	assert_gt(orbit._pitch, 0.0)
	press.pressed = false
	orbit._gui_input(press)
	assert_false(orbit._dragging)


func test_drag_outside_the_planet_is_ignored() -> void:
	var orbit: OrbitView = app.current.find_children("*", "OrbitView", true, false)[0]
	await wait_process_frames(2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(2, 2)
	orbit._gui_input(press)
	assert_false(orbit._dragging)


func test_expanding_the_3d_view_hides_the_side_panels() -> void:
	_reference_design()
	var design: Control = await _go(&"design")
	design._preview.expand_toggled.emit(true)
	for p in design._side_panels:
		assert_false(p.visible)
	design._preview.expand_toggled.emit(false)
	for p in design._side_panels:
		assert_true(p.visible)


func test_operations_screen_fits_the_base_window_with_a_pause_banner() -> void:
	var run: Control = await _launch()
	run._set_speed(0)
	# worst case: every reason at once with a failure, and both restarts offered
	var s: SimState = GameState.mission.state
	s.radio_hung = true
	s.instrument_hung = true
	s.failures_started.assign([&"radio_hang"])
	GameState.mission.controls.duty_cycle = 1.0
	GameState.mission.controls.radio_enabled = false
	var every_reason: Array[StringName] = AutoPause.TRIGGERS.duplicate()
	run._auto_paused(every_reason)
	# and the widest header the mission can show
	run._day.text = "Day 30 of 30"
	run._mode.text = "SAFE MODE"
	run._goal.text = "Goal 100 %"
	await wait_process_frames(2)
	var page: Control = run.get_child(0)
	var needed := page.get_combined_minimum_size()
	assert_lte(needed.x, 1280.0, "width at 1280x720")
	assert_lte(needed.y, 720.0, "height at 1280x720")


func _paused_by(kind: StringName, duty := 0.2, radio := true) -> Control:
	_reference_design()
	GameState.design.instrument_duty_cycle = duty
	GameState.start_mission()
	var m := GameState.mission
	var plan: Array[Dictionary] = []
	if kind != &"":
		plan.append({"t_s": 86400.0, "kind": kind, "magnitude": 0.3})
	GameState.mission = Mission.new(m.input, m.timeline, plan)
	GameState.mission.controls.radio_enabled = radio
	var run: Control = await _go(&"run")
	run._set_speed(0)
	var fired: Array[StringName] = []
	while fired.is_empty() and not GameState.mission.state.done:
		fired = GameState.mission.advance(1)
	run._refresh()
	run._auto_paused(fired)
	return run


func _tags(run: Control) -> Dictionary:
	var out := {}
	for id in run._cards:
		if run._cards[id][1].visible:
			out[id] = run._cards[id][1].text
	return out


func test_permanent_failure_points_at_using_less_power_not_a_repair() -> void:
	for kind in [&"battery_fade", &"solar_loss"]:
		var run: Control = await _paused_by(kind)
		assert_eq(run._decision_title.text, Explain.failure_name(kind))
		assert_string_contains(run._decision_todo.text, "nothing repairs it")
		assert_eq(_tags(run), {&"camera": "Lower: saves power", &"radio": "Off: saves power in passes"}, "the controls that use power, no repair")
		assert_string_contains(run._faults.text, "permanent")
		assert_false(run._cycle_radio.visible or run._cycle_camera.visible, "no restart for a weaker part")
		assert_true(run._health_note.visible)
		run._resume()
		assert_eq(_tags(run), {}, "the marks go when the clock runs")


func test_each_pause_marks_only_the_controls_that_help() -> void:
	var cases := [
		[[AutoPause.LOW_BATTERY], true, {&"camera": "Lower: saves power", &"radio": "Off: saves power in passes"}],
		[[AutoPause.SAFE_ENTER], true, {&"camera": "Lower: saves power", &"radio": "Off: saves power in passes"}],
		[[AutoPause.CONTACT_BEGIN], false, {&"radio": "On: sends data home"}],
		[[AutoPause.STORAGE_HIGH], false, {&"camera": "Lower: makes less data", &"radio": "On: sends data home"}],
		[[AutoPause.LOW_BATTERY, AutoPause.STORAGE_HIGH], true, {&"camera": "Lower: less power and data"}],
	]
	for c in cases:
		var run: Control = await _launch()
		run._set_speed(0)
		GameState.mission.controls.radio_enabled = c[1]
		var fired: Array[StringName] = []
		fired.assign(c[0])
		run._auto_paused(fired)
		assert_eq(_tags(run), c[2], str(c[0]))
		assert_string_contains(run._decision_todo.text, "Marked on the right")


func test_hang_points_at_its_restart() -> void:
	for kind in [&"radio_hang", &"instrument_hang"]:
		var run: Control = await _paused_by(kind)
		var tags := _tags(run)
		assert_eq(tags.get(&"health"), "Restart clears it", String(kind))
		var button: Button = run._cycle_radio if kind == &"radio_hang" else run._cycle_camera
		assert_true(button.visible and not button.disabled, "its restart shows and works")
		assert_true(button.has_theme_stylebox_override("normal"), "and is marked as the recommended click")
		var titles: Array = run._options.get_children().map(func(b): return b.text.get_slice("\n", 0))
		assert_has(titles, "Restart radio" if kind == &"radio_hang" else "Restart camera")


func test_full_memory_with_the_radio_on_points_at_the_camera() -> void:
	var run: Control = await _paused_by(&"", 1.0, true)
	assert_has(run._fired, AutoPause.STORAGE_HIGH)
	var tags := _tags(run)
	assert_eq(tags.get(&"camera"), "Lower: makes less data")
	assert_false(tags.has(&"radio"), "the radio is already on")


func test_meeting_the_goal_says_the_mission_flies_on() -> void:
	_reference_design()
	# at half the time the reference design meets the goal before day 30
	GameState.design.instrument_duty_cycle = 0.5
	GameState.start_mission()
	var run: Control = await _go(&"run")
	run._set_speed(0)
	var m := GameState.mission
	while m.state.result.delivered_bits_total < run._goal_bits and not m.state.done:
		m.advance(60)
	run._refresh()
	assert_false(m.state.done, "the goal comes before the last day")
	assert_eq(run._goal.text, "Goal met")
	var log: Array = run._log.get_children().map(func(l): return l.text)
	assert_true(log.any(func(t): return "goal met" in t and "flies on to day 30" in t))
	assert_string_contains(run._forecast.text, "still runs to day 30")


func test_power_cycle_button_clears_a_hung_radio() -> void:
	_reference_design()
	GameState.start_mission()
	var m := GameState.mission
	GameState.mission = Mission.new(m.input, m.timeline, [{"t_s": 0.0, "kind": &"radio_hang", "magnitude": 0.0}])
	var run: Control = await _go(&"run")
	run._set_speed(0)
	run._mission.advance(5)
	run._refresh()
	assert_string_contains(run._faults.text, "LOCKED UP")
	assert_false(run._cycle_radio.disabled, "a hung radio can be restarted")
	assert_true(run._cycle_camera.disabled, "the camera is fine")
	run._cycle_radio.pressed.emit()
	assert_false(run._radio.button_pressed, "radio off for the cycle")
	assert_true(run._cycle_radio.disabled)
	run._mission.advance(1)
	run._refresh()
	assert_true(run._radio.button_pressed)
	assert_string_contains(run._faults.text, "nominal")


func test_report_lists_the_failures() -> void:
	_reference_design()
	GameState.start_mission()
	var m := GameState.mission
	GameState.mission = Mission.new(m.input, m.timeline, [{"t_s": 600.0, "kind": &"solar_loss", "magnitude": 0.25}])
	var run: Control = await _go(&"run")
	run._finish_now()
	var report: Control = await _go(&"report")
	var texts := report.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_true(texts.any(func(t): return "Solar string failed" in t))


func test_menu_opens_how_to_play_and_comes_back() -> void:
	app.current.find_child("HowToPlayButton", true, false).pressed.emit()
	# the menu plays its press and fade first
	await wait_seconds(0.5)
	assert_eq(app.current.name, "how_to_play")
	EventBus.screen_requested.emit(&"main_menu")
	await wait_process_frames(2)
	assert_eq(app.current.name, "main_menu")
