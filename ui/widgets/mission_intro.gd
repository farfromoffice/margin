class_name MissionIntro
extends Control
## A short opening for a mission, played over the briefing screen. It shows the
## scenario's intro beats one at a time over a picture or the 3D Earth and waits
## for the player.

signal finished

const FADE_S := 0.7
## the picture behind the first beats slowly grows by this much over DRIFT_S
const DRIFT_SCALE := 1.12
const DRIFT_S := 20.0

var beat := -1
var _beats: Array[Dictionary] = []
var _done := false
var _photo: TextureRect
var _earth: OrbitView
var _text_box: VBoxContainer
var _kicker: Label
var _text: Label
var _note: Label
var _dots: Array[ColorRect] = []
var _skip: Button
var _hint: Label
## the image path on screen now, "" for the Earth
var _scene := "?"


## set_up fills the beats from the scenario, the goal and days put in the text.
func set_up(s: Scenario) -> void:
	var goal := ""
	for id in s.objectives:
		goal = Explain.goal(id, s.objectives[id])
	for b in s.intro:
		var text := str(b["text"]).format({"goal": goal, "days": s.duration_days})
		_beats.append({"kicker": str(b.get("kicker", "")), "text": text, "note": str(b.get("note", "")), "image": str(b.get("image", ""))})
	_build(s.title)


func _build(title: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(Starfield.new())

	_photo = TextureRect.new()
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.modulate = Color(0.6, 0.6, 0.6, 0.0)
	# the drift grows the picture from its middle
	_photo.resized.connect(func(): _photo.pivot_offset = _photo.size / 2.0)
	add_child(_photo)

	_earth = OrbitView.new()
	_earth.planet_scale = 1.3
	_earth.anchor_left = 0.45
	_earth.anchor_right = 1.0
	_earth.anchor_top = 0.0
	_earth.anchor_bottom = 1.0
	_earth.modulate.a = 0.0
	add_child(_earth)

	# darkens the bottom and the left so the text reads over any picture
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(UiStyle.BG, 0.0))
	g.set_color(1, Color(UiStyle.BG, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(0.0, 1.0)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var head := UiStyle.vbox(6)
	head.position = Vector2(64, 48)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiStyle.section("MISSION BRIEFING", "satellite", 14, UiStyle.CYAN))
	head.add_child(UiStyle.heading(title, 40))
	add_child(head)

	_text_box = UiStyle.vbox(10)
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.anchor_top = 1.0
	_text_box.anchor_bottom = 1.0
	_text_box.offset_left = 64
	_text_box.offset_right = 64 + 760
	_text_box.offset_top = -300
	_text_box.offset_bottom = -110
	_text_box.alignment = BoxContainer.ALIGNMENT_END
	_kicker = UiStyle.label("", 15, UiStyle.ACCENT)
	_kicker.theme_type_variation = &"DisplayLabel"
	_text = UiStyle.label("", 32, UiStyle.TEXT, true)
	_note = UiStyle.label("", 16, UiStyle.MUTED, true)
	_text_box.add_child(_kicker)
	_text_box.add_child(_text)
	_text_box.add_child(_note)
	add_child(_text_box)

	var foot := UiStyle.hbox(8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 64
	foot.offset_top = -64
	foot.offset_bottom = -52
	for i in _beats.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(28, 3)
		d.color = UiStyle.MUTED
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(d)
		_dots.append(d)
	add_child(foot)

	_hint = UiStyle.label("Press Space or click to go on", 16, UiStyle.CYAN)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 64 + 36 * _beats.size() + 12
	_hint.offset_top = -74
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	# a slow breath on the hint, it is clear the intro waits for the player
	var pulse := _hint.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_hint, "modulate:a", 0.45, 1.2)
	pulse.tween_property(_hint, "modulate:a", 1.0, 1.2)

	_skip = UiStyle.button("Skip intro", skip)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.anchor_top = 1.0
	_skip.anchor_bottom = 1.0
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -48
	_skip.offset_bottom = -40
	add_child(_skip)


func _ready() -> void:
	grab_focus()
	next()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		next()
	elif e.is_action_pressed("ui_cancel"):
		skip()
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_right"):
		next()
	else:
		return
	accept_event()


## next shows the following beat or ends the intro after the last one.
func next() -> void:
	if _done:
		return
	if beat + 1 >= _beats.size():
		skip()
		return
	beat += 1
	var b: Dictionary = _beats[beat]
	_kicker.text = b["kicker"]
	_text.text = b["text"]
	_note.text = b["note"]
	_note.visible = not b["note"].is_empty()
	_text_box.modulate.a = 0.0
	create_tween().tween_property(_text_box, "modulate:a", 1.0, FADE_S).set_trans(Tween.TRANS_SINE)
	for i in _dots.size():
		_dots[i].color = UiStyle.ACCENT if i <= beat else UiStyle.MUTED
	if beat == _beats.size() - 1:
		_skip.text = "Continue"
		_hint.text = "Press Space or click to start"
	_show_scene(b["image"])


## _show_scene fades between the picture and the Earth when the beat asks for the
## other one. A picture drifts slowly closer for as long as it stays.
func _show_scene(image: String) -> void:
	if image == _scene:
		return
	_scene = image
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if image.is_empty():
		tw.tween_property(_photo, "modulate:a", 0.0, FADE_S * 1.5)
		tw.tween_property(_earth, "modulate:a", 1.0, FADE_S * 1.5)
		return
	_photo.texture = load(image)
	_photo.scale = Vector2.ONE
	tw.tween_property(_earth, "modulate:a", 0.0, FADE_S)
	tw.tween_property(_photo, "modulate:a", 1.0, FADE_S * 1.5)
	tw.tween_property(_photo, "scale", Vector2.ONE * DRIFT_SCALE, DRIFT_S)


## skip ends the intro now. The briefing fades it out and frees it.
func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()
