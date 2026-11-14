extends Control
## Mission operations. The mission flies live on the mission clock; the player
## can change the camera duty cycle and the radio while it runs, and auto-pause
## stops the clock when a decision is due. Hardware, orbit and launcher are
## locked. Rules in DESIGN.md ("Mission clock", "Auto-pause").

## how fast the craft goes round the orbit view, radians per real second.
## Real orbits would blur at 1x (one every 0.4 s). It turns at a readable pace.
const ORBIT_VIEW_SPIN := 0.9

var _mission: Mission
var _clock: MissionClock
var _charts: Array[LineChart] = []
var _day: Label
var _mode: Label
var _banner: Label
var _log: VBoxContainer
var _orbit: OrbitView
var _speed_buttons := {}
var _duty: HSlider
var _duty_label: Label
var _duty_dragging := false
var _radio: CheckButton
var _forecast: Label
var _finish: Button
var _report: Button
var _next_event := 0
var _shown_day := -1
var _forecast_day := -1
var _ended := false
## event kind -> how often it fired on the day being logged. A weak design can
## flip in and out of Safe mode every orbit, one line each would bury the log.
var _day_counts := {}
var _log_day := -1


func _ready() -> void:
	_mission = GameState.mission
	_clock = MissionClock.new(_mission.input.dt_s)
	var page := UiStyle.page(self, 20)
	var row := UiStyle.hbox(16)
	page.add_child(row)
	row.add_child(_build_main())
	row.add_child(_build_side())
	_log_line("Day 1: launch. Battery full, memory empty.", UiStyle.TEXT)
	_set_speed(1)
	_refresh()
	_update_forecast()


func _build_main() -> Control:
	var input := _mission.input
	var r := _mission.state.result
	var left := UiStyle.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UiStyle.hbox(20)
	head.add_child(UiStyle.section("%s  ·  Operations" % GameState.scenario().title, "satellite", 26))
	_day = UiStyle.label("", 20)
	_mode = UiStyle.label("", 20)
	_day.theme_type_variation = &"DisplayLabel"
	_mode.theme_type_variation = &"DisplayLabel"
	head.add_child(_day)
	head.add_child(_mode)
	left.add_child(head)
	_banner = UiStyle.label("", 17, UiStyle.WARN, true)
	left.add_child(UiStyle.panel(_banner))
	_banner.get_parent().visible = false

	var battery := _chart("Battery", UiStyle.GOOD, input.battery_capacity_j,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(input.battery_capacity_j, 1.0)))
	battery.modes = r.mode
	_chart("Memory used", UiStyle.WARN, input.storage_capacity_bits,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(input.storage_capacity_bits, 1.0)))
	_chart("Data sent home", UiStyle.DATA, 1.0, func(v: float) -> String: return Explain.mb(v))
	for c in _charts:
		left.add_child(c)
	left.add_child(UiStyle.label("Red bands: Safe mode, the camera was off and the radio only listened.", 14, UiStyle.MUTED))
	left.add_child(UiStyle.section("Mission log", "flag", 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = UiStyle.vbox(4)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log)
	left.add_child(scroll)
	return left


func _build_side() -> Control:
	var side := UiStyle.vbox(10)
	side.custom_minimum_size.x = 340
	_orbit = OrbitView.new()
	_orbit.auto_spin = false
	_orbit.custom_minimum_size = Vector2(300, 150)
	_orbit.eclipse_fraction = _mission.timeline.eclipse_fraction
	side.add_child(_orbit)

	side.add_child(UiStyle.section("Mission clock", "orbit"))
	var speeds := UiStyle.hbox(6)
	var group := ButtonGroup.new()
	for speed in [0] + MissionClock.SPEEDS:
		var b := UiStyle.button("Pause" if speed == 0 else "%d×" % speed, _set_speed.bind(speed))
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_speed_buttons[speed] = b
		speeds.add_child(b)
	side.add_child(speeds)

	side.add_child(UiStyle.section("Operations", "camera"))
	_duty_label = UiStyle.label("", 16)
	side.add_child(_duty_label)
	_duty = HSlider.new()
	_duty.min_value = 0.0
	_duty.max_value = 1.0
	_duty.step = 0.05
	_duty.value = _mission.controls.duty_cycle
	_duty.value_changed.connect(func(v: float):
		_duty_label.text = "Camera on %d %% of the time" % roundi(v * 100.0)
		if not _duty_dragging:
			_set_control(Controls.DUTY_CYCLE, v))
	# a drag would log every tick it passes; only where it lands is a decision
	_duty.drag_started.connect(func(): _duty_dragging = true)
	_duty.drag_ended.connect(func(_changed: bool):
		_duty_dragging = false
		_set_control(Controls.DUTY_CYCLE, _duty.value))
	_duty_label.text = "Camera on %d %% of the time" % roundi(_duty.value * 100.0)
	side.add_child(_duty)
	_radio = CheckButton.new()
	_radio.text = "Radio sends data during passes"
	_radio.button_pressed = _mission.controls.radio_enabled
	_radio.toggled.connect(func(on: bool): _set_control(Controls.RADIO_ENABLED, on))
	side.add_child(_radio)
	_forecast = UiStyle.label("", 15, UiStyle.MUTED, true)
	side.add_child(_forecast)

	side.add_child(UiStyle.section("Auto-pause", "flag"))
	for trigger in AutoPause.TRIGGERS:
		var cb := CheckBox.new()
		cb.text = Explain.PAUSE_NAMES[trigger]
		cb.button_pressed = _mission.auto_pause.enabled[trigger]
		cb.toggled.connect(func(on: bool): _mission.auto_pause.enabled[trigger] = on)
		side.add_child(cb)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_finish = UiStyle.button("Fly to the end, no more pauses", _finish_now)
	_report = UiStyle.button("Read the report", func(): EventBus.screen_requested.emit(&"report"))
	_report.icon = UiStyle.icon("data")
	_report.disabled = true
	side.add_child(_finish)
	side.add_child(_report)
	var p := UiStyle.panel(side)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


func _process(delta: float) -> void:
	if _ended:
		return
	if not _clock.paused:
		_orbit.angle = fmod(_orbit.angle + delta * ORBIT_VIEW_SPIN, TAU)
	var steps := _clock.advance(delta)
	if steps <= 0:
		return
	var fired := _mission.advance(steps)
	_refresh()
	if not fired.is_empty():
		_auto_paused(fired)
	if _mission.state.done:
		_end()


func _set_speed(speed: int) -> void:
	_clock.set_paused(speed == 0)
	if speed > 0:
		_clock.set_speed(speed)
		_banner.get_parent().visible = false
	_speed_buttons[speed].set_pressed_no_signal(true)


func _set_control(control: StringName, value: Variant) -> void:
	var logged := _mission.state.result.commands.size()
	_mission.set_control(control, value)
	var commands := _mission.state.result.commands
	if commands.size() > logged:
		_log_line(Explain.command(commands.back()), UiStyle.CYAN)
		_update_forecast()


func _auto_paused(fired: Array[StringName]) -> void:
	_set_speed(0)
	_banner.text = "Paused, %s. %s" % [Explain.mission_time(_mission.state.t_s), Explain.pause_reasons(fired)]
	_banner.get_parent().visible = true
	for f in fired:
		_log_line("%s: paused, %s." % [Explain.mission_time(_mission.state.t_s), Explain.PAUSE_NAMES[f].to_lower()], UiStyle.WARN)
	_update_forecast()


## Redraws once per frame however many steps ran; never per step.
func _refresh() -> void:
	var s := _mission.state
	var r := s.result
	var progress := float(s.step) / maxf(s.total_steps, 1)
	var series := [r.energy_j, r.stored_bits, r.delivered_bits]
	for i in _charts.size():
		# packed arrays are copy on write, so hand the chart the current buffer
		_charts[i].values = series[i]
		_charts[i].total_steps = s.total_steps
		_charts[i].progress = progress
	_charts[0].modes = r.mode
	_charts[2].max_value = maxf(r.delivered_bits_total, 1.0)
	var days_total := int(_mission.input.duration_s / 86400.0)
	var day := int(s.t_s / 86400.0)
	if day != _shown_day:
		_shown_day = day
		_day.text = "Day %d of %d" % [mini(day + 1, days_total), days_total]
		EventBus.sim_tick.emit(day)
	var safe := s.mode == RunResult.Mode.SAFE
	_mode.text = "SAFE MODE" if safe else "Normal"
	_mode.add_theme_color_override("font_color", UiStyle.BAD if safe else UiStyle.GOOD)
	while _next_event < r.events.size():
		_log_event(r.events[_next_event])
		_next_event += 1
	if day != _forecast_day:
		_update_forecast()


func _update_forecast() -> void:
	var s := _mission.state
	_forecast_day = int(s.t_s / 86400.0)
	if s.done:
		_forecast.text = ""
		return
	var f := Warnings.forecast(_mission.input, _mission.controls, _mission.timeline, s)
	var lines := Explain.forecast(f, s)
	_forecast.text = "Estimate with these settings (averages over orbits and passes):\n" + "\n".join(lines)


func _finish_now() -> void:
	_mission.finish()
	_refresh()
	_end()


func _end() -> void:
	if _ended:
		return
	_ended = true
	_clock.set_paused(true)
	_flush_day()
	GameState.finish_mission()
	for b in _speed_buttons.values():
		b.disabled = true
	_duty.editable = false
	_radio.disabled = true
	_finish.disabled = true
	_report.disabled = false
	_banner.get_parent().visible = false
	_forecast.text = ""
	var r := _mission.state.result
	if r.end_reason == RunResult.EndReason.COMPLETED:
		_log_line("Mission complete. %s sent home." % Explain.mb(r.delivered_bits_total), UiStyle.GOOD)


func _log_event(e: Dictionary) -> void:
	var day := int(float(e["t_s"]) / 86400.0) + 1
	EventBus.event_fired.emit(e["kind"])
	if day != _log_day:
		_flush_day()
		_log_day = day
	var seen: int = _day_counts.get(e["kind"], 0)
	_day_counts[e["kind"]] = seen + 1
	if seen > 0:
		return
	match e["kind"]:
		&"safe_enter":
			_log_line("Day %d: battery low, Safe mode on." % day, UiStyle.BAD)
		&"safe_exit":
			_log_line("Day %d: battery recharged, back to work." % day, UiStyle.GOOD)
		&"power_lost":
			_log_line("Day %d: the battery is empty. Mission lost." % day, UiStyle.BAD)


func _flush_day() -> void:
	var entries: int = _day_counts.get(&"safe_enter", 0)
	if entries > 1:
		_log_line("Day %d: Safe mode %d times that day." % [_log_day, entries], UiStyle.BAD)
	_day_counts.clear()


func _log_line(text: String, color: Color) -> void:
	_log.add_child(UiStyle.label(text, 15, color, true))


func _chart(title: String, color: Color, max_value: float, format: Callable) -> LineChart:
	var c := LineChart.new()
	c.title = title
	c.color = color
	c.max_value = maxf(max_value, 1.0)
	c.format = format
	_charts.append(c)
	return c
