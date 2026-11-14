extends Control
## Launch pad between the prediction and the run. The 3D scene fills the
## screen; the preflight numbers and the milestone log sit in panels opened from
## the round buttons in the bottom right corner. Nothing here is flown or steered: the
## launcher reaches the orbit if the launch check passed, so the sequence is a
## story, not a simulation.

var _go: Button
## Ticked to launch a design with warnings. Null when there are none.
var _accept: CheckBox
var _blocked := false
var _ops: Button
var _skip: Button
var _seq: VBoxContainer
var _scene: LaunchScene
## milestone id -> line for the sequence log
var _steps := {}
## overlay panel name -> [round button, panel]
var _overlays := {}


func _ready() -> void:
	var design := GameState.design
	var scenario := GameState.scenario()
	var orbit := Catalog.get_entry("orbits", design.orbit_id)
	var launcher := Catalog.get_entry("launchers", design.launcher_id)
	var violations := LaunchCheck.check(design, scenario, Catalog)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scene = LaunchScene.new()
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scene)
	var parts: Array = []
	for id in design.component_ids:
		var c := Catalog.get_entry("components", id)
		if not c.is_empty():
			parts.append(c)
	_scene.set_up(launcher, parts)
	_scene.milestone.connect(_on_milestone)
	_scene.finished.connect(func():
		_skip.disabled = true
		_ops.disabled = false)

	# hmm, no full rect containers on top of the scene: they would eat the
	# drag and wheel the camera needs, so every overlay is anchored on its own
	var top := UiStyle.vbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(20, 20)
	top.add_child(UiStyle.section("LAUNCH PAD", "rocket", 14, UiStyle.CYAN))
	top.add_child(UiStyle.heading(scenario.title, 28))
	var actions := UiStyle.hbox(10)
	actions.add_child(UiStyle.button("Back to prediction", func(): EventBus.screen_requested.emit(&"prediction")))
	_go = UiStyle.button("Begin countdown", _begin)
	_go.icon = UiStyle.icon("rocket")
	_blocked = not violations.is_empty()
	_go.disabled = _blocked
	_skip = UiStyle.button("Skip to orbit", skip_sequence)
	_skip.disabled = true
	_ops = UiStyle.button("Start mission operations", _start_ops)
	_ops.icon = UiStyle.icon("satellite")
	_ops.disabled = true
	actions.add_child(_go)
	actions.add_child(_skip)
	actions.add_child(_ops)
	top.add_child(actions)
	add_child(top)

	var pad := UiStyle.vbox(10)
	pad.add_child(UiStyle.section("Preflight", "rocket", 18, UiStyle.CYAN))
	pad.add_child(_preflight(design, orbit, launcher, violations))
	_update_go()

	var seq_box := UiStyle.vbox(10)
	seq_box.add_child(UiStyle.section("Launch sequence", "flag", 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_seq = UiStyle.vbox(8)
	_seq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_seq)
	seq_box.add_child(scroll)
	seq_box.add_child(UiStyle.label("The ascent is shown, not simulated. The launcher's own guidance flies it; your part was picking a launcher that can lift this mass to this orbit.", 13, UiStyle.MUTED, true))

	add_child(_overlay_dock([
		[&"pad", "rocket", "Launch pad", pad],
		[&"sequence", "flag", "Sequence", seq_box],
	]))
	# the GO or NO GO is the first thing to read, so the pad starts open
	_show_overlay(&"pad")

	_steps = _sequence(launcher, orbit)


## Bottom right corner: one panel slot above a row of round buttons. Each
## entry is [name, icon, tooltip, content]; only one panel shows at a time.
func _overlay_dock(entries: Array) -> Control:
	var dock := UiStyle.vbox(12)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.anchor_left = 1.0
	dock.anchor_top = 1.0
	dock.anchor_right = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = -20.0
	dock.offset_top = -20.0
	dock.offset_right = -20.0
	dock.offset_bottom = -20.0
	# grows up and left from the corner, whatever panel is open
	dock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := UiStyle.hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	for e in entries:
		var p := UiStyle.panel(e[3])
		p.custom_minimum_size.x = 380
		p.size_flags_horizontal = Control.SIZE_SHRINK_END
		p.visible = false
		dock.add_child(p)
		var b := UiStyle.round_button(e[1], e[2])
		var id: StringName = e[0]
		b.toggled.connect(func(on: bool): _show_overlay(id if on else &""))
		row.add_child(b)
		_overlays[id] = [b, p]
	dock.add_child(row)
	return dock


## Opens one overlay panel and closes the rest, &"" closes them all.
func _show_overlay(id: StringName) -> void:
	for key in _overlays:
		var b: Button = _overlays[key][0]
		var p: Control = _overlays[key][1]
		var on: bool = key == id
		b.set_pressed_no_signal(on)
		p.visible = on


## _update_go enables the countdown when nothing blocks the launch and any
## warnings are accepted.
func _update_go() -> void:
	_go.disabled = _blocked or (_accept != null and not _accept.button_pressed)


func _begin() -> void:
	if _accept:
		_accept.disabled = true
	_go.disabled = true
	_skip.disabled = false
	_show_overlay(&"sequence")
	Sfx.play(&"liftoff")
	_scene.launch()


## Jumps the scene to orbit; it logs every milestone left on the way.
func skip_sequence() -> void:
	_go.disabled = true
	_scene.skip()


func _on_milestone(id: StringName) -> void:
	if _steps.has(id):
		_seq.add_child(UiStyle.label(_steps[id], 15, UiStyle.TEXT, true))


func _start_ops() -> void:
	GameState.start_mission()
	EventBus.screen_requested.emit(&"run")


func _preflight(design: MissionDesign, orbit: Dictionary, launcher: Dictionary, violations: Array[Dictionary]) -> Control:
	var box := UiStyle.vbox(8)
	var totals := LaunchCheck.totals(design, Catalog)
	var capacity: Variant = launcher.get("capacity_kg", {}).get(String(design.orbit_id))
	box.add_child(_item("Launcher", str(launcher.get("name", "none")), not launcher.is_empty()))
	if capacity is int or capacity is float:
		box.add_child(_item("Mass", "%s of %s it can lift" % [Explain.kg(totals["mass_kg"]), Explain.kg(capacity)], totals["mass_kg"] <= float(capacity)))
	var budget := GameState.scenario().budget_kusd
	if budget > 0.0:
		box.add_child(_item("Cost", "%s of %s" % [Explain.kusd(totals["cost_kusd"]), Explain.kusd(budget)], totals["cost_kusd"] <= budget))
	if not orbit.is_empty():
		var a := OrbitTimeline.R_EARTH_M + float(orbit.get("altitude_m", 0.0))
		var period := OrbitTimeline.period_for_altitude_s(float(orbit.get("altitude_m", 0.0)))
		box.add_child(_item("Orbit", str(orbit.get("name", "")), true))
		box.add_child(UiStyle.label("One lap every %.1f min at %.2f km/s (calculated from the altitude, circular orbit)." % [period / 60.0, sqrt(OrbitTimeline.MU_M3_S2 / a) / 1000.0], 14, UiStyle.MUTED, true))
		var input := SimInput.from_design(design, GameState.scenario(), Catalog)
		var warnings := Warnings.compute(input, OrbitTimeline.build(orbit, design.ground_station_ids, input.duration_s))
		if warnings.is_empty():
			box.add_child(_item("Design warnings", "none", true))
		else:
			# Warnings never block but launching with them is a decision: each one is
			# listed again and the countdown waits for the player to accept them.
			box.add_child(_item("Design warnings", "%d" % warnings.size(), true, UiStyle.WARN))
			for w in warnings:
				box.add_child(UiStyle.label("• " + Explain.warning(w), 14, UiStyle.WARN, true))
			_accept = CheckBox.new()
			_accept.text = "I accept these risks"
			_accept.toggled.connect(func(_on: bool): _update_go())
			box.add_child(_accept)
	for v in violations:
		box.add_child(UiStyle.label("NO GO: %s" % Explain.violation(v), 15, UiStyle.BAD, true))
	var go := violations.is_empty()
	var verdict := UiStyle.heading("GO for launch" if go else "NO GO", 24)
	verdict.add_theme_color_override("font_color", UiStyle.GOOD if go else UiStyle.BAD)
	box.add_child(verdict)
	return box


func _item(what: String, value: String, ok: bool, color := Color.TRANSPARENT) -> Control:
	var tint := color if color.a > 0.0 else (UiStyle.GOOD if ok else UiStyle.BAD)
	var line := UiStyle.hbox(8)
	line.add_child(UiStyle.label("GO" if ok else "NO", 15, tint))
	var text := UiStyle.label("%s: %s" % [what, value], 15, UiStyle.TEXT, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return line


## hmm, no timestamps on purpose: the sim starts in orbit and has no ascent
## model, so any T+ seconds here would be made up.
func _sequence(launcher: Dictionary, orbit: Dictionary) -> Dictionary:
	var km := float(orbit.get("altitude_km", 0.0))
	return {
		&"countdown": "Final checks complete. All stations GO. Ignition.",
		&"liftoff": "Liftoff: %s." % launcher.get("name", "launcher"),
		&"ascent": "Ascent. The air thins steadily with height, there is no line where it stops.",
		&"pitch": "The rocket tips over and builds sideways speed. Going straight up never makes an orbit.",
		&"fairing": "Fairing open. Above most of the air, the nose cone is dead weight now.",
		&"separation": "Spacecraft separated at %d km." % roundi(km),
		&"deploy": "Solar panels out. In orbit, gravity is still about %d %% of the surface value; you float because you keep falling around Earth." % roundi(100.0 * pow(OrbitTimeline.R_EARTH_M / (OrbitTimeline.R_EARTH_M + km * 1000.0), 2.0)),
		&"handover": "Battery full, memory empty. Handing over to mission operations.",
	}
