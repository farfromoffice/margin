extends Control
## Mission card: the story, the goal and the hard limits, before any design. A
## scenario with intro beats opens with them the first time this session.

var _go: Button
var _intro: MissionIntro


func _ready() -> void:
	var s := GameState.scenario()
	var page := UiStyle.page(self, 60)
	var col := UiStyle.vbox(18)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size.x = 760
	page.add_child(col)

	col.add_child(UiStyle.section("MISSION BRIEFING", "satellite", 14, UiStyle.CYAN))
	col.add_child(UiStyle.heading(s.title, 40))
	col.add_child(UiStyle.label(s.briefing, 20, UiStyle.TEXT, true))

	var facts := UiStyle.vbox(8)
	facts.add_child(_fact("star", "Mission length", "%d days" % s.duration_days))
	facts.add_child(_fact("coin", "Budget", Explain.kusd(s.budget_kusd) if s.budget_kusd > 0.0 else "no limit"))
	facts.add_child(_fact("weight", "Mass limit", Explain.kg(s.max_mass_kg) if s.max_mass_kg > 0.0 else "no limit"))
	var orbits := s.allowed_orbit_ids.map(func(id): return Catalog.get_entry("orbits", id).get("name", String(id)))
	facts.add_child(_fact("orbit", "Orbits", "any" if orbits.is_empty() else ", ".join(orbits)))
	col.add_child(UiStyle.panel(facts))

	if not s.objectives.is_empty():
		var goals := UiStyle.vbox(6)
		goals.add_child(UiStyle.section("Goal", "flag", 15, UiStyle.ACCENT))
		for id in s.objectives:
			goals.add_child(UiStyle.label(Explain.goal(id, s.objectives[id]), 19))
		col.add_child(UiStyle.panel(goals))

	var buttons := UiStyle.hbox(12)
	buttons.add_child(UiStyle.button("Back", func(): EventBus.screen_requested.emit(&"main_menu")))
	if not s.intro.is_empty():
		buttons.add_child(UiStyle.button("Replay intro", play_intro))
	_go = UiStyle.button("Design the spacecraft", func(): EventBus.screen_requested.emit(&"design"))
	_go.icon = UiStyle.icon("satellite")
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_go)
	col.add_child(buttons)

	if not s.intro.is_empty() and not GameState.intros_seen.has(s.id):
		play_intro()


## Escape skips the intro if it plays, else goes back to the menu like Back.
func on_escape() -> void:
	if _intro:
		_intro.skip()
	else:
		EventBus.screen_requested.emit(&"main_menu")


## play_intro covers the card with the mission intro and fades it out when it ends.
func play_intro() -> void:
	if _intro:
		return
	var s := GameState.scenario()
	GameState.intros_seen[s.id] = true
	_intro = MissionIntro.new()
	_intro.set_up(s)
	_intro.finished.connect(_end_intro)
	add_child(_intro)


func _end_intro() -> void:
	var gone := _intro
	_intro = null
	gone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := gone.create_tween()
	tw.tween_property(gone, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(gone.queue_free)
	_go.grab_focus()


func _fact(icon_name: String, what: String, value: String) -> HBoxContainer:
	var row := UiStyle.hbox()
	row.add_child(UiStyle.icon_rect(icon_name, 20, UiStyle.CYAN))
	var n := UiStyle.label(what, 17, UiStyle.MUTED)
	n.custom_minimum_size.x = 200
	row.add_child(n)
	row.add_child(UiStyle.label(value, 17))
	return row
