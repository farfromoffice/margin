extends Control
## Launch pad between the prediction and the run. Shows the preflight numbers
## the design will fly with, then plays the launch in 3D and logs each
## milestone as the scene reaches it. Nothing here is flown or steered: the
## launcher reaches the orbit if the launch check passed, so the sequence is a
## story, not a simulation.

var _go: Button
var _ops: Button
var _skip: Button
var _seq: VBoxContainer
var _scene: LaunchScene
## milestone id -> line for the sequence log
var _steps := {}


func _ready() -> void:
	var design := GameState.design
	var scenario := GameState.scenario()
	var orbit := Catalog.get_entry("orbits", design.orbit_id)
	var launcher := Catalog.get_entry("launchers", design.launcher_id)
	var violations := LaunchCheck.check(design, scenario, Catalog)

	var page := UiStyle.page(self, 20)
	var row := UiStyle.hbox(16)
	page.add_child(row)

	var left := UiStyle.vbox(10)
	left.custom_minimum_size.x = 360
	left.add_child(UiStyle.section("LAUNCH PAD", "rocket", 14, UiStyle.CYAN))
	left.add_child(UiStyle.heading(scenario.title, 28))
	left.add_child(_preflight(design, orbit, launcher, violations))
	var lp := UiStyle.panel(left)
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(lp)

	var middle := UiStyle.vbox(10)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(UiStyle.section("Launch site", "rocket", 18, UiStyle.CYAN))
	_scene = LaunchScene.new()
	var frame := UiStyle.panel(_scene)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(frame)
	row.add_child(middle)
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

	var right := UiStyle.vbox(10)
	right.custom_minimum_size.x = 340
	right.add_child(UiStyle.section("Launch sequence", "flag", 20))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_seq = UiStyle.vbox(8)
	_seq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_seq)
	right.add_child(scroll)
	right.add_child(UiStyle.label("The ascent is shown, not simulated. The launcher's own guidance flies it; your part was picking a launcher that can lift this mass to this orbit.", 13, UiStyle.MUTED, true))
	_go = UiStyle.button("Begin countdown", _begin)
	_go.icon = UiStyle.icon("rocket")
	_go.disabled = not violations.is_empty()
	_ops = UiStyle.button("Start mission operations", _start_ops)
	_ops.icon = UiStyle.icon("satellite")
	_ops.disabled = true
	_skip = UiStyle.button("Skip to orbit", skip_sequence)
	_skip.disabled = true
	right.add_child(_go)
	right.add_child(_skip)
	right.add_child(_ops)
	right.add_child(UiStyle.button("Back to prediction", func(): EventBus.screen_requested.emit(&"prediction")))
	var rp := UiStyle.panel(right)
	rp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(rp)

	_steps = _sequence(launcher, orbit)


func _begin() -> void:
	_go.disabled = true
	_skip.disabled = false
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
			# warnings never block, the players already saw them on the design screen
			box.add_child(_item("Design warnings", "%d, launching anyway" % warnings.size(), true, UiStyle.WARN))
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
