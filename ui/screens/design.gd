extends Control
## The design screen: one tab per mission segment on the left, the live margin
## panel on the right. Every pick writes into GameState.design and the panel
## redraws from EventBus.design_changed.

## tab -> categories shown on it, in order. adcs can be left out.
const TABS := {
	"Bus": ["structure", "solar", "battery", "obc", "adcs"],
	"Science": ["instrument"],
	"Launch": [],
	"Ground": ["comms"],
}
const OPTIONAL := ["adcs"]
const TAB_ICONS := {"Bus": "satellite", "Science": "camera", "Launch": "rocket", "Ground": "dish"}

var _design: MissionDesign
var _scenario: Scenario
var _mass: MarginMeter
var _cost: MarginMeter
var _power: Label
var _data: Label
var _checks: VBoxContainer
var _next: Button
var _duty_label: Label
## launcher id -> Button, station id -> CheckBox; their text depends on the orbit
var _launcher_buttons := {}
var _station_boxes := {}
var _preview: SpacecraftView
## side columns, hidden while the 3D view is maximized
var _side_panels: Array[Control] = []


func _ready() -> void:
	_design = GameState.design
	_scenario = GameState.scenario()
	var page := UiStyle.page(self, 20)
	var row := UiStyle.hbox(16)
	page.add_child(row)

	var left := UiStyle.vbox(10)
	left.custom_minimum_size.x = 360
	left.add_child(UiStyle.section("%s  ·  Design" % _scenario.title, "satellite", 22))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tabs)
	row.add_child(left)
	_side_panels.append(left)
	for tab in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = tab
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var body := UiStyle.vbox(14)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		tabs.add_child(scroll)
		tabs.set_tab_icon(tabs.get_tab_count() - 1, UiStyle.icon(TAB_ICONS[tab]))
		for cat in TABS[tab]:
			body.add_child(_category_picker(cat))
		match tab:
			"Science":
				body.add_child(_duty_slider())
			"Launch":
				body.add_child(_orbit_picker())
				body.add_child(_launcher_picker())
			"Ground":
				body.add_child(_station_picker())

	var middle := UiStyle.vbox(10)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(UiStyle.section("Your spacecraft", "satellite", 18, UiStyle.CYAN))
	_preview = SpacecraftView.new()
	_preview.expand_toggled.connect(func(on: bool):
		for p in _side_panels:
			p.visible = not on)
	var frame := UiStyle.panel(_preview)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _frame_box())
	middle.add_child(frame)
	row.add_child(middle)
	var margins := _margin_panel()
	row.add_child(margins)
	_side_panels.append(margins)
	EventBus.design_changed.connect(_refresh)
	_refresh()


func _category_picker(cat: String) -> Control:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section(Explain.category(cat).capitalize(), Explain.icon_for(cat)))
	var group := ButtonGroup.new()
	group.allow_unpress = cat in OPTIONAL
	var chosen := _chosen_in(cat)
	for c in Catalog.components_in(cat):
		var id := StringName(str(c["id"]))
		var b := _option_button("%s\n%s" % [c["name"], Explain.part_line(c)], group)
		b.button_pressed = id == chosen
		# hmm, switching inside a group also fires toggled(false) on the old one,
		# possibly after the new one, so only clear if it is still the chosen part
		b.toggled.connect(func(on: bool):
			if on:
				_pick(cat, id)
			elif _chosen_in(cat) == id:
				_pick(cat, &""))
		box.add_child(b)
	if cat in OPTIONAL:
		box.add_child(UiStyle.label("Optional, click again to remove.", 14, UiStyle.MUTED))
	return box


func _duty_slider() -> Control:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section("Camera on time", "camera"))
	_duty_label = UiStyle.label("", 16)
	box.add_child(_duty_label)
	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _design.instrument_duty_cycle
	slider.value_changed.connect(func(v: float):
		_design.instrument_duty_cycle = v
		GameState.touch_design())
	box.add_child(slider)
	box.add_child(UiStyle.label("Pictures only over land and fires save power and data.", 14, UiStyle.MUTED, true))
	return box


func _orbit_picker() -> Control:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section("Orbit", "orbit"))
	var group := ButtonGroup.new()
	for o in Catalog.all("orbits"):
		var id := StringName(str(o["id"]))
		if not _scenario.allowed_orbit_ids.is_empty() and not id in _scenario.allowed_orbit_ids:
			continue
		var b := _option_button("%s\n%s" % [o["name"], o.get("explain", "")], group)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.button_pressed = id == _design.orbit_id
		b.toggled.connect(func(on: bool):
			if on:
				_design.orbit_id = id
				GameState.touch_design())
		box.add_child(b)
	return box


func _launcher_picker() -> Control:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section("Launcher", "rocket"))
	var group := ButtonGroup.new()
	for l in Catalog.all("launchers"):
		var id := StringName(str(l["id"]))
		var b := _option_button("", group)
		b.button_pressed = id == _design.launcher_id
		b.toggled.connect(func(on: bool):
			if on:
				_design.launcher_id = id
				GameState.touch_design())
		_launcher_buttons[id] = b
		box.add_child(b)
	return box


func _station_picker() -> Control:
	var box := UiStyle.vbox(6)
	box.add_child(UiStyle.section("Ground stations", "dish"))
	box.add_child(UiStyle.label("More stations mean more time to send data home. Passes over two at once count once.", 14, UiStyle.MUTED, true))
	for g in Catalog.all("ground_stations"):
		var id := StringName(str(g["id"]))
		var cb := CheckBox.new()
		cb.button_pressed = id in _design.ground_station_ids
		cb.toggled.connect(func(on: bool):
			if on and not id in _design.ground_station_ids:
				_design.ground_station_ids.append(id)
			elif not on:
				_design.ground_station_ids.erase(id)
			GameState.touch_design())
		_station_boxes[id] = cb
		box.add_child(cb)
	return box


func _option_button(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _margin_panel() -> Control:
	var col := UiStyle.vbox(12)
	col.custom_minimum_size.x = 300
	col.add_child(UiStyle.section("Margins", "star", 22))
	_mass = MarginMeter.new("Mass", "weight")
	_cost = MarginMeter.new("Cost", "coin")
	col.add_child(_mass)
	col.add_child(_cost)
	_power = UiStyle.label("", 16, UiStyle.TEXT, true)
	_data = UiStyle.label("", 16, UiStyle.TEXT, true)
	col.add_child(_icon_row("bolt", _power))
	col.add_child(_icon_row("data", _data))
	col.add_child(HSeparator.new())
	col.add_child(UiStyle.section("Launch check", "flag"))
	_checks = UiStyle.vbox(6)
	_checks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_checks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_checks)
	col.add_child(scroll)
	var buttons := UiStyle.hbox(10)
	buttons.add_child(UiStyle.button("Briefing", func(): EventBus.screen_requested.emit(&"briefing")))
	_next = UiStyle.button("Predict and launch", func(): EventBus.screen_requested.emit(&"prediction"))
	_next.icon = UiStyle.icon("rocket")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_next)
	col.add_child(buttons)
	var p := UiStyle.panel(col)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


func _icon_row(icon_name: String, l: Label) -> HBoxContainer:
	var row := UiStyle.hbox(8)
	var r := UiStyle.icon_rect(icon_name, 18, UiStyle.MUTED)
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(r)
	row.add_child(l)
	return row


func _frame_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color.BLACK
	b.border_color = UiStyle.LINE
	b.set_border_width_all(1)
	b.set_corner_radius_all(10)
	b.set_content_margin_all(2)
	return b


func _refresh() -> void:
	var parts: Array = []
	for id in _design.component_ids:
		var c := Catalog.get_entry("components", id)
		if not c.is_empty():
			parts.append(c)
	_preview.show_parts(parts)
	var totals := LaunchCheck.totals(_design, Catalog)
	var orbit := Catalog.get_entry("orbits", _design.orbit_id)
	var launcher := Catalog.get_entry("launchers", _design.launcher_id)
	var mass_limit := _mass_limit(launcher)
	_mass.set_values(Explain.kg(totals["mass_kg"]), Explain.kg(mass_limit), totals["mass_kg"], mass_limit)
	_cost.set_values(Explain.kusd(totals["cost_kusd"]), Explain.kusd(_scenario.budget_kusd), totals["cost_kusd"], _scenario.budget_kusd)
	_duty_label.text = Explain.duty(_design.instrument_duty_cycle)

	var input := SimInput.from_design(_design, _scenario, Catalog)
	var timeline := OrbitTimeline.build(orbit, _design.ground_station_ids, input.duration_s)
	if orbit.is_empty():
		_power.text = "Power: pick an orbit to see the balance."
		_data.text = "Data: pick an orbit to see contact time."
		_power.add_theme_color_override("font_color", UiStyle.MUTED)
		_data.add_theme_color_override("font_color", UiStyle.MUTED)
	else:
		var net := Warnings.orbit_energy_j(input, timeline)
		_power.text = "Power per orbit: %s%s" % ["+" if net >= 0.0 else "", Explain.wh(net)]
		_power.add_theme_color_override("font_color", UiStyle.GOOD if net >= 0.0 else UiStyle.BAD)
		var made := Warnings.generated_bits_per_day(input)
		var sendable := Warnings.deliverable_bits_per_day(input, timeline)
		_data.text = "Data per day: %s made, %s can be sent" % [Explain.mb(made), Explain.mb(sendable)]
		_data.add_theme_color_override("font_color", UiStyle.GOOD if made <= sendable else UiStyle.WARN)

	for child in _checks.get_children():
		child.queue_free()
	var violations := LaunchCheck.check(_design, _scenario, Catalog)
	for v in violations:
		_checks.add_child(UiStyle.label("• " + Explain.violation(v), 15, UiStyle.BAD, true))
	if violations.is_empty():
		_checks.add_child(UiStyle.label("Ready for launch", 16, UiStyle.GOOD, true))
		for w in Warnings.compute(input, OrbitTimeline.build(orbit, _design.ground_station_ids, input.duration_s)):
			_checks.add_child(UiStyle.label("• " + Explain.warning(w), 15, UiStyle.WARN, true))
	_next.disabled = not violations.is_empty()
	_refresh_orbit_dependent()


## Launcher capacity and station contact time both change with the orbit.
func _refresh_orbit_dependent() -> void:
	var orbit := Catalog.get_entry("orbits", _design.orbit_id)
	for id in _launcher_buttons:
		var l := Catalog.get_entry("launchers", id)
		var cap: Variant = l.get("capacity_kg", {}).get(String(_design.orbit_id))
		var reach := "pick an orbit" if orbit.is_empty() else ("can't reach this orbit" if cap == null else "carries up to %s here" % Explain.kg(cap))
		_launcher_buttons[id].text = "%s\n%s · %s" % [l["name"], Explain.kusd(l.get("cost_kusd", 0.0)), reach]
	var contacts: Variant = orbit.get("contacts_s", {})
	var reference := float(orbit.get("reference_duration_s", 0.0))
	for id in _station_boxes:
		var g := Catalog.get_entry("ground_stations", id)
		var text: String = g["name"]
		if reference > 0.0 and contacts is Dictionary:
			var seconds := 0.0
			for w in contacts.get(String(id), []):
				seconds += float(w[1]) - float(w[0])
			text += "  ·  %d min a day in view" % roundi(seconds / reference * 86400.0 / 60.0)
		_station_boxes[id].text = text


func _mass_limit(launcher: Dictionary) -> float:
	var limits: Array[float] = []
	if _scenario.max_mass_kg > 0.0:
		limits.append(_scenario.max_mass_kg)
	var cap: Variant = launcher.get("capacity_kg", {}).get(String(_design.orbit_id))
	if cap is int or cap is float:
		limits.append(float(cap))
	return limits.min() if not limits.is_empty() else 0.0


func _chosen_in(cat: String) -> StringName:
	for id in _design.component_ids:
		if Catalog.get_entry("components", id).get("category") == cat:
			return id
	return &""


## One part per category; empty id clears the category.
func _pick(cat: String, id: StringName) -> void:
	var kept: Array[StringName] = []
	for other in _design.component_ids:
		if Catalog.get_entry("components", other).get("category") != cat:
			kept.append(other)
	if id != &"":
		kept.append(id)
	_design.component_ids = kept
	GameState.touch_design()
