class_name OrbitView
extends Control
## Earth with a tilted orbit ring and the spacecraft on it. Either spins on its
## own (menu) or follows `angle` set by the run view. The Sun is on the left,
## so the craft dims on the right side of the ring, inside Earth's shadow.
## With `interactive` on, dragging the globe spins and tilts it.

const EARTH_SHADER := preload("res://ui/widgets/earth.gdshader")
const DAY_MAP := preload("res://ui/earth/blue_marble.jpg")
const NIGHT_MAP := preload("res://ui/earth/black_marble.jpg")

var auto_spin := true
## radians per second when spinning on its own
var spin_speed := 0.35
## 0..TAU around the ring, 0 is the far right, deepest in the shadow
var angle := 0.0
## share of the ring in Earth's shadow, centered on the side away from the Sun
var eclipse_fraction := 0.36
var in_shadow := false
var tilt := -0.32
## size of the planet relative to the view, the menu wants a bigger one
var planet_scale := 1.0
var interactive := false:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

var _planet: ColorRect
var _front: Control
var _sat: Texture2D = UiStyle.icon("satellite")
var _earth_spin := 0.0
var _pitch := 0.0
var _dragging := false
## extra spin speed left over from a fling, fades out after release
var _fling := 0.0

# negative turns the surface left to right, the way Earth turns with north up
const IDLE_SPIN := -0.05
const DRAG_RAD_PER_PX := 0.008
const MAX_PITCH := 0.9


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet = ColorRect.new()
	_planet.material = ShaderMaterial.new()
	_planet.material.shader = EARTH_SHADER
	_planet.material.set_shader_parameter("day_map", DAY_MAP)
	_planet.material.set_shader_parameter("night_map", NIGHT_MAP)
	_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_planet)
	# front half of the ring and the craft have to sit on top of the planet
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.draw.connect(_draw_front)
	add_child(_front)


func _process(delta: float) -> void:
	if auto_spin:
		angle = fmod(angle + delta * spin_speed, TAU)
	in_shadow = absf(wrapf(angle, -PI, PI)) < eclipse_fraction * PI
	if not _dragging:
		_earth_spin += (IDLE_SPIN + _fling) * delta
		_fling *= exp(-1.8 * delta)
	_planet.material.set_shader_parameter("spin", _earth_spin)
	_planet.material.set_shader_parameter("pitch", _pitch)
	var r := _radius()
	_planet.position = size / 2.0 - Vector2(r, r)
	_planet.size = Vector2(r, r) * 2.0
	queue_redraw()
	_front.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(size / 2.0) <= _radius():
			_dragging = true
			_fling = 0.0
			accept_event()
		elif not event.pressed and _dragging:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		var over: bool = event.position.distance_to(size / 2.0) <= _radius()
		mouse_default_cursor_shape = Control.CURSOR_DRAG if (over or _dragging) else Control.CURSOR_ARROW
		if _dragging:
			# dragging right should turn the near side right, so spin goes the other way
			var step: float = -event.relative.x * DRAG_RAD_PER_PX
			_earth_spin += step
			_pitch = clampf(_pitch + event.relative.y * DRAG_RAD_PER_PX * 0.7, -MAX_PITCH, MAX_PITCH)
			# hmm, velocity per event is noisy; one event is about one frame, good enough
			_fling = clampf(step * Engine.get_frames_per_second(), -6.0, 6.0)
			accept_event()


func _radius() -> float:
	return minf(size.x / 2.2, size.y) * 0.32 * planet_scale


func _ring() -> Vector2:
	var r := _radius()
	return Vector2(r * 1.9, r * 0.62)


func _draw() -> void:
	var c := size / 2.0
	var r := _radius()
	for i in 10:
		draw_circle(c, r * (1.16 - i * 0.015), Color(0.35, 0.65, 1.0, 0.03))
	_draw_ring(c, _ring(), PI, TAU, Color(UiStyle.CYAN, 0.22))
	if _behind():
		_draw_sat(_front_pos())


func _draw_front() -> void:
	var c := size / 2.0
	_draw_ring(c, _ring(), 0.0, PI, Color(UiStyle.CYAN, 0.55), _front)
	if not _behind():
		_draw_sat(_front_pos(), _front)


## Upper half of the ring passes behind the planet.
func _behind() -> bool:
	return sin(angle) < 0.0


func _front_pos() -> Vector2:
	return _on_ring(size / 2.0, _ring(), angle)


func _draw_sat(p: Vector2, canvas: CanvasItem = self) -> void:
	var s := clampf(_radius() * 0.32, 22.0, 44.0)
	var col := Color(0.45, 0.5, 0.65) if in_shadow else Color.WHITE
	if not in_shadow:
		canvas.draw_circle(p, s * 0.55, Color(UiStyle.ACCENT, 0.16))
	canvas.draw_texture_rect(_sat, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false, col)


func _draw_ring(c: Vector2, ring: Vector2, from: float, to: float, color: Color, canvas: CanvasItem = self) -> void:
	var pts := PackedVector2Array()
	for i in 65:
		pts.append(_on_ring(c, ring, lerpf(from, to, i / 64.0)))
	canvas.draw_polyline(pts, color, 1.5, true)


func _on_ring(c: Vector2, ring: Vector2, a: float) -> Vector2:
	return c + Vector2(cos(a) * ring.x, sin(a) * ring.y).rotated(tilt)
