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
	assert_not_null(GameState.last_result)
	run._set_progress(1.0)
	assert_false(run._report.disabled)
	var report: Control = await _go(&"report")
	assert_eq(report.name, "report")
	assert_eq(GameState.prediction, [&"power"] as Array[StringName])


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
