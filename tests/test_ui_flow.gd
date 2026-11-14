extends GutTest
## Clicks through every screen headless. Catches screens that fail to build,
## not layout problems; those need eyes on a real window.

var app: Control


func before_each() -> void:
	# random failures would make the pause tests flaky, the ones that want a
	# failure plant their own
	GameState.live_failures = false
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
	assert_has(titles, "Resume", "and so is changing nothing")
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
