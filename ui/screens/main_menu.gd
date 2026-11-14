extends Control
## Title screen: name and buttons on the left, Earth with a circling spacecraft
## on the right. Play starts Wildfire Watch, Sandbox has no limits or goals,
## How to play explains the loop.

const FIRST_SCENARIO := &"wildfire_watch"


func _ready() -> void:
	var orbit := OrbitView.new()
	orbit.planet_scale = 1.4
	orbit.interactive = true
	orbit.anchor_left = 0.42
	orbit.anchor_right = 1.0
	orbit.anchor_bottom = 1.0
	add_child(orbit)
	move_child(orbit, 0)

	var menu: VBoxContainer = $Center/Menu
	menu.add_theme_constant_override("separation", 14)
	menu.custom_minimum_size.x = 380
	var kicker := UiStyle.section("NASA SPACE APPS CHALLENGE 2026", "star", 13, UiStyle.CYAN)
	menu.add_child(kicker)
	menu.move_child(kicker, 0)

	var title: Label = $Center/Menu/Title
	title.theme_type_variation = &"DisplayLabel"
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", UiStyle.ACCENT)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(UiStyle.ACCENT, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tagline: Label = $Center/Menu/Tagline
	tagline.text = "Every gram counts."
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", UiStyle.TEXT)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var pitch := UiStyle.label("Design a small satellite, guess what will hold it back, fly it for a month and find out why.", 16, UiStyle.MUTED, true)
	menu.add_child(pitch)
	menu.move_child(pitch, tagline.get_index() + 1)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	menu.add_child(gap)
	menu.move_child(gap, pitch.get_index() + 1)

	var play: Button = $Center/Menu/PlayButton
	_style_button(play, "Start mission: Wildfire Watch", "rocket", 18)
	play.pressed.connect(_start.bind(FIRST_SCENARIO))
	var sandbox: Button = $Center/Menu/SandboxButton
	_style_button(sandbox, "Sandbox: no limits, no goals", "planet", 15)
	sandbox.pressed.connect(_start.bind(&"sandbox"))
	var how := Button.new()
	how.name = "HowToPlayButton"
	menu.add_child(how)
	menu.move_child(how, sandbox.get_index() + 1)
	_style_button(how, "How to play", "flag", 15)
	how.pressed.connect(func(): EventBus.screen_requested.emit(&"how_to_play"))

	var hint := UiStyle.label("Drag the Earth to spin it", 13, UiStyle.MUTED)
	hint.anchor_left = 0.42
	hint.anchor_right = 1.0
	hint.anchor_top = 0.86
	hint.anchor_bottom = 0.86
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	var footer := UiStyle.label("An independent project by farfromoffice Studios. Not affiliated with NASA.",
    13,
    UiStyle.MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position += Vector2(28, -36)
	add_child(footer)


func _style_button(b: Button, text: String, icon_name: String, font_size: int) -> void:
	b.text = text
	b.theme_type_variation = &"DisplayButton"
	b.icon = UiStyle.icon(icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 58 if font_size > 16 else 48
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("icon_normal_color", UiStyle.CYAN)
	b.add_theme_color_override("icon_hover_color", UiStyle.ACCENT)


func _start(scenario_id: StringName) -> void:
	GameState.new_mission(scenario_id, 1)
	EventBus.screen_requested.emit(&"briefing")
