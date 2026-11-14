extends Control
## Root of the game. Owns the theme and swaps one screen at a time whenever
## someone emits EventBus.screen_requested.

const SCREENS := {
	&"main_menu": "res://scenes/main_menu.tscn",
	&"briefing": "res://ui/screens/briefing.gd",
	&"design": "res://ui/screens/design.gd",
	&"prediction": "res://ui/screens/prediction.gd",
	&"run": "res://ui/screens/run_view.gd",
	&"report": "res://ui/screens/report.gd",
}

var current: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.build_theme()
	add_child(Starfield.new())
	EventBus.screen_requested.connect(show_screen)
	show_screen(&"main_menu")


func show_screen(screen: StringName) -> void:
	if not SCREENS.has(screen):
		push_error("App: unknown screen %s" % screen)
		return
	if current:
		current.queue_free()
	var path: String = SCREENS[screen]
	var res: Resource = load(path)
	# scenes and plain screen scripts both work, the menu is a scene
	current = res.instantiate() if res is PackedScene else res.new()
	current.name = String(screen)
	add_child(current)
