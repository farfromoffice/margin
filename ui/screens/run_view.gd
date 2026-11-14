extends Control
## Plays the finished run back over a few seconds: battery, storage and data
## sent home, with Safe mode tinted and events listed as the playhead passes.
## The sim already ran in GameState.run_mission(), this only animates it.

const PLAYBACK_S := 14.0

var _result: RunResult
var _input: SimInput
var _charts: Array[LineChart] = []
var _day: Label
var _mode: Label
var _log: VBoxContainer
var _report: Button
var _skip: Button
var _progress := 0.0
var _next_event := 0
var _last_day := -1
var _orbit: OrbitView
## event kind -> how often it fired on the day being logged. A weak design can
## flip in and out of Safe mode every orbit, one line each would bury the log.
var _day_counts := {}
var _log_day := -1


func _ready() -> void:
	_result = GameState.last_result
	_input = GameState.last_input
	var page := UiStyle.page(self, 20)
	var row := UiStyle.hbox(16)
	page.add_child(row)

	var left := UiStyle.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UiStyle.hbox(20)
	head.add_child(UiStyle.section("%s  ·  Mission" % GameState.scenario().title, "satellite", 26))
	_day = UiStyle.label("", 20)
	_mode = UiStyle.label("", 20)
	_day.theme_type_variation = &"DisplayLabel"
	_mode.theme_type_variation = &"DisplayLabel"
	head.add_child(_day)
	head.add_child(_mode)
	left.add_child(head)
	row.add_child(left)

	var total := int(ceil(_input.duration_s / _input.dt_s))
	var battery := _chart("Battery", UiStyle.GOOD, _result.energy_j, _input.battery_capacity_j, total,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(_input.battery_capacity_j, 1.0)))
	battery.modes = _result.mode
	_chart("Memory used", UiStyle.WARN, _result.stored_bits, _input.storage_capacity_bits, total,
			func(v: float) -> String: return "%d %%" % roundi(100.0 * v / maxf(_input.storage_capacity_bits, 1.0)))
	var sent_max := maxf(_result.delivered_bits_total, 1.0)
	_chart("Data sent home", UiStyle.DATA, _result.delivered_bits, sent_max, total, func(v: float) -> String: return Explain.mb(v))
	for c in _charts:
		left.add_child(c)
	left.add_child(UiStyle.label("Red bands: Safe mode, the camera and radio were off to save the battery.", 14, UiStyle.MUTED))

	var side := UiStyle.vbox(10)
	side.custom_minimum_size.x = 320
	_orbit = OrbitView.new()
	_orbit.auto_spin = false
	_orbit.custom_minimum_size = Vector2(300, 170)
	side.add_child(_orbit)
	_orbit.eclipse_fraction = float(Catalog.get_entry("orbits", GameState.design.orbit_id).get("eclipse_fraction", 0.0))
	side.add_child(UiStyle.section("Mission log", "flag", 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log = UiStyle.vbox(6)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log)
	side.add_child(scroll)
	_skip = UiStyle.button("Skip to the end", func(): _set_progress(1.0))
	_report = UiStyle.button("Read the report", func(): EventBus.screen_requested.emit(&"report"))
	_report.icon = UiStyle.icon("data")
	_report.disabled = true
	side.add_child(_skip)
	side.add_child(_report)
	var p := UiStyle.panel(side)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	_log_line("Day 1: launch. Battery full, memory empty.", UiStyle.TEXT)
	_set_progress(0.0)


func _process(delta: float) -> void:
	if _progress < _end_fraction():
		_set_progress(_progress + delta / PLAYBACK_S)


## A lost mission stops early, so playback stops where the series ends.
func _end_fraction() -> float:
	return _result.end_t_s / _input.duration_s if _input.duration_s > 0.0 else 1.0


func _set_progress(p: float) -> void:
	_progress = minf(p, _end_fraction())
	for c in _charts:
		c.progress = _progress
	var t := _progress * _input.duration_s
	var day := int(t / 86400.0)
	if day != _last_day:
		_last_day = day
		_day.text = "Day %d of %d" % [mini(day + 1, int(_input.duration_s / 86400.0)), int(_input.duration_s / 86400.0)]
		EventBus.sim_tick.emit(day)
	_update_orbit()
	var i := clampi(int(t / _input.dt_s) - 1, 0, _result.step_count() - 1)
	var safe := _result.step_count() > 0 and _result.mode[i] == RunResult.Mode.SAFE
	_mode.text = "SAFE MODE" if safe else "Normal"
	_mode.add_theme_color_override("font_color", UiStyle.BAD if safe else UiStyle.GOOD)
	while _next_event < _result.events.size() and float(_result.events[_next_event]["t_s"]) <= t + 0.001:
		_log_event(_result.events[_next_event])
		_next_event += 1
	if _progress >= _end_fraction() and _report.disabled:
		_flush_day()
		_report.disabled = false
		_skip.disabled = true
		if _result.end_reason == RunResult.EndReason.COMPLETED:
			_log_line("Mission complete. %s sent home." % Explain.mb(_result.delivered_bits_total), UiStyle.GOOD)


## The playback squeezes hundreds of orbits into seconds, so the craft would
## blur round the ring. It spins at a readable pace instead, the shadow arc
## still has the real eclipse share of this orbit.
func _update_orbit() -> void:
	_orbit.angle = fmod(_progress * PLAYBACK_S * 0.9, TAU)


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


func _chart(title: String, color: Color, values: PackedFloat64Array, max_value: float, total: int, format: Callable) -> LineChart:
	var c := LineChart.new()
	c.title = title
	c.color = color
	c.values = values
	c.max_value = maxf(max_value, 1.0)
	c.total_steps = total
	c.format = format
	_charts.append(c)
	return c
