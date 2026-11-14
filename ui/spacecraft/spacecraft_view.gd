class_name SpacecraftView
extends SubViewportContainer
## Live 3D look at the design: the CubeSat over Earth, lit by a hard Sun, with
## sky reflections on metal and glass. Drag to turn it, wheel to zoom,
## "Inside" cuts the skin away. Rebuilds whenever the design changes. The
## expand button only asks; the screen decides what to hide for more room.

signal expand_toggled(on: bool)

const SKY_SHADER := preload("res://ui/spacecraft/space_sky.gdshader")
const WING_OPEN_S := 1.2
const DRAG_RAD_PER_PX := 0.008

var model: SpacecraftModel
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _yaw := 0.7
var _pitch := -0.08
var _distance := 0.9
var _dragging := false
var _idle_s := 0.0
var _last_solar := ""
var _inside_button: Button
var _expand_button: Button
var _sky_mat: ShaderMaterial
var _caption: Label


func _init() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300, 300)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# the sky is black above, so sky ambient leaves shadow sides pitch black.
	# Realistic, but you couldn't read the parts; a flat cool fill instead.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.38, 0.5)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.55, 0.9, 0.0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3.0
	_viewport.add_child(sun)
	# earthshine: dim blue light bouncing up from the planet below
	var earth_light := DirectionalLight3D.new()
	earth_light.rotation = Vector3(PI / 2.0, 0, 0)
	earth_light.light_energy = 0.6
	earth_light.light_color = Color(0.45, 0.65, 1.0)
	_viewport.add_child(earth_light)

	model = SpacecraftModel.new()
	_viewport.add_child(model)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.near = 0.01
	_pivot.add_child(_camera)

	_inside_button = UiStyle.button("Inside", func(): model.inside_view = _inside_button.button_pressed)
	_inside_button.toggle_mode = true
	_inside_button.icon = UiStyle.icon("chip")
	_inside_button.position = Vector2(12, 12)
	add_child(_inside_button)
	_expand_button = UiStyle.button("Expand", func(): expand_toggled.emit(_expand_button.button_pressed))
	_expand_button.toggle_mode = true
	_expand_button.toggled.connect(func(on: bool): _expand_button.text = "Back" if on else "Expand")
	add_child(_expand_button)
	_caption = UiStyle.label("Drag to turn · wheel to zoom", 13, UiStyle.MUTED)
	add_child(_caption)


func _ready() -> void:
	resized.connect(func():
		_caption.position = Vector2(14, size.y - 28)
		_expand_button.position = Vector2(size.x - _expand_button.size.x - 12, 12))


## parts: catalog entries of every chosen component and instrument
func show_parts(parts: Array) -> void:
	model.rebuild(parts)
	var solar := ""
	for p in parts:
		if p.get("category") == "solar":
			solar = str(p.get("id", ""))
	# fresh wings swing open, ones already shown stay open
	var animate := solar != _last_solar
	_last_solar = solar
	for hinge in model.hinges:
		var side: int = hinge.get_meta("side")
		hinge.rotation.y = side * PI / 2.0 if animate else 0.0
		if animate:
			var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(hinge, "rotation:y", 0.0, WING_OPEN_S)
	_distance = clampf(model.body.y * 2.6 + (0.35 if not model.hinges.is_empty() else 0.0), 0.6, 2.0)


func _process(delta: float) -> void:
	if not _dragging:
		_idle_s += delta
		if _idle_s > 2.0:
			_yaw += delta * 0.25
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_camera.position = Vector3(0, 0, _distance)
	_sky_mat.set_shader_parameter("spin", Time.get_ticks_msec() / 1000.0 * 0.004)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				_idle_s = 0.0
			MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(_distance * 0.9, 0.3)
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(_distance * 1.1, 3.0)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * DRAG_RAD_PER_PX
		_pitch = clampf(_pitch - event.relative.y * DRAG_RAD_PER_PX, -1.2, 0.5)
		_idle_s = 0.0
