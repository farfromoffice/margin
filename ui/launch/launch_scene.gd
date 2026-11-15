class_name LaunchScene
extends SubViewportContainer
## The launch in 3D. Before the countdown it is an inspection view of the
## rocket on the pad (drag to turn, wheel to zoom). launch() plays a fixed
## sequence: ignition, liftoff watched from the ground, a chase camera while the
## sky darkens, then a cut to orbit where the fairing opens and the player's own
## spacecraft separates and unfolds. It is a picture of the launch, the timing
## is not computed from any physics. milestone() fires as each stage is reached.

signal milestone(id: StringName)
signal finished

const SPACE_SKY := preload("res://ui/spacecraft/space_sky.gdshader")
const MILESTONES: Array[StringName] = [&"countdown", &"liftoff", &"ascent", &"pitch", &"fairing", &"separation", &"deploy", &"handover"]
const T_IGNITION := 3.0
const T_LIFTOFF := 4.5
const T_CHASE := 10.5
const T_PITCH := 12.5
const T_FADE := 16.5
const FADE_S := 0.7
## orbit part, seconds after the cut
const S_FAIRING := 1.2
const S_CUTOFF := 3.2
const S_SEPARATION := 4.2
const S_DEPLOY := 6.4
const S_HANDOVER := 9.0
const DRAG_RAD_PER_PX := 0.008

var payload: SpacecraftModel
var _viewport: SubViewport
var _env: Environment
var _pad_sky: ProceduralSkyMaterial
var _space_env: Environment
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _camera: Camera3D
var _pad_root: Node3D
var _space_root: Node3D
var _complex: LaunchComplex
var _rocket: LaunchRocket
var _pad_smoke: CPUParticles3D
var _stage: Node3D
var _fairing: Array[Node3D] = []
var _vac_flame: CPUParticles3D
var _fade: ColorRect
var _caption: Label

var _t := -1.0
var _next := 0
var _in_space := false
var _done := false
var _vel := 0.0
var _climb := Vector3.ZERO
var _ground_cam := Vector3.ZERO
var _yaw := 0.6
var _pitch := 0.12
var _distance := 2.3
var _dragging := false
var _payload_drift := 0.0
var _parts: Array = []


func _init() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300, 300)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_pad_sky = ProceduralSkyMaterial.new()
	_pad_sky.sky_top_color = Color(0.16, 0.36, 0.68)
	_pad_sky.sky_horizon_color = Color(0.62, 0.72, 0.82)
	_pad_sky.ground_horizon_color = Color(0.55, 0.6, 0.62)
	_pad_sky.ground_bottom_color = Color(0.18, 0.2, 0.18)
	_pad_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _pad_sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.7
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.08
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.66, 0.74, 0.82)
	_env.fog_density = 0.00025
	_env.fog_sky_affect = 0.0

	var space_sky := Sky.new()
	var space_mat := ShaderMaterial.new()
	space_mat.shader = SPACE_SKY
	space_sky.sky_material = space_mat
	_space_env = Environment.new()
	_space_env.background_mode = Environment.BG_SKY
	_space_env.sky = space_sky
	_space_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_space_env.ambient_light_color = Color(0.32, 0.38, 0.5)
	_space_env.ambient_light_energy = 0.6
	_space_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_space_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_space_env.glow_enabled = true
	_space_env.glow_intensity = 0.35

	_world_env = WorldEnvironment.new()
	_world_env.environment = _env
	_viewport.add_child(_world_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-32), deg_to_rad(-40), 0)
	_sun.light_energy = 1.6
	_sun.light_color = Color(1.0, 0.96, 0.9)
	_sun.shadow_enabled = true
	_viewport.add_child(_sun)

	_pad_root = Node3D.new()
	_viewport.add_child(_pad_root)
	_space_root = Node3D.new()
	_space_root.visible = false
	_viewport.add_child(_space_root)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 30000.0
	_viewport.add_child(_camera)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_caption = UiStyle.label("Drag to turn · wheel to zoom", 13, UiStyle.MUTED)
	add_child(_caption)


func _ready() -> void:
	var place := func(): _caption.position = Vector2(14, size.y - 28)
	resized.connect(place)
	# full screen hosts size us before _ready, so that resize is already gone
	place.call()


## Builds the rocket for this launcher and loads the payload the player built.
## launcher is the launchers.json entry; parts are the chosen component entries.
func set_up(launcher: Dictionary, parts: Array) -> void:
	_parts = parts
	for c in _pad_root.get_children():
		c.queue_free()
	for c in _space_root.get_children():
		c.queue_free()
	_fairing.clear()
	var length := float(launcher.get("rocket_length_m", 70.0))
	var diameter := float(launcher.get("rocket_diameter_m", 3.7))
	_complex = LaunchComplex.new(length, diameter)
	_pad_root.add_child(_complex)
	_rocket = LaunchRocket.new(length, diameter)
	_rocket.position = Vector3(0, LaunchComplex.PAD_H + maxf(diameter * 0.8, 2.0), 0)
	_pad_root.add_child(_rocket)
	_pad_smoke = _ground_smoke(diameter)
	_pad_smoke.position = Vector3(18.0, LaunchComplex.PAD_H + 1.0, 0)
	_pad_root.add_child(_pad_smoke)
	_sun.directional_shadow_max_distance = length * 6.0
	_build_space(diameter)
	_reset_camera()


func launch() -> void:
	if _t < 0.0:
		_t = 0.0
		_caption.visible = false


## Jumps to the end state, the spacecraft open in orbit, firing every milestone
## not reached yet in order.
func skip() -> void:
	if _done:
		return
	if _t < 0.0:
		launch()
	_t = _end_t()
	_enter_space()
	_fade.color.a = 0.0
	_vac_flame.emitting = false
	_open_fairing(true)
	_stage.position.y = -12.0
	_payload_drift = 1.0
	_deploy_wings(true)
	_emit_due()


func _process(delta: float) -> void:
	if _rocket == null:
		return
	if _t < 0.0:
		_yaw += delta * 0.06 if not _dragging else 0.0
		_orbit_camera(_rocket.position + Vector3(0, _rocket.top_y() * 0.5, 0), _rocket.length_m * _distance)
		return
	if _done:
		_space_orbit(delta)
		return
	_t += delta
	if not _in_space:
		_pad_update(delta)
	else:
		_space_update(delta)
	_emit_due()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(_distance * 0.9, 0.4)
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(_distance * 1.1, 6.0)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * DRAG_RAD_PER_PX
		_pitch = clampf(_pitch + event.relative.y * DRAG_RAD_PER_PX, -0.05, 1.3)


func _milestone_t(i: int) -> float:
	var space := T_FADE + FADE_S
	return [0.0, T_LIFTOFF, T_CHASE, T_PITCH, space + S_FAIRING, space + S_SEPARATION, space + S_DEPLOY, space + S_HANDOVER][i]


func _end_t() -> float:
	return _milestone_t(MILESTONES.size() - 1)


func _emit_due() -> void:
	while _next < MILESTONES.size() and _t >= _milestone_t(_next):
		milestone.emit(MILESTONES[_next])
		_next += 1
	if _next >= MILESTONES.size() and not _done:
		_done = true
		finished.emit()


func _pad_update(delta: float) -> void:
	var l := _rocket.length_m
	var burning := _t >= T_IGNITION
	_rocket.flame.emitting = burning
	_rocket.glow.light_energy = randf_range(5.0, 8.0) if burning else 0.0
	_pad_smoke.emitting = burning and _t < T_LIFTOFF + 5.0
	if _t >= T_LIFTOFF:
		_rocket.trail.emitting = true
		# not real thrust, only enough acceleration to clear the tower in about four
		# seconds and be a dot by the cut.
		var tau := _t - T_LIFTOFF
		_vel = l * (tau / 8.0 + tau * tau / 20.0)
		var tilt := clampf((_t - T_PITCH) * 0.09, 0.0, 0.55)
		_rocket.rotation.z = -tilt
		_climb = Vector3(sin(tilt), cos(tilt), 0)
		_rocket.position += _climb * _vel * delta
	var height := _rocket.position.y
	_thin_air(clampf(height / (l * 55.0), 0.0, 1.0))

	var target := _rocket.position + _rocket.basis.y * _rocket.top_y() * 0.5
	if _t < T_LIFTOFF + 0.6:
		_orbit_camera(target, l * _distance)
		_ground_cam = _camera.position
	elif _t < T_CHASE:
		# spectators' view: fixed on the ground, zooming in as it climbs
		# eye height on the hardstand, a ground camera would only see the pad wall
		_camera.position = Vector3(_ground_cam.x, LaunchComplex.PAD_H + 2.0, _ground_cam.z)
		_camera.look_at(target, Vector3.UP)
		var dist := _camera.position.distance_to(target)
		_camera.fov = clampf(rad_to_deg(2.0 * atan(l * 1.8 / (2.0 * dist))), 3.0, 45.0)
	else:
		_camera.fov = lerpf(_camera.fov, 48.0, minf(delta * 2.0, 1.0))
		var behind := Vector3(-l * 0.7, -l * 1.1, l * 1.5)
		_camera.position = _rocket.position + behind
		_camera.look_at(_rocket.position + _rocket.basis.y * l * 0.6, Vector3.UP)
	if _t >= T_FADE:
		_fade.color.a = clampf((_t - T_FADE) / (FADE_S * 0.5), 0.0, 1.0)
		if _t >= T_FADE + FADE_S * 0.5:
			_enter_space()


## Lerps the day sky towards black and the fog away as the rocket climbs. The
## air thins steadily, there is no edge, so neither does the picture.
func _thin_air(f: float) -> void:
	var dark := Color(0.01, 0.015, 0.04)
	_pad_sky.sky_top_color = Color(0.16, 0.36, 0.68).lerp(dark, f)
	_pad_sky.sky_horizon_color = Color(0.62, 0.72, 0.82).lerp(Color(0.25, 0.45, 0.75), f)
	_env.fog_density = lerpf(0.00025, 0.00002, f)
	_env.ambient_light_energy = lerpf(0.7, 0.35, f)


func _enter_space() -> void:
	if _in_space:
		return
	_in_space = true
	_pad_root.visible = false
	_rocket.flame.emitting = false
	_rocket.trail.emitting = false
	_space_root.visible = true
	_world_env.environment = _space_env
	# side on, so the fairing halves fly off left and right, not into the lens.
	# It then swings round towards the sunlit side of the spacecraft.
	_yaw = PI / 2.0
	_pitch = 0.12
	_sun.rotation = Vector3(-0.55, 0.9, 0.0)
	_sun.light_energy = 2.2
	_sun.directional_shadow_max_distance = 30.0
	_camera.near = 0.01
	_camera.far = 500.0
	_camera.fov = 40.0
	_vac_flame.emitting = true
	_distance = 1.0


func _space_update(delta: float) -> void:
	var s := _t - T_FADE - FADE_S
	_fade.color.a = clampf(1.0 - (s + FADE_S * 0.5) / (FADE_S * 0.5), 0.0, 1.0)
	if s >= S_FAIRING:
		_open_fairing(false)
	if s >= S_CUTOFF:
		_vac_flame.emitting = false
	if s >= S_SEPARATION:
		# stage backs off, the spacecraft drifts free on its springs
		_stage.position.y -= delta * 1.6
		_payload_drift = minf(_payload_drift + delta * 0.35, 1.0)
	if s >= S_DEPLOY:
		_deploy_wings(false)
	_space_orbit(delta)


## Camera on the payload: starts wide enough to see the whole fairing and closes
## in on the spacecraft as it leaves the stage.
func _space_orbit(delta: float) -> void:
	payload.position.y = _payload_base_y() + _payload_drift * 1.2
	var d := float(_stage.get_meta("diameter"))
	var close := clampf(payload.body.y * 2.6 + (0.35 if not payload.hinges.is_empty() else 0.0), 0.6, 2.0)
	var wide := d * 4.2
	var k := smoothstep(0.0, 1.0, _payload_drift)
	if not _dragging:
		_yaw -= delta * (0.12 if not _done else 0.05)
	_orbit_camera(payload.position.lerp(Vector3(0, d * 0.6, 0), 1.0 - k), lerpf(wide, close, k) * _distance)


func _orbit_camera(target: Vector3, dist: float) -> void:
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_camera.position = target + dir * dist
	_camera.look_at(target, Vector3.UP)


func _reset_camera() -> void:
	_yaw = 0.0
	_pitch = 0.1
	_distance = 2.3


## The orbit shot: the upper stage under the spacecraft, both fairing halves
## around it and a vacuum flame. Scaled from the rocket diameter so a CubeSat
## sits small in a big fairing, as it does on a rideshare.
func _build_space(diameter: float) -> void:
	var r := diameter / 2.0
	_stage = Node3D.new()
	_stage.set_meta("diameter", diameter)
	_space_root.add_child(_stage)
	var body := MeshInstance3D.new()
	body.mesh = LaunchRocket.lathe(PackedVector2Array([Vector2(r, -diameter * 2.2), Vector2(r, 0), Vector2(r * 0.35, r * 0.25), Vector2(0, r * 0.25)]), 32)
	body.material_override = LaunchRocket.paint(Color(0.93, 0.93, 0.91), 0.0, 0.42)
	_stage.add_child(body)
	var bell := MeshInstance3D.new()
	bell.mesh = LaunchRocket.lathe(PackedVector2Array([Vector2(r * 0.8, 0), Vector2(r * 0.3, r * 1.1), Vector2(r * 0.25, r * 1.3)]), 24)
	bell.material_override = LaunchRocket.paint(Color(0.3, 0.28, 0.26), 0.85, 0.35)
	bell.position.y = -diameter * 2.2 - r * 1.3
	_stage.add_child(bell)
	_vac_flame = LaunchRocket.exhaust(r * 0.8, true)
	_vac_flame.position.y = bell.position.y
	_stage.add_child(_vac_flame)
	var adapter := MeshInstance3D.new()
	adapter.mesh = LaunchRocket.lathe(PackedVector2Array([Vector2(0.25, 0), Vector2(0.12, 0.08)]), 20)
	adapter.material_override = LaunchRocket.paint(Color(0.25, 0.25, 0.27), 0.7, 0.4)
	adapter.position.y = r * 0.25
	_stage.add_child(adapter)

	var white := LaunchRocket.paint(Color(0.93, 0.93, 0.91), 0.0, 0.45)
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in 2:
		var half := Node3D.new()
		var m := MeshInstance3D.new()
		m.mesh = LaunchRocket.lathe(LaunchRocket.fairing_profile(r, diameter * 2.4), 24, side * PI, (side + 1) * PI)
		m.material_override = white
		half.add_child(m)
		half.set_meta("side", side)
		_stage.add_child(half)
		_fairing.append(half)

	payload = SpacecraftModel.new()
	_space_root.add_child(payload)
	payload.rebuild(_parts)
	payload.position.y = _payload_base_y()
	# folded until deployment
	for hinge in payload.hinges:
		hinge.rotation.y = int(hinge.get_meta("side")) * PI / 2.0


func _payload_base_y() -> float:
	var r := float(_stage.get_meta("diameter")) / 2.0
	return r * 0.25 + 0.08 + payload.body.y / 2.0


func _open_fairing(instant: bool) -> void:
	for half in _fairing:
		if half.has_meta("opened"):
			continue
		half.set_meta("opened", true)
		var side := 1.0 if int(half.get_meta("side")) == 0 else -1.0
		var d := float(_stage.get_meta("diameter"))
		var end_rot := Vector3(side * 1.3, 0, 0)
		var end_pos := Vector3(0, -d * 1.5, side * d * 7.0)
		if instant:
			half.visible = false
			continue
		var tw := create_tween().set_parallel()
		tw.tween_property(half, "rotation", end_rot, 3.0).set_ease(Tween.EASE_OUT)
		tw.tween_property(half, "position", end_pos, 3.0).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(half.hide)


func _deploy_wings(instant: bool) -> void:
	for hinge in payload.hinges:
		if hinge.has_meta("deployed"):
			continue
		hinge.set_meta("deployed", true)
		if instant:
			hinge.rotation.y = 0.0
			continue
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(hinge, "rotation:y", 0.0, SpacecraftView.WING_OPEN_S)


## Ground cloud at ignition, pushed out along the flame trench.
func _ground_smoke(diameter: float) -> CPUParticles3D:
	var p := LaunchRocket.smoke_trail(diameter / 2.0 * 2.5)
	p.amount = 200
	p.lifetime = 7.0
	p.preprocess = p.lifetime
	# out along the trench, across the view rather than into the lens
	p.direction = Vector3(1, 0.25, 0)
	p.spread = 35.0
	p.initial_velocity_min = diameter * 6.0
	p.initial_velocity_max = diameter * 12.0
	p.gravity = Vector3(0, 1.5, 0)
	return p
