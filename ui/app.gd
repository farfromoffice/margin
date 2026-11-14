extends Control
## Root of the game. Owns the theme and swaps one screen at a time whenever
## someone emits EventBus.screen_requested.

const SCREENS := {
	&"main_menu": "res://scenes/main_menu.tscn",
	&"how_to_play": "res://ui/screens/how_to_play.gd",
	&"briefing": "res://ui/screens/briefing.gd",
	&"design": "res://ui/screens/design.gd",
	&"prediction": "res://ui/screens/prediction.gd",
	&"launch": "res://ui/screens/launch.gd",
	&"run": "res://ui/screens/run_view.gd",
	&"report": "res://ui/screens/report.gd",
}

var current: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.build_theme()
	_share_cursor()
	add_child(Starfield.new())
	EventBus.screen_requested.connect(show_screen)
	show_screen(&"main_menu")


## The project setting only swaps the plain arrow. Dragging the Earth asks for
## the drag shape, so point that at the same image or the system hand pops up.
func _share_cursor() -> void:
	var path: String = ProjectSettings.get_setting("display/mouse_cursor/custom_image", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var hotspot: Vector2 = ProjectSettings.get_setting("display/mouse_cursor/custom_image_hotspot", Vector2.ZERO)
	Input.set_custom_mouse_cursor(load(path), Input.CURSOR_DRAG, hotspot)


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
