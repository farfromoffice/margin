extends Control
## Title screen laid out like a sports game hub: wordmark and tabs across the
## top, a grid of big tiles at the bottom left, Earth with its spacecraft on the
## right. Q and E (or the shoulder buttons) flip tabs, the tiles take focus so
## arrows and Enter work too. Tabs slide in, tiles lift on hover and press in
## before the menu fades out to the next screen.

const FIRST_SCENARIO := &"wildfire_watch"
const TABS := ["HOME", "PLAY", "LEARN"]
const TILE_GAP := 14
const DAY_MAP := preload("res://ui/earth/blue_marble.jpg")
const NIGHT_MAP := preload("res://ui/earth/black_marble.jpg")
## Wildfire Watch's tile, a real fire seen from orbit
const WILDFIRE_ART := preload("res://ui/earth/wildfire.jpg")
## crops of the 2048x1024 Earth maps used as tile art, x is longitude, y latitude
const ART_EUROPE_DAY := Rect2(900, 110, 420, 230)
const ART_ASIA_NIGHT := Rect2(1450, 170, 460, 240)
const SLIDE_PX := 60.0
const HOVER_SCALE := 1.025

var _tab := 0
var _tab_buttons: Array[Button] = []
var _tiles: Control
## set once a tile is pressed, so a double click can't start two missions
var _leaving := false


func _ready() -> void:
	var orbit := OrbitView.new()
	orbit.planet_scale = 1.4
	orbit.interactive = true
	orbit.anchor_left = 0.58
	orbit.anchor_right = 1.0
	orbit.anchor_top = 0.08
	orbit.anchor_bottom = 1.0
	add_child(orbit)

	_build_top_bar()

	_tiles = Control.new()
	_tiles.name = "Tiles"
	_tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles.anchor_left = 0.0
	_tiles.anchor_right = 0.6
	_tiles.anchor_top = 0.22
	_tiles.anchor_bottom = 1.0
	_tiles.offset_left = 40
	_tiles.offset_bottom = -84
	add_child(_tiles)

	_build_studio_logo()
	_build_footer()
	_show_tab(0)


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_page_down") or _key(event, KEY_E) or _pad(event, JOY_BUTTON_RIGHT_SHOULDER):
		step = 1
	elif event.is_action_pressed(&"ui_page_up") or _key(event, KEY_Q) or _pad(event, JOY_BUTTON_LEFT_SHOULDER):
		step = -1
	if step != 0:
		_show_tab(wrapi(_tab + step, 0, TABS.size()))
		get_viewport().set_input_as_handled()


func _key(event: InputEvent, code: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == code


func _pad(event: InputEvent, b: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == b


func _build_top_bar() -> void:
	var bar := UiStyle.hbox(0)
	bar.name = "TopBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = 26
	bar.custom_minimum_size.y = 52
	add_child(bar)

	var mark := UiStyle.label("MARGIN", 30, UiStyle.ACCENT)
	mark.name = "Title"
	mark.theme_type_variation = &"DisplayLabel"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(mark)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 48
	bar.add_child(spacer)

	bar.add_child(_shoulder_hint("Q"))
	var tabs := UiStyle.hbox(4)
	tabs.name = "Tabs"
	for i in TABS.size():
		var t := Button.new()
		t.name = TABS[i].capitalize() + "Tab"
		t.text = TABS[i]
		t.theme_type_variation = &"DisplayButton"
		t.focus_mode = Control.FOCUS_NONE
		t.add_theme_font_size_override("font_size", 16)
		t.pressed.connect(_show_tab.bind(i))
		tabs.add_child(t)
		_tab_buttons.append(t)
	bar.add_child(tabs)
	bar.add_child(_shoulder_hint("E"))

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)

	var kicker := UiStyle.section("NASA SPACE APPS CHALLENGE 2026", "star", 12, UiStyle.CYAN)
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(kicker)

	# thin rule under the bar, the tabs sit on it
	var rule := ColorRect.new()
	rule.color = UiStyle.LINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = 40
	rule.offset_right = -40
	rule.offset_top = 26 + 56
	rule.offset_bottom = 26 + 57
	add_child(rule)


func _shoulder_hint(key: String) -> Control:
	var l := UiStyle.label(key, 13, UiStyle.MUTED)
	l.theme_type_variation = &"DisplayLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(30, 24)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := _flat(Color(UiStyle.PANEL_LIGHT, 0.6), 4, 0, UiStyle.LINE, 1)
	l.add_theme_stylebox_override("normal", box)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_child(l)
	return m


func _build_studio_logo() -> void:
	var studio := TextureRect.new()
	studio.name = "StudioLogo"
	studio.texture = preload("res://ui/brand/logo_small.png")
	studio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	studio.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	studio.modulate.a = 0.8
	studio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	studio.size = Vector2(130, 25)
	studio.position += Vector2(-130 - 24, -25 - 30)


func _build_footer() -> void:
	var footer := UiStyle.label("Not affiliated with NASA.", 13, UiStyle.MUTED)
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position += Vector2(40, -34)


func _show_tab(i: int) -> void:
	if _leaving:
		return
	var dir := signf(i - _tab) if i != _tab else 1.0
	_tab = i
	for j in _tab_buttons.size():
		_style_tab(_tab_buttons[j], j == i)
	for old in _tiles.get_children():
		_slide_out(old, dir)
	var grid: Control
	match TABS[i]:
		"HOME":
			grid = _home_grid()
		"PLAY":
			grid = _play_grid()
		_:
			grid = _learn_grid()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tiles.add_child(grid)
	_slide_in(grid, dir)
	# first tile grabs focus so a pad or the keyboard can drive the menu at once
	var first := grid.find_children("*", "Button", true, false)
	if not first.is_empty() and is_inside_tree():
		(first[0] as Button).grab_focus.call_deferred()


## Old grid drifts the other way and fades, then frees itself. Its tiles go
## dead right away so a fast click can't land on a tile that's leaving.
func _slide_out(grid: Control, dir: float) -> void:
	grid.name = "Leaving"
	for b in grid.find_children("*", "Button", true, false):
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
	var tw := grid.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(grid, "position:x", grid.position.x - dir * SLIDE_PX, 0.16)
	tw.tween_property(grid, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(grid.queue_free)


## New grid slides in from the side, then each tile pops in a beat after the last.
func _slide_in(grid: Control, dir: float) -> void:
	grid.modulate.a = 0.0
	# yeah, wait a frame: the container hasn't laid the tiles out yet, so
	# position and pivots would be zero
	await get_tree().process_frame
	if not is_instance_valid(grid):
		return
	var home_x := grid.position.x
	grid.position.x += dir * SLIDE_PX
	var tw := grid.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(grid, "position:x", home_x, 0.32).set_delay(0.08)
	tw.tween_property(grid, "modulate:a", 1.0, 0.24).set_delay(0.08)
	var delay := 0.1
	for b: Button in grid.find_children("*", "Button", true, false):
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(0.94, 0.94)
		b.modulate.a = 0.0
		tw.tween_property(b, "scale", Vector2.ONE, 0.34).set_delay(delay).set_trans(Tween.TRANS_BACK)
		tw.tween_property(b, "modulate:a", 1.0, 0.22).set_delay(delay)
		delay += 0.06


func _style_tab(t: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.set_content_margin_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 16
	if selected:
		box.border_color = UiStyle.ACCENT
		box.border_width_bottom = 3
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		t.add_theme_stylebox_override(state, box)
	var c := UiStyle.TEXT if selected else UiStyle.MUTED
	t.add_theme_color_override("font_color", c)
	t.add_theme_color_override("font_hover_color", UiStyle.TEXT)
	t.add_theme_color_override("font_pressed_color", c)


## Hero tile on the left, two smaller ones stacked next to it.
func _home_grid() -> Control:
	var row := UiStyle.hbox(TILE_GAP)
	var hero := _tile("PlayButton", "FEATURED MISSION", _scenario_title(FIRST_SCENARIO),
		"Every gram counts. Design a small satellite, guess what will hold it back, fly it for a month and find out why.",
		"rocket", true, WILDFIRE_ART)
	hero.size_flags_stretch_ratio = 1.6
	hero.pressed.connect(_press.bind(hero, _start.bind(FIRST_SCENARIO)))
	row.add_child(hero)
	var side := UiStyle.vbox(TILE_GAP)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sandbox := _tile("SandboxButton", "FREE PLAY", "Sandbox", "No limits, no goals.", "planet",
		false, _crop(DAY_MAP, ART_EUROPE_DAY))
	sandbox.pressed.connect(_press.bind(sandbox, _start.bind(&"sandbox")))
	side.add_child(sandbox)
	var how := _tile("HowToPlayButton", "LEARN", "How to play", "The loop in two minutes.", "flag",
		false, _crop(NIGHT_MAP, ART_ASIA_NIGHT))
	how.pressed.connect(_press.bind(how, _how_to_play))
	side.add_child(how)
	row.add_child(side)
	return row


## One tile per scenario in the catalog, so new missions show up on their own.
func _play_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for s in Catalog.all("scenarios"):
		var id := StringName(s.id)
		var sandbox: bool = s.get("sandbox", false)
		var kicker := "FREE PLAY" if sandbox else "MISSION · %d DAYS" % int(s.duration_days)
		var art: Texture2D = _crop(DAY_MAP, ART_EUROPE_DAY) if sandbox else WILDFIRE_ART
		var t := _tile(String(id).to_pascal_case() + "Tile", kicker, s.title, s.get("briefing", ""),
			"planet" if sandbox else "rocket", false, art)
		t.pressed.connect(_press.bind(t, _start.bind(id)))
		grid.add_child(t)
	return grid


func _learn_grid() -> Control:
	var row := UiStyle.hbox(TILE_GAP)
	var how := _tile("HowToPlayTile", "LEARN", "How to play",
		"Design, predict, launch, fly, read the report. What each step asks of you and what the numbers mean.",
		"flag", true, _crop(NIGHT_MAP, ART_ASIA_NIGHT))
	how.pressed.connect(_press.bind(how, _how_to_play))
	row.add_child(how)
	return row


## Big clickable card: Earth photo behind, small kicker on top, bold title and
## a line of text at the bottom, icon in the top right. The art sits in a
## rounded mask and the border is a separate frame on top, otherwise the photo
## would paint over both.
func _tile(node_name: String, kicker: String, title: String, body: String, icon_name: String,
		hero := false, photo: Texture2D = null) -> Button:
	var b := Button.new()
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(220, 130)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var mask := Panel.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_theme_stylebox_override("panel", _flat(Color(UiStyle.PANEL, 0.92), 8, 0))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	b.add_child(mask)

	var art: TextureRect
	if photo:
		art = TextureRect.new()
		art.texture = photo
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(0.8, 0.82, 0.9)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.resized.connect(func(): art.pivot_offset = art.size / 2.0)
		mask.add_child(art)
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(shade)

	# accent strip down the left edge, the hero tile gets the warm one
	var strip := ColorRect.new()
	strip.color = UiStyle.ACCENT if hero else UiStyle.CYAN
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	strip.offset_right = 5
	mask.add_child(strip)

	var glyph := UiStyle.icon_rect(icon_name, 72 if hero else 44, Color(UiStyle.TEXT, 0.55))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var px := glyph.custom_minimum_size.x
	glyph.offset_left = -px - 18
	glyph.offset_right = -18
	glyph.offset_top = 16
	glyph.offset_bottom = 16 + px
	b.add_child(glyph)

	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22 if hero else 18)
	b.add_child(m)
	var v := UiStyle.vbox(4)
	m.add_child(v)
	var k := UiStyle.label(kicker, 12, UiStyle.ACCENT if hero else UiStyle.CYAN)
	k.theme_type_variation = &"DisplayLabel"
	v.add_child(k)
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(push)
	var t := UiStyle.label(title.to_upper(), 36 if hero else 22, UiStyle.TEXT)
	t.theme_type_variation = &"DisplayLabel"
	v.add_child(t)
	if not body.is_empty():
		v.add_child(UiStyle.label(body, 15 if hero else 14, Color(UiStyle.TEXT, 0.75), true))
	if hero:
		v.add_child(UiStyle.section("PRESS TO START", "rocket", 13, UiStyle.ACCENT))
	for c in v.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(frame)

	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var refresh := _refresh_tile.bind(b, frame, art)
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited, b.button_down, b.button_up]:
		# hmm, deferred because on mouse_exited the button still thinks it's hovered
		sig.connect(refresh.call_deferred)
	refresh.call()
	return b


## Border plus the lift: a lit tile grows a touch and its photo zooms in.
func _refresh_tile(b: Button, frame: Panel, art: TextureRect) -> void:
	if not is_instance_valid(b):
		return
	var lit := b.is_hovered() or b.has_focus()
	var box := _flat(Color.TRANSPARENT, 8, 0, UiStyle.ACCENT if lit else UiStyle.LINE, 3 if lit else 1)
	box.draw_center = false
	frame.add_theme_stylebox_override("panel", box)
	if _leaving:
		return
	var tw := b.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (HOVER_SCALE if lit else 1.0), 0.18)
	if art:
		tw.tween_property(art, "scale", Vector2.ONE * (1.08 if lit else 1.0), 0.6)


## Tile presses in, the menu fades to the starfield, then `then` runs.
func _press(b: Button, then: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(b, "scale", Vector2.ONE * 0.96, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * HOVER_SCALE, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(then)


func _crop(map: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = map
	a.region = region
	return a


## Clear at the top, dark at the bottom, so the title reads over any photo.
func _shade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(UiStyle.BG, 0.25), Color(UiStyle.BG, 0.2), Color(UiStyle.BG, 0.92)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 128
	return t


func _flat(color: Color, radius: int, pad: int, border := Color.TRANSPARENT, width := 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	if border.a > 0.0:
		b.border_color = border
		b.set_border_width_all(width)
	return b


func _scenario_title(id: StringName) -> String:
	return Catalog.get_entry("scenarios", id).get("title", String(id))


func _how_to_play() -> void:
	EventBus.screen_requested.emit(&"how_to_play")


func _start(scenario_id: StringName) -> void:
	GameState.new_mission(scenario_id, 1)
	EventBus.screen_requested.emit(&"briefing")
