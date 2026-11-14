extends GutTest
## Clicks through every screen headless. Catches screens that fail to build,
## not layout problems; those need eyes on a real window.

var app: Control


func before_each() -> void:
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
	app.current.get_node("Center/Menu/PlayButton").pressed.emit()
	await wait_process_frames(2)
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
	# the screen also ticks on the frames GUT waited through; pausing and
	# resuming clears any part step so the next second is measured exactly
	run._set_speed(0)
	run._set_speed(1)
	var before := m.state.step
	run._process(1.0)
	assert_eq(m.state.step - before, 240, "1x: 1 s of real time is 4 mission hours")
	run._radio.button_pressed = false
	run._process(6.0)
	assert_true(run._clock.paused, "the next pass stops the clock")
	assert_true(run._banner.get_parent().visible)
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
