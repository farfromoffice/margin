class_name Starfield
extends Control
## Slowly drifting, twinkling stars with a couple of faint nebula glows. Sits
## behind every screen. Fixed seed, so the sky looks the same every launch.

const STAR_COUNT := 260
## px per second for the far, middle and near layer
const LAYER_SPEED: Array[float] = [3.0, 7.0, 14.0]

var _stars: Array[Dictionary] = []
var _time := 0.0
var _glow_tex: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = g
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 256
	_glow_tex.height = 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 1969
	for i in STAR_COUNT:
		var layer := rng.randi_range(0, 2)
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"layer": layer,
			"size": 0.6 + layer * 0.55 + rng.randf() * 0.5,
			"phase": rng.randf() * TAU,
			"rate": 0.6 + rng.randf() * 2.2,
			# mostly white, a few warm and cool ones
			"tint": [Color.WHITE, Color("ffe2b0"), Color("b8d6ff")][rng.randi_range(0, 2)],
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BG)
	_glow(Vector2(size.x * 0.82, size.y * 0.18), size.y * 0.55, Color(0.45, 0.25, 0.75, 0.16))
	_glow(Vector2(size.x * 0.12, size.y * 0.9), size.y * 0.6, Color(0.1, 0.4, 0.7, 0.14))
	for s in _stars:
		var speed: float = LAYER_SPEED[s["layer"]]
		var p: Vector2 = s["pos"] * size
		p.x = fposmod(p.x - _time * speed, size.x)
		var twinkle := 0.55 + 0.45 * sin(_time * s["rate"] + s["phase"])
		var c: Color = s["tint"]
		c.a = (0.35 + 0.25 * s["layer"]) * twinkle + 0.15
		draw_circle(p, s["size"], c)


func _glow(center: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_glow_tex, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)
