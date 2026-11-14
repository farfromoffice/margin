extends Control
## The operations screen. The mission runs live on the mission clock and the player
## can change the camera duty cycle and the radio while it runs. Auto pause stops
## the clock when a decision is due. Hardware, orbit and launcher stay fixed.
## DESIGN.md describes the clock and the auto pause rules.

## Speed of the craft in the orbit view in radians per real second. A real orbit
## takes 0.4 s at 1x and would blur. This pace stays readable.
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
var _duty_effect: Label
var _radio_effect: Label
var _goal: Label
## goal in bits, 0 for a scenario without one (the sandbox)
var _goal_bits := 0.0
var _on_track := true
## The auto-pause panel: the reason, what happens if nothing changes and the
## options with their effects. The mission log hides while it is open.
var _decision: PanelContainer
var _decision_outlook: Label
var _options: HFlowContainer
var _log_parts: Array[Control] = []
## speed the clock goes back to after a decision
var _last_speed := 1
var _faults: Label
var _cycle_radio: Button
var _cycle_camera: Button
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
	_goal_bits = float(GameState.scenario().objectives.get(&"delivered_mb", 0.0)) * Outcome.BITS_PER_MB
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
	var head := UiStyle.hbox(12)
	head.add_child(UiStyle.section(GameState.scenario().title, "satellite", 26))
	_day = UiStyle.label("", 20)
	_mode = UiStyle.label("", 20)
	_day.theme_type_variation = &"DisplayLabel"
	_mode.theme_type_variation = &"DisplayLabel"
	head.add_child(_day)
	head.add_child(_mode)
	_goal = UiStyle.label("", 20)
	_goal.theme_type_variation = &"DisplayLabel"
	_goal.visible = _goal_bits > 0.0
	head.add_child(_goal)
	left.add_child(head)
	var box := UiStyle.vbox(8)
	_banner = UiStyle.label("", 17, UiStyle.WARN, true)
	box.add_child(_banner)
	_decision_outlook = UiStyle.label("", 15, UiStyle.TEXT, true)
	box.add_child(_decision_outlook)
	_options = HFlowContainer.new()
	_options.add_theme_constant_override("h_separation", 8)
	_options.add_theme_constant_override("v_separation", 8)
	box.add_child(_options)
	_decision = UiStyle.panel(box)
	_decision.visible = false
	left.add_child(_decision)

	var battery := _chart("Battery", UiStyle.GOOD, input.battery_capacity_j,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(input.battery_capacity_j, 1.0)))
	battery.modes = r.mode
	battery.threshold = input.safe_enter_fraction * input.battery_capacity_j
	battery.threshold_label = "Safe mode below %d %%" % roundi(input.safe_enter_fraction * 100.0)
	_chart("Memory used", UiStyle.WARN, input.storage_capacity_bits,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(input.storage_capacity_bits, 1.0)))
	var sent := _chart("Data sent home", UiStyle.DATA, 1.0, func(v: float) -> String: return Explain.mb(v))
	if _goal_bits > 0.0:
		sent.threshold = _goal_bits
		sent.threshold_label = "Goal %s" % Explain.mb(_goal_bits)
		sent.threshold_color = UiStyle.ACCENT
	for c in _charts:
		left.add_child(c)
	left.add_child(UiStyle.label("Red bands: Safe mode, the camera was off and the radio only listened.", 14, UiStyle.MUTED))
	var log_title := UiStyle.section("Mission log", "flag", 18)
	left.add_child(log_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 90
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = UiStyle.vbox(4)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log)
	left.add_child(scroll)
	_log_parts = [log_title, scroll]
	return left


func _build_side() -> Control:
	var side := UiStyle.vbox(10)
	side.custom_minimum_size.x = 340
	_orbit = OrbitView.new()
	_orbit.auto_spin = false
	_orbit.custom_minimum_size = Vector2(300, 110)
	_orbit.eclipse_fraction = _mission.timeline.eclipse_fraction
	side.add_child(_orbit)

	# The controls scroll when the window is small. The orbit view stays on top and
	# the two buttons stay at the bottom, where the report button is always visible.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := UiStyle.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	side.add_child(scroll)

	body.add_child(UiStyle.section("Mission clock", "orbit"))
	var speeds := UiStyle.hbox(6)
	var group := ButtonGroup.new()
	for speed in [0] + MissionClock.SPEEDS:
		var b := UiStyle.button("Pause" if speed == 0 else "%d×" % speed, _set_speed.bind(speed))
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_speed_buttons[speed] = b
		speeds.add_child(b)
	body.add_child(speeds)

	body.add_child(UiStyle.section("Operations", "camera"))
	_duty_label = UiStyle.label("", 16)
	body.add_child(_duty_label)
	_duty = HSlider.new()
	_duty.min_value = 0.0
	_duty.max_value = 1.0
	_duty.step = Warnings.DUTY_STEP
	_duty.value = _mission.controls.duty_cycle
	_duty.value_changed.connect(func(v: float):
		_duty_label.text = Explain.duty(v)
		# while dragging, the lines below preview the value under the thumb
		_show_effects(v)
		if not _duty_dragging:
			_set_control(Controls.DUTY_CYCLE, v))
	# A drag passes many values on the way. Only the value where it ends is logged.
	_duty.drag_started.connect(func(): _duty_dragging = true)
	_duty.drag_ended.connect(func(_changed: bool):
		_duty_dragging = false
		_set_control(Controls.DUTY_CYCLE, _duty.value))
	_duty_label.text = Explain.duty(_duty.value)
	body.add_child(_duty)
	_duty_effect = UiStyle.label("", 14, UiStyle.MUTED, true)
	_duty_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_duty_effect)
	_radio = CheckButton.new()
	_radio.text = "Radio sends data during passes"
	_radio.button_pressed = _mission.controls.radio_enabled
	_radio.toggled.connect(func(on: bool): _set_control(Controls.RADIO_ENABLED, on))
	body.add_child(_radio)
	_radio_effect = UiStyle.label("", 14, UiStyle.MUTED, true)
	_radio_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_radio_effect)
	body.add_child(UiStyle.section("Spacecraft health", "chip"))
	_faults = UiStyle.label("", 15, UiStyle.TEXT, true)
	_faults.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_faults)
	var cycles := UiStyle.vbox(6)
	_cycle_radio = UiStyle.button("Restart radio (clears a lock-up)", _power_cycle.bind(Controls.RADIO_ENABLED))
	_cycle_camera = UiStyle.button("Restart camera (clears a freeze)", _power_cycle.bind(Controls.DUTY_CYCLE))
	_cycle_radio.tooltip_text = "Switches the radio off for one minute and back on. Only needed when it locks up."
	_cycle_camera.tooltip_text = "Switches the camera off for one minute and back on. Only needed when it freezes. To turn it off, move the slider to 0."
	for b in [_cycle_radio, _cycle_camera]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cycles.add_child(b)
	body.add_child(cycles)
	_forecast = UiStyle.label("", 15, UiStyle.MUTED, true)
	_forecast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_forecast)

	body.add_child(UiStyle.section("Auto-pause", "flag"))
	var triggers := GridContainer.new()
	triggers.columns = 2
	for trigger in AutoPause.TRIGGERS:
		var cb := CheckBox.new()
		cb.text = Explain.PAUSE_NAMES[trigger]
		cb.button_pressed = _mission.auto_pause.enabled[trigger]
		cb.toggled.connect(func(on: bool): _mission.auto_pause.enabled[trigger] = on)
		triggers.add_child(cb)
	body.add_child(triggers)

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
		_last_speed = speed
		_show_decision(false)
	# set_pressed_no_signal does not release the other buttons of the group.
	for s in _speed_buttons:
		_speed_buttons[s].set_pressed_no_signal(s == speed)


## _set_control applies a change and logs it with what it does: the energy per
## orbit and the projected data at home before and after.
func _set_control(control: StringName, value: Variant) -> void:
	var logged := _mission.state.result.commands.size()
	var before := _outlook(_mission.controls)
	_mission.set_control(control, value)
	var commands := _mission.state.result.commands
	if commands.size() > logged:
		var after := _outlook(_mission.controls)
		_log_line("%s. %s" % [Explain.command(commands.back()), Explain.change(before, after, _goal_bits)], UiStyle.CYAN)
		_update_forecast()


## _outlook returns {forecast, projected} for a set of controls, the numbers the
## effect lines, the log and the auto pause options compare.
func _outlook(c: Controls) -> Dictionary:
	var f := Warnings.forecast(_mission.input, c, _mission.timeline, _mission.state)
	return {"forecast": f, "projected": Warnings.projected_delivered_bits(_mission.input, _mission.timeline, c, _mission.state)}


## _controls_with copies the current controls with one of them changed.
func _controls_with(control: StringName, value: Variant) -> Controls:
	var c := Controls.new()
	c.duty_cycle = _mission.controls.duty_cycle
	c.radio_enabled = _mission.controls.radio_enabled
	c.apply(control, value)
	return c


## _show_effects fills the lines under the camera slider and the radio switch for
## a camera time, the current one or the one under a dragged thumb.
func _show_effects(duty: float) -> void:
	if _mission.state.done:
		_duty_effect.text = ""
		_radio_effect.text = ""
		return
	var f := Warnings.forecast(_mission.input, _controls_with(Controls.DUTY_CYCLE, duty), _mission.timeline, _mission.state)
	_duty_effect.text = Explain.power_effect(f)
	_duty_effect.add_theme_color_override("font_color", UiStyle.GOOD if float(f["energy_per_orbit_j"]) >= 0.0 else UiStyle.WARN)
	_radio_effect.text = Explain.data_effect(f)
	var piles_up := float(f["generated_bits_per_day"]) > float(f["sendable_bits_per_day"])
	_radio_effect.add_theme_color_override("font_color", UiStyle.WARN if piles_up else UiStyle.MUTED)


## Power cycles take one mission step, so they also work while paused: the
## switch back happens on the first step after the clock resumes.
func _power_cycle(control: StringName) -> void:
	var logged := _mission.state.result.commands.size()
	_mission.power_cycle(control)
	var commands := _mission.state.result.commands
	for i in range(logged, commands.size()):
		_log_line(Explain.command(commands[i]) + " (power cycle)", UiStyle.CYAN)
	_sync_controls()
	_refresh_health()


func _auto_paused(fired: Array[StringName]) -> void:
	_set_speed(0)
	# one sound per pause, the most serious reason wins
	if AutoPause.FAILURE in fired:
		Sfx.play(&"failure")
	elif AutoPause.SAFE_ENTER in fired:
		Sfx.play(&"safe_mode")
	else:
		Sfx.play(&"pause")
	var text := Explain.pause_reasons(fired)
	if AutoPause.FAILURE in fired:
		var alerts := _mission.state.failures_started.map(func(k): return Explain.failure_alert(k))
		text = (" ".join(alerts) + " " + text).strip_edges()
	_banner.text = "Paused, %s. %s" % [Explain.mission_time(_mission.state.t_s), text]
	var now := _outlook(_mission.controls)
	var lines := [Explain.goal_outlook(now["projected"], _goal_bits)] + Explain.forecast(now["forecast"], _mission.state, true)
	_decision_outlook.text = "If nothing changes: " + ". ".join(lines) + "."
	for child in _options.get_children():
		child.queue_free()
	# The options only lay out the choice. Each shows what it does; none is applied
	# until the player presses it and keeping everything as it is is always one.
	for c in Warnings.choices(fired, _mission.input, _mission.timeline, _mission.controls, _mission.state):
		_options.add_child(UiStyle.button("%s\n%s" % [Explain.choice(c), _choice_effect(c, now)], _choose.bind(c)))
	_options.add_child(UiStyle.button("Keep going\nchange nothing", _resume))
	_show_decision(true)
	for f in fired:
		_log_line("%s: paused, %s." % [Explain.mission_time(_mission.state.t_s), Explain.PAUSE_NAMES[f].to_lower()], UiStyle.WARN)
	_update_forecast()


func _choice_effect(c: Dictionary, now: Dictionary) -> String:
	if c["kind"] == &"restart":
		return "off for a minute, then back on"
	var control := Controls.DUTY_CYCLE if c["kind"] == &"duty" else Controls.RADIO_ENABLED
	return Explain.choice_effect(now, _outlook(_controls_with(control, c["value"])), _goal_bits)


## _choose applies an auto-pause option and lets the clock run again.
func _choose(c: Dictionary) -> void:
	match c["kind"]:
		&"duty":
			_set_control(Controls.DUTY_CYCLE, c["value"])
		&"radio":
			_set_control(Controls.RADIO_ENABLED, c["value"])
		&"restart":
			_power_cycle(c["value"])
	_sync_controls()
	_resume()


func _resume() -> void:
	_set_speed(_last_speed)


func _show_decision(on: bool) -> void:
	_decision.visible = on
	for part in _log_parts:
		part.visible = not on


## _refresh redraws the charts, labels and log once per frame, however many steps
## ran in that frame.
func _refresh() -> void:
	var s := _mission.state
	var r := s.result
	var progress := float(s.step) / maxf(s.total_steps, 1)
	var series := [r.energy_j, r.stored_bits, r.delivered_bits]
	for i in _charts.size():
		# Packed arrays are copy on write. The chart gets the current buffer every frame.
		_charts[i].values = series[i]
		_charts[i].total_steps = s.total_steps
		_charts[i].progress = progress
	_charts[0].modes = r.mode
	_charts[2].max_value = maxf(maxf(r.delivered_bits_total, _goal_bits * 1.25), 1.0)
	if _goal_bits > 0.0:
		_goal.text = "Goal %d %%" % mini(floori(100.0 * r.delivered_bits_total / _goal_bits), 100)
		var met := r.delivered_bits_total >= _goal_bits
		_goal.add_theme_color_override("font_color", UiStyle.GOOD if met or _on_track else UiStyle.WARN)
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
	_sync_controls()
	_refresh_health()


## Power cycles move the controls behind the widgets' backs, this puts them back
## in line without logging anything.
func _sync_controls() -> void:
	if not _duty_dragging and not is_equal_approx(_duty.value, _mission.controls.duty_cycle):
		_duty.set_value_no_signal(_mission.controls.duty_cycle)
		_duty_label.text = Explain.duty(_duty.value)
	_radio.set_pressed_no_signal(_mission.controls.radio_enabled)


func _refresh_health() -> void:
	var s := _mission.state
	var lines: Array[String] = []
	if s.radio_hung:
		lines.append("Radio: LOCKED UP, sends nothing")
	if s.instrument_hung:
		lines.append("Camera: FROZEN, takes no pictures")
	if s.battery_health < 1.0:
		lines.append("Battery: holds %d %% of its design capacity" % roundi(s.battery_health * 100.0))
	if s.solar_health < 1.0:
		lines.append("Solar array: %d %% of its design output" % roundi(s.solar_health * 100.0))
	_faults.text = "All systems nominal" if lines.is_empty() else "\n".join(lines)
	_faults.add_theme_color_override("font_color", UiStyle.GOOD if lines.is_empty() else UiStyle.WARN)
	_cycle_radio.disabled = s.done or not s.radio_hung or _mission.is_cycling(Controls.RADIO_ENABLED)
	_cycle_camera.disabled = s.done or not s.instrument_hung or _mission.is_cycling(Controls.DUTY_CYCLE) \
			or _mission.controls.duty_cycle <= 0.0
	# the fix is the obvious next click, so it lights up while something is hung
	_cycle_radio.modulate = UiStyle.WARN if s.radio_hung else Color.WHITE
	_cycle_camera.modulate = UiStyle.WARN if s.instrument_hung else Color.WHITE


func _update_forecast() -> void:
	var s := _mission.state
	_forecast_day = int(s.t_s / 86400.0)
	if s.done:
		_forecast.text = ""
		return
	var now := _outlook(_mission.controls)
	_on_track = float(now["projected"]) >= _goal_bits
	var lines := [Explain.goal_outlook(now["projected"], _goal_bits)] + Explain.forecast(now["forecast"], s)
	_forecast.text = "Estimate with these settings (averages over orbits and passes):\n" + "\n".join(lines)
	if not _duty_dragging:
		_show_effects(_mission.controls.duty_cycle)


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
	_show_decision(false)
	_forecast.text = ""
	_show_effects(0.0)
	var r := _mission.state.result
	if r.end_reason == RunResult.EndReason.COMPLETED:
		_log_line("Mission complete. %s sent home." % Explain.mb(r.delivered_bits_total), UiStyle.GOOD)


func _log_event(e: Dictionary) -> void:
	var day := int(float(e["t_s"]) / 86400.0) + 1
	EventBus.event_fired.emit(e["kind"])
	if day != _log_day:
		_flush_day()
		_log_day = day
	match e["kind"]:
		&"failure":
			_log_line("%s: FAILURE, %s." % [Explain.mission_time(float(e["t_s"])), Explain.failure_name(e["failure"]).to_lower()], UiStyle.BAD)
			return
		&"recovered":
			_log_line("%s: %s cleared by the restart." % [Explain.mission_time(float(e["t_s"])), Explain.failure_name(e["failure"])], UiStyle.GOOD)
			return
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
	# Three charts at the default 130 px leave no room for the pause banner at 720 px.
	# They still grow to fill a larger window.
	c.custom_minimum_size.y = 100
	c.title = title
	c.color = color
	c.max_value = maxf(max_value, 1.0)
	c.format = format
	_charts.append(c)
	return c
