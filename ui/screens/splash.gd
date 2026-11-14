extends Control
## Studio logo on black before the game. The skyline draws in from the left,
## the house windows flicker on, then it fades and hands over to the app.
## Any key or click skips it.

const NEXT_SCENE := "res://scenes/app.tscn"
const LOGO_WIDTH_RATIO := 0.62

var _logo: Control
var _lines: TextureRect
var _lights: TextureRect
var _glow: TextureRect
var _tween: Tween
var _leaving := false


func _ready() -> void:
	# hidden still delivers clicks, so skipping with the mouse keeps working
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	# all three layers share one canvas size, so stacking them lines up for free
	_glow = _layer(preload("res://ui/brand/logo_glow.png"))
	_lines = _layer(preload("res://ui/brand/logo_lines.png"))
	_lights = _layer(preload("res://ui/brand/logo_lights.png"))
	var reveal := ShaderMaterial.new()
	reveal.shader = preload("res://ui/brand/logo_reveal.gdshader")
	_lines.material = reveal
	_lights.modulate.a = 0.0
	_glow.modulate.a = 0.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive

	resized.connect(_fit_logo)
	_fit_logo()
	_play()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed and not _leaving:
		get_viewport().set_input_as_handled()
		_leave(0.35)


func _layer(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _fit_logo() -> void:
	var tex_size := _lines.texture.get_size()
	var w := size.x * LOGO_WIDTH_RATIO
	_logo.size = Vector2(w, w * tex_size.y / tex_size.x)
	_logo.pivot_offset = _logo.size * 0.5
	_logo.position = (size - _logo.size) * 0.5


func _play() -> void:
	# slow push in on its own tween, otherwise its long step holds back the lights
	_logo.scale = Vector2.ONE * 0.97
	create_tween().tween_property(_logo, "scale", Vector2.ONE, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween = create_tween()
	_tween.tween_interval(0.4)
	_tween.tween_method(_set_reveal, 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# yeah, an old bulb catching: two quick blinks before it holds
	for step: Array in [[0.9, 0.06], [0.0, 0.08], [0.6, 0.05], [0.0, 0.14], [1.0, 0.25]]:
		_tween.tween_property(_lights, "modulate:a", step[0], step[1])
	_tween.parallel().tween_property(_glow, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(1.3)
	_tween.tween_callback(_leave.bind(0.8))


func _set_reveal(value: float) -> void:
	(_lines.material as ShaderMaterial).set_shader_parameter(&"progress", value)


func _leave(duration: float) -> void:
	if _leaving:
		return
	_leaving = true
	if _tween:
		_tween.kill()
	var out := create_tween()
	out.tween_property(_logo, "modulate:a", 0.0, duration)
	out.tween_callback(_go_next)


func _go_next() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(NEXT_SCENE)
