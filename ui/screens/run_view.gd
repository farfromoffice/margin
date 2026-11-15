extends Control
## The operations screen. The mission runs live on the mission clock and the player
## can change the camera duty cycle and the radio while it runs. Auto pause stops
## the clock when a decision is due. Hardware, orbit and launcher stay fixed.
## DESIGN.md describes the clock and the auto pause rules.

## Speed of the craft in the orbit view in radians per real second. A real orbit
## takes 0.4 s at 1x and would blur. This pace stays readable.
const ORBIT_VIEW_SPIN := 0.9
## minimum chart height and the smaller one while the auto-pause panel is open
const CHART_MIN := 100.0
const CHART_MIN_DECIDING := 64.0

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
var _decision_icon: TextureRect
var _decision_title: Label
var _decision_time: Label
var _decision_todo: Label
var _decision_facts: Label
var _decision_outlook: Label
## reasons of the open auto-pause, kept to refresh the panel when a control changes
var _fired: Array[StringName] = []
var _options: HFlowContainer
var _log_parts: Array[Control] = []
## speed the clock goes back to after a decision
var _last_speed := 1
var _faults: Label
var _health_note: Label
var _side_scroll: ScrollContainer
## sidebar groups by id -> [panel, tag], see _card and _mark
var _cards := {}
var _card_style := UiStyle._box(UiStyle.PANEL_LIGHT, 8, 10, UiStyle.LINE, 1)
## a card that can help with the open pause: an accent edge, no flashing
var _card_marked := UiStyle._box(UiStyle.PANEL_LIGHT, 8, 10, UiStyle.ACCENT, 2)
## the one action that only helps, a restart of a hung part
var _recommended := UiStyle._box(UiStyle.ACCENT.darkened(0.6), 6, 10, UiStyle.ACCENT, 2)
## goal met already logged, so the line comes once
var _goal_logged := false
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
	# the pause panel reads top to bottom: what happened, what can be done about
	# it, then where the mission ends up if it resumes as is
	var box := UiStyle.vbox(6)
	var title_row := UiStyle.hbox(10)
	_decision_icon = UiStyle.icon_rect("flag", 22, UiStyle.WARN)
	title_row.add_child(_decision_icon)
	_decision_title = UiStyle.label("", 19, UiStyle.WARN, true)
	_decision_title.theme_type_variation = &"DisplayLabel"
	title_row.add_child(_decision_title)
	_decision_time = UiStyle.label("", 14, UiStyle.MUTED)
	title_row.add_child(_decision_time)
	box.add_child(title_row)
	_banner = UiStyle.label("", 15, UiStyle.TEXT, true)
	box.add_child(_banner)
	_decision_todo = UiStyle.label("", 15, UiStyle.CYAN, true)
	box.add_child(_decision_todo)
	_decision_facts = UiStyle.label("", 14, UiStyle.MUTED, true)
	box.add_child(_decision_facts)
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
	var bands_note := UiStyle.label("Red bands: Safe mode, the camera was off and the radio only listened.", 14, UiStyle.MUTED)
	left.add_child(bands_note)
	var log_title := UiStyle.section("Mission log", "flag", 18)
	left.add_child(log_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 90
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = UiStyle.vbox(4)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log)
	left.add_child(scroll)
	_log_parts = [bands_note, log_title, scroll]
	return left


func _build_side() -> Control:
	var side := UiStyle.vbox(10)
	side.custom_minimum_size.x = 340
	_orbit = OrbitView.new()
	_orbit.auto_spin = false
	_orbit.custom_minimum_size = Vector2(300, 84)
	_orbit.eclipse_fraction = _mission.timeline.eclipse_fraction
	side.add_child(_orbit)

	# The controls scroll when the window is small. The orbit view stays on top and
	# the two buttons stay at the bottom, where the report button is always visible.
	_side_scroll = ScrollContainer.new()
	_side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := UiStyle.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_scroll.add_child(body)
	side.add_child(_side_scroll)

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

	var camera := _card(&"camera", "Camera", "camera")
	body.add_child(_cards[&"camera"][0])
	_duty_label = UiStyle.label("", 16)
	camera.add_child(_duty_label)
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
	camera.add_child(_duty)
	_duty_effect = UiStyle.label("", 14, UiStyle.MUTED, true)
	camera.add_child(_duty_effect)

	var radio := _card(&"radio", "Radio", "antenna")
	body.add_child(_cards[&"radio"][0])
	_radio = CheckButton.new()
	_radio.text = "Sends data during passes"
	# the switch shows on and off; the button look of the theme would paint the
	# whole row orange like a pressed alarm
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		_radio.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_radio.button_pressed = _mission.controls.radio_enabled
	_radio.toggled.connect(func(on: bool): _set_control(Controls.RADIO_ENABLED, on))
	radio.add_child(_radio)
	_radio_effect = UiStyle.label("", 14, UiStyle.MUTED, true)
	radio.add_child(_radio_effect)

	var health := _card(&"health", "Spacecraft health", "chip")
	body.add_child(_cards[&"health"][0])
	_faults = UiStyle.label("", 15, UiStyle.TEXT, true)
	health.add_child(_faults)
	_cycle_radio = UiStyle.button("Restart radio", _power_cycle.bind(Controls.RADIO_ENABLED))
	_cycle_camera = UiStyle.button("Restart camera", _power_cycle.bind(Controls.DUTY_CYCLE))
	_cycle_radio.tooltip_text = "Switches the radio off for one minute and back on. Clears a lock-up."
	_cycle_camera.tooltip_text = "Switches the camera off for one minute and back on. Clears a freeze. To turn it off, move the slider to 0."
	for b in [_cycle_radio, _cycle_camera]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		health.add_child(b)
	_health_note = UiStyle.label("A restart button shows up here when the radio or the camera locks up.", 13, UiStyle.MUTED, true)
	health.add_child(_health_note)

	var outlook := _card(&"outlook", "Outlook", "star")
	body.add_child(_cards[&"outlook"][0])
	_forecast = UiStyle.label("", 14, UiStyle.MUTED, true)
	outlook.add_child(_forecast)

	body.add_child(UiStyle.label("Pause automatically when", 14, UiStyle.MUTED))
	var triggers := GridContainer.new()
	triggers.columns = 2
	for trigger in AutoPause.TRIGGERS:
		var cb := CheckBox.new()
		cb.text = Explain.PAUSE_NAMES[trigger]
		cb.add_theme_font_size_override("font_size", 13)
		cb.button_pressed = _mission.auto_pause.enabled[trigger]
		cb.toggled.connect(func(on: bool): _mission.auto_pause.enabled[trigger] = on)
		triggers.add_child(cb)
	body.add_child(triggers)

	_finish = Button.new()
	_finish.text = "Fly to the end without pauses"
	_finish.pressed.connect(_finish_now)
	_report = UiStyle.button("Read the report", func(): EventBus.screen_requested.emit(&"report"))
	_report.icon = UiStyle.icon("data")
	_report.disabled = true
	side.add_child(_finish)
	side.add_child(_report)
	var p := UiStyle.panel(side)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


## _card makes one sidebar group: a small panel with a title, a tag that names how
## it helps with the open pause and a box for the controls. _cards keeps
## [panel, tag] by id so _mark can light it up.
func _card(id: StringName, title: String, icon_name: String) -> VBoxContainer:
	var box := UiStyle.vbox(6)
	var head := UiStyle.hbox(8)
	head.add_child(UiStyle.section(title, icon_name, 16))
	var tag := UiStyle.label("", 13, UiStyle.ACCENT)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.visible = false
	head.add_child(tag)
	box.add_child(head)
	var p := UiStyle.panel(box)
	p.add_theme_stylebox_override("panel", _card_style)
	_cards[id] = [p, tag]
	return box


## _mark lights up the cards that can help with the open pause, each with its tag
## and returns the others to normal. An empty dictionary clears them all.
func _mark(tags: Dictionary) -> void:
	for id in _cards:
		var p: PanelContainer = _cards[id][0]
		var tag: Label = _cards[id][1]
		var on: bool = tags.has(id)
		p.add_theme_stylebox_override("panel", _card_marked if on else _card_style)
		tag.text = tags.get(id, "")
		tag.visible = on
	# the first marked card must be on screen
	for id in _cards:
		if tags.has(id):
			_side_scroll.ensure_control_visible.call_deferred(_cards[id][0])
			break


func _helpers(broke: Array, fired: Array[StringName]) -> Dictionary:
	var s := _mission.state
	var c := _mission.controls
	var out := {}
	var power := AutoPause.LOW_BATTERY in fired or AutoPause.SAFE_ENTER in fired \
			or &"battery_fade" in broke or &"solar_loss" in broke
	var memory := AutoPause.STORAGE_HIGH in fired
	if c.duty_cycle > 0.0 and (power or memory):
		out[&"camera"] = "Lower: less power and data" if power and memory else ("Lower: saves power" if power else "Lower: makes less data")
	# with the memory filling too, a silent radio would make that worse.
	# only the camera is marked, it helps with both
	if power and not memory and c.radio_enabled and not s.radio_hung:
		out[&"radio"] = "Off: saves power in passes"
	if (memory or AutoPause.CONTACT_BEGIN in fired) and not c.radio_enabled and not s.radio_hung:
		out[&"radio"] = "On: sends data home"
	if s.radio_hung or (s.instrument_hung and c.duty_cycle > 0.0):
		out[&"health"] = "Restart clears it"
	return out


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
		if _decision.visible:
			_fill_decision()


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
	var broke: Array = _mission.state.failures_started.duplicate() if AutoPause.FAILURE in fired else []
	var others := fired.filter(func(f): return f != AutoPause.FAILURE)
	var titles: Array = broke.map(func(k): return Explain.failure_name(k)) + others.map(func(f): return Explain.PAUSE_NAMES[f])
	_decision_title.text = " · ".join(titles)
	var color := UiStyle.BAD if not broke.is_empty() else (UiStyle.CYAN if others == [AutoPause.CONTACT_BEGIN] else UiStyle.WARN)
	_decision_title.add_theme_color_override("font_color", color)
	_decision_icon.modulate = color
	_decision_icon.texture = UiStyle.icon(_pause_icon(broke, others))
	_decision_time.text = "%s · clock paused" % Explain.mission_time(_mission.state.t_s)
	var happened: Array = broke.map(func(k): return Explain.failure_explain(k)) + [Explain.pause_reasons(others)]
	_banner.text = " ".join(happened).strip_edges()
	_fired = fired
	var tags := _helpers(broke, fired)
	var todo: Array = broke.map(func(k): return Explain.failure_fix(k))
	if not tags.is_empty():
		var names := {&"camera": "camera", &"radio": "radio", &"health": "spacecraft health"}
		var marked: Array = tags.keys().map(func(id): return "%s (%s)" % [names[id], tags[id].to_lower()])
		todo.append("Marked on the right: %s." % ", ".join(marked))
	_decision_todo.text = "What you can do: " + " ".join(todo) if not todo.is_empty() else ""
	_decision_todo.visible = not todo.is_empty()
	_mark(tags)
	_fill_decision()
	_show_decision(true)
	for f in fired:
		_log_line("%s: paused, %s." % [Explain.mission_time(_mission.state.t_s), Explain.PAUSE_NAMES[f].to_lower()], UiStyle.WARN)
	_update_forecast()


## _pause_icon picks the panel icon for what paused the clock: the part for a
## failure, else the resource that ran into trouble.
func _pause_icon(broke: Array, others: Array) -> String:
	if not broke.is_empty():
		return "chip"
	if AutoPause.LOW_BATTERY in others or AutoPause.SAFE_ENTER in others:
		return "battery"
	if AutoPause.STORAGE_HIGH in others:
		return "data"
	return "dish"


## _fill_decision writes the panel for the open auto-pause with the controls as
## they are now: the numbers behind the problem, where the mission ends up if
## nothing else breaks, the repairs and switches that apply, and Resume. It runs
## again whenever the player changes a control while paused, so trying a camera
## time shows its outcome before the clock runs.
func _fill_decision() -> void:
	var now := _outlook(_mission.controls)
	var facts := Explain.tradeoffs(_fired, now["forecast"], Warnings.camera_step(_mission.input, _mission.timeline))
	_decision_facts.text = " ".join(facts)
	_decision_facts.visible = not facts.is_empty()
	var lines := [Explain.goal_outlook(now["projected"], _goal_bits)] + Explain.forecast(now["forecast"], _mission.state, true)
	_decision_outlook.text = "If you resume as things are and nothing else breaks: " + ". ".join(lines) + "."
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for c in Warnings.choices(_fired, _mission.input, _mission.timeline, _mission.controls, _mission.state):
		var b := UiStyle.button("%s\n%s" % [Explain.choice(c), _choice_effect(c, now)], _choose.bind(c))
		if c["kind"] == &"restart":
			b.add_theme_stylebox_override("normal", _recommended)
		_options.add_child(b)
	_options.add_child(UiStyle.button("Resume as is\nchange nothing", _resume))


func _choice_effect(c: Dictionary, now: Dictionary) -> String:
	if c["kind"] == &"restart":
		return "off for a minute, then back on"
	return Explain.choice_effect(now, _outlook(_controls_with(Controls.RADIO_ENABLED, c["value"])), _goal_bits)


## _choose applies an auto-pause option and lets the clock run again.
func _choose(c: Dictionary) -> void:
	match c["kind"]:
		&"radio":
			_set_control(Controls.RADIO_ENABLED, c["value"])
		&"restart":
			_power_cycle(c["value"])
	_sync_controls()
	_resume()


func _resume() -> void:
	_set_speed(_last_speed)


## _show_decision opens or closes the auto-pause panel. While it is open the log
## hides and the charts may shrink, the clock is stopped and the panel is what the
## player reads; the charts still fill any room that is left.
func _show_decision(on: bool) -> void:
	_decision.visible = on
	if not on:
		_mark({})
	for part in _log_parts:
		part.visible = not on
	for c in _charts:
		c.custom_minimum_size.y = CHART_MIN_DECIDING if on else CHART_MIN


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
		var met := r.delivered_bits_total >= _goal_bits
		_goal.text = "Goal met" if met else "Goal %d %%" % floori(100.0 * r.delivered_bits_total / _goal_bits)
		_goal.add_theme_color_override("font_color", UiStyle.GOOD if met or _on_track else UiStyle.WARN)
		if met and not _goal_logged:
			_goal_logged = true
			_log_line("%s: goal met, %s home. The mission flies on to day %d, and data sent from now on still counts." % [Explain.mission_time(s.t_s), Explain.mb(_goal_bits), int(_mission.input.duration_s / 86400.0)], UiStyle.GOOD)
			_update_forecast()
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
		lines.append("Battery: holds %d %% of its design capacity, permanent" % roundi(s.battery_health * 100.0))
	if s.solar_health < 1.0:
		lines.append("Solar array: %d %% of its design output, permanent" % roundi(s.solar_health * 100.0))
	_faults.text = "All systems nominal" if lines.is_empty() else "\n".join(lines)
	_faults.add_theme_color_override("font_color", UiStyle.GOOD if lines.is_empty() else UiStyle.WARN)
	var radio_cycling := _mission.is_cycling(Controls.RADIO_ENABLED)
	var camera_cycling := _mission.is_cycling(Controls.DUTY_CYCLE)
	_cycle_radio.disabled = s.done or not s.radio_hung or radio_cycling
	_cycle_camera.disabled = s.done or not s.instrument_hung or camera_cycling or _mission.controls.duty_cycle <= 0.0
	_cycle_radio.visible = not s.done and (s.radio_hung or radio_cycling)
	_cycle_camera.visible = not s.done and (s.instrument_hung or camera_cycling)
	_cycle_radio.text = "Restarting radio, one minute" if radio_cycling else "Restart radio"
	if camera_cycling:
		_cycle_camera.text = "Restarting camera, one minute"
	elif _mission.controls.duty_cycle <= 0.0:
		_cycle_camera.text = "Camera at 0 %, it clears by itself"
	else:
		_cycle_camera.text = "Restart camera"
	for b in [_cycle_radio, _cycle_camera]:
		if b.disabled:
			b.remove_theme_stylebox_override("normal")
		else:
			b.add_theme_stylebox_override("normal", _recommended)
	_health_note.visible = not (_cycle_radio.visible or _cycle_camera.visible) and not s.done


func _update_forecast() -> void:
	var s := _mission.state
	_forecast_day = int(s.t_s / 86400.0)
	if s.done:
		_forecast.text = ""
		return
	var now := _outlook(_mission.controls)
	_on_track = float(now["projected"]) >= _goal_bits
	var lines := [Explain.goal_outlook(now["projected"], _goal_bits)] + Explain.forecast(now["forecast"], s)
	var head := "If the settings stay and nothing else breaks (averages over orbits and passes):"
	if _goal_bits > 0.0 and s.result.delivered_bits_total >= _goal_bits:
		head = "Goal met. The mission still runs to day %d.\n%s" % [int(_mission.input.duration_s / 86400.0), head]
	_forecast.text = head + "\n" + "\n".join(lines)
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
	_report.add_theme_stylebox_override("normal", _recommended)
	_report.grab_focus()
	_show_decision(false)
	_forecast.text = ""
	_cards[&"outlook"][0].visible = false
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
	# Three charts at the default 130 px leave no room for the pause panel at 720 px.
	# They still grow to fill a larger window.
	c.custom_minimum_size.y = CHART_MIN
	c.title = title
	c.color = color
	c.max_value = maxf(max_value, 1.0)
	c.format = format
	_charts.append(c)
	return c
