class_name LaunchComplex
extends Node3D
## A coastal launch site, scaled to the rocket: raised pad with a flame trench,
## a lattice service tower, lightning masts with their wires, a water tower,
## propellant spheres, an assembly building down the crawler road and scrub all
## round. Generic on purpose, it is a launch site, not a copy of one.
## Pad center is the origin, the sea is to the +X side.

const GROUND_SHADER := preload("res://ui/launch/ground.gdshader")
const PAD_H := 6.0
const COAST_X := 900.0

var rocket_length := 70.0
var _steel: StandardMaterial3D
var _concrete: StandardMaterial3D


func _init(p_rocket_length := 70.0, rocket_diameter := 3.7) -> void:
	rocket_length = p_rocket_length
	var l := rocket_length
	_steel = LaunchRocket.paint(Color(0.5, 0.5, 0.52), 0.6, 0.5)
	_concrete = LaunchRocket.paint(Color(0.6, 0.59, 0.56), 0.0, 0.9)
	# weathered slabs: low contrast noise, full contrast reads as snow
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.49, 0.46))
	ramp.set_color(1, Color(0.66, 0.65, 0.61))
	noise.color_ramp = ramp
	_concrete.albedo_texture = noise
	_concrete.uv1_triplanar = true
	_concrete.uv1_scale = Vector3.ONE * 0.05
	_concrete.albedo_color = Color.WHITE

	_ground()
	# raised hardstand with a ramp and the flame trench running out to one side
	_box(Vector3(70, PAD_H, 70), _concrete, Vector3(0, PAD_H / 2.0, 0))
	_box(Vector3(30, PAD_H, 60), _concrete, Vector3(-50, PAD_H / 2.0 - 1.5, 0), Vector3(0, 0, deg_to_rad(8)))
	var trench := LaunchRocket.paint(Color(0.12, 0.11, 0.1), 0.0, 1.0)
	_box(Vector3(70, 0.4, 12), trench, Vector3(20, PAD_H + 0.05, 0))
	var mount_h := maxf(rocket_diameter * 0.8, 2.0)
	_box(Vector3(rocket_diameter * 2.2, mount_h, rocket_diameter * 2.2), _steel, Vector3(0, PAD_H + mount_h / 2.0, -rocket_diameter * 1.4))
	_tower(rocket_diameter)
	for i in 4:
		# on the diagonals, so none stands between the start camera (+Z) and the rocket
		var a := TAU * (i + 0.5) / 4.0
		_mast(Vector3(cos(a), 0, sin(a)) * maxf(l * 1.1, 60.0), l * 1.45)
	_water_tower(Vector3(-l * 1.2 - 40, 0, l * 1.0 + 30), l)
	for i in 2:
		_sphere_tank(Vector3(-90 - i * 28, 0, -110), 11.0, Color(0.9, 0.9, 0.88))
	_sphere_tank(Vector3(95, 0, -120), 9.0, Color(0.92, 0.92, 0.9))
	_assembly_building(Vector3(-1600, 0, -900))
	_crawler_road(Vector3(-40, 0, 0), Vector3(-1520, 0, -860))
	for p in [Vector3(-250, 0, 220), Vector3(-320, 0, -260), Vector3(220, 0, 260)]:
		_shed(p)
	_scrub()


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(16000, 16000)
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("pad_radius", 120.0)
	m.set_shader_parameter("coast_x", COAST_X)
	var g := MeshInstance3D.new()
	g.mesh = plane
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


## Square lattice tower beside the rocket: four legs, a deck every few meters,
## X bracing on each face and an access arm near the top.
func _tower(rocket_diameter: float) -> void:
	var h := rocket_length * 1.12
	var w := clampf(rocket_length * 0.13, 5.0, 12.0)
	var root := Node3D.new()
	root.position = Vector3(-(rocket_diameter / 2.0 + w / 2.0 + 3.0), PAD_H, 0)
	add_child(root)
	var leg := w * 0.06
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_box(Vector3(leg, h, leg), _steel, Vector3(cx * w / 2.0, h / 2.0, cz * w / 2.0), Vector3.ZERO, root)
	var level := w * 0.9
	var n := int(h / level)
	var brace := leg * 0.45
	var diag := sqrt(w * w + level * level)
	var tilt := atan2(level, w)
	for i in n + 1:
		var y := i * level
		_box(Vector3(w, brace, w), _steel, Vector3(0, y, 0), Vector3.ZERO, root)
		if i == n:
			break
		var mid := y + level / 2.0
		for side in 4:
			var yaw := side * PI / 2.0
			var out := Vector3(sin(yaw), 0, cos(yaw)) * w / 2.0
			for s in [-1, 1]:
				var b := _box(Vector3(diag, brace, brace), _steel, out + Vector3(0, mid, 0), Vector3.ZERO, root)
				b.rotation = Vector3(0, yaw, s * tilt)
	var arm_len := w / 2.0 + rocket_diameter / 2.0 + 3.0
	_box(Vector3(arm_len, w * 0.2, w * 0.2), _steel, Vector3(arm_len / 2.0, h * 0.86, 0), Vector3.ZERO, root)
	# red beacon light on top, aircraft warning
	var beacon := LaunchRocket.paint(Color(1, 0.1, 0.05), 0.0, 0.4)
	beacon.emission_enabled = true
	beacon.emission = Color(1, 0.1, 0.05)
	beacon.emission_energy_multiplier = 3.0
	_box(Vector3.ONE * w * 0.06, beacon, Vector3(0, h + w * 0.05, 0), Vector3.ZERO, root)


## Lightning mast with a catenary wire sagging down to the ground.
func _mast(pos: Vector3, h: float) -> void:
	var mast := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.35
	c.bottom_radius = 0.9
	c.height = h
	mast.mesh = c
	mast.material_override = _steel
	mast.position = pos + Vector3(0, h / 2.0, 0)
	add_child(mast)
	var anchor := pos * 1.6
	var top := pos + Vector3(0, h, 0)
	var wire_mat := LaunchRocket.paint(Color(0.2, 0.2, 0.2), 0.5, 0.6)
	var steps := 8
	for i in steps:
		var a := _sag(top, anchor, float(i) / steps)
		var b := _sag(top, anchor, float(i + 1) / steps)
		var seg := _box(Vector3(0.12, 0.12, a.distance_to(b)), wire_mat, (a + b) / 2.0)
		seg.basis = Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)


func _sag(a: Vector3, b: Vector3, f: float) -> Vector3:
	return a.lerp(b, f) - Vector3(0, sin(f * PI) * a.distance_to(b) * 0.06, 0)


func _water_tower(pos: Vector3, l: float) -> void:
	var h := maxf(l * 0.6, 30.0)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_box(Vector3(0.8, h, 0.8), _steel, pos + Vector3(cx * 4.0, h / 2.0, cz * 4.0))
	var tank := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 7.0
	s.height = 11.0
	tank.mesh = s
	tank.material_override = LaunchRocket.paint(Color(0.86, 0.86, 0.84), 0.2, 0.5)
	tank.position = pos + Vector3(0, h + 4.0, 0)
	add_child(tank)


func _sphere_tank(pos: Vector3, r: float, color: Color) -> void:
	var tank := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	tank.mesh = s
	tank.material_override = LaunchRocket.paint(color, 0.3, 0.35)
	tank.position = pos + Vector3(0, r + 3.0, 0)
	add_child(tank)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_box(Vector3(0.6, r + 3.0, 0.6), _steel, pos + Vector3(cx * r * 0.6, (r + 3.0) / 2.0, cz * r * 0.6))


## Tall assembly hall with ribbed walls and a high door facing the pad.
func _assembly_building(pos: Vector3) -> void:
	var size := Vector3(150, 160, 190)
	var wall := LaunchRocket.paint(Color(0.8, 0.8, 0.78), 0.0, 0.8)
	var b := _box(size, wall, pos + Vector3(0, size.y / 2.0, 0))
	# nodes aren't in the tree yet, so no look_at(); the door (-Z) faces the pad
	b.basis = Basis.looking_at(Vector3(-pos.x, 0, -pos.z), Vector3.UP)
	var rib := LaunchRocket.paint(Color(0.68, 0.68, 0.66), 0.0, 0.85)
	for i in 9:
		var x := -size.x / 2.0 + (i + 0.5) * size.x / 9.0
		_box(Vector3(1.5, size.y, 1.5), rib, Vector3(x, 0, -size.z / 2.0 - 0.7), Vector3.ZERO, b)
	var door := LaunchRocket.paint(Color(0.35, 0.37, 0.4), 0.3, 0.6)
	_box(Vector3(size.x * 0.28, size.y * 0.85, 0.6), door, Vector3(0, -size.y * 0.075, -size.z / 2.0 - 1.2), Vector3.ZERO, b)
	_box(Vector3(60, 40, 90), wall, Vector3(size.x / 2.0 + 30, -size.y / 2.0 + 20, 0), Vector3.ZERO, b)


func _crawler_road(from: Vector3, to: Vector3) -> void:
	var gravel := LaunchRocket.paint(Color(0.66, 0.63, 0.58), 0.0, 1.0)
	var road := _box(Vector3(36, 0.3, from.distance_to(to)), gravel, (from + to) / 2.0 + Vector3(0, 0.15, 0))
	road.basis = Basis.looking_at(to - from, Vector3.UP)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _shed(pos: Vector3) -> void:
	var m := LaunchRocket.paint(Color(0.72, 0.72, 0.7), 0.1, 0.7)
	_box(Vector3(26, 9, 16), m, pos + Vector3(0, 4.5, 0))


## Low bushes scattered round the site, off the apron, the road and the beach.
func _scrub() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.6
	mesh.height = 2.2
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = LaunchRocket.paint(Color(0.12, 0.2, 0.08), 0.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var xforms: Array[Transform3D] = []
	while xforms.size() < 2500:
		var p := Vector3(rng.randf_range(-2600, COAST_X - 120), 0, rng.randf_range(-2600, 2600))
		if p.length() < 160.0:
			continue
		var s := rng.randf_range(0.6, 2.4)
		xforms.append(Transform3D(Basis().scaled(Vector3(s, s * rng.randf_range(0.6, 1.1), s)), p + Vector3(0, s * 0.5, 0)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
