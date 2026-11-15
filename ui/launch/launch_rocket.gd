class_name LaunchRocket
extends Node3D
## A generic two stage launcher built from lathed meshes, sized from the
## launcher entry. Origin is the bottom of the engines, +Y up, meters. No
## livery or shape copied from a real vehicle: white body, dark interstage.
## Also builds the pieces the orbit shot needs: upper stage and fairing halves.

var length_m := 70.0
var diameter_m := 3.7
## exhaust, smoke trail and engine glow; the scene switches them on and off
var flame: CPUParticles3D
var trail: CPUParticles3D
var glow: OmniLight3D


func _init(p_length_m := 70.0, p_diameter_m := 3.7) -> void:
	length_m = p_length_m
	diameter_m = p_diameter_m
	var r := diameter_m / 2.0
	var l := length_m
	var white := paint(Color(0.93, 0.93, 0.91), 0.0, 0.42)
	var dark := paint(Color(0.07, 0.07, 0.08), 0.0, 0.6)
	var metal := paint(Color(0.32, 0.31, 0.3), 0.85, 0.35)

	var bell_h := maxf(r * 0.9, 0.6)
	var body := MeshInstance3D.new()
	body.mesh = lathe(PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r, l * 0.62)]), 32)
	body.material_override = white
	body.position.y = bell_h
	add_child(body)
	var inter := MeshInstance3D.new()
	inter.mesh = lathe(PackedVector2Array([Vector2(r, 0), Vector2(r, l * 0.06)]), 32)
	inter.material_override = dark
	inter.position.y = bell_h + l * 0.62
	add_child(inter)
	var upper := MeshInstance3D.new()
	upper.mesh = lathe(PackedVector2Array([Vector2(r, 0), Vector2(r, l * 0.16)]), 32)
	upper.material_override = white
	upper.position.y = bell_h + l * 0.68
	add_child(upper)
	var nose := MeshInstance3D.new()
	nose.mesh = lathe(fairing_profile(r, l * 0.16), 32)
	nose.material_override = white
	nose.position.y = bell_h + l * 0.84
	add_child(nose)
	# a thin dark ring at the base of the fairing, the split line
	var ring := MeshInstance3D.new()
	ring.mesh = lathe(PackedVector2Array([Vector2(r * 1.005, 0), Vector2(r * 1.005, l * 0.004)]), 32)
	ring.material_override = dark
	ring.position.y = nose.position.y
	add_child(ring)

	# engine cluster: one bell for a small rocket, a ring of them for a big one
	var bells := 1 if diameter_m < 2.0 else 7
	for i in bells:
		var b := MeshInstance3D.new()
		var br := r * (0.55 if bells == 1 else 0.24)
		b.mesh = lathe(PackedVector2Array([Vector2(br, 0), Vector2(br * 0.45, bell_h * 0.85), Vector2(br * 0.35, bell_h)]), 20)
		b.material_override = metal
		if i > 0:
			var a := TAU * float(i - 1) / float(bells - 1)
			b.position = Vector3(cos(a), 0, sin(a)) * r * 0.58
		add_child(b)

	flame = exhaust(r, false)
	add_child(flame)
	trail = smoke_trail(r)
	# starts below the flame, not round the engines
	trail.position.y = -r * 6.0
	add_child(trail)
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.3)
	glow.omni_range = l * 0.9
	glow.light_energy = 0.0
	glow.position.y = -r
	add_child(glow)


## Top of the stack, where the fairing sits. Handy for the camera.
func top_y() -> float:
	return maxf(diameter_m / 2.0 * 0.9, 0.6) + length_m


## Profile of a fairing: straight sides, then an ogive closing to a rounded tip.
static func fairing_profile(r: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(r, 0)])
	var straight := h * 0.45
	pts.append(Vector2(r, straight))
	for i in range(1, 11):
		var f := float(i) / 10.0
		pts.append(Vector2(r * sqrt(1.0 - f * f * 0.97), straight + (h - straight) * f))
	pts.append(Vector2(0, h))
	return pts


## Spins a profile (x = radius, y = height) round the Y axis between two angles.
## Half shells for the fairing use from..to of 0..PI.
static func lathe(profile: PackedVector2Array, segments: int, from_angle := 0.0, to_angle := TAU) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a0 := lerpf(from_angle, to_angle, float(s) / segments)
		var a1 := lerpf(from_angle, to_angle, float(s + 1) / segments)
		for i in profile.size() - 1:
			var p0 := profile[i]
			var p1 := profile[i + 1]
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			# Godot culls counter-clockwise faces, so this order faces outward
			for v in [v00, v11, v10, v00, v01, v11]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func paint(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## Engine exhaust pointing down from the origin. Vacuum flames are wider and
## bluer, the air squeezes the sea level one into a tight orange plume.
static func exhaust(r: float, vacuum: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 160
	p.lifetime = 0.35
	p.preprocess = p.lifetime
	p.local_coords = true
	p.mesh = _puff_mesh(true, r * 1.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.35
	p.direction = Vector3.DOWN
	p.spread = 14.0 if vacuum else 5.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = r * 18.0
	p.initial_velocity_max = r * 24.0
	p.scale_amount_min = 1.4 if vacuum else 0.9
	p.scale_amount_max = 2.2 if vacuum else 1.4
	var g := Gradient.new()
	if vacuum:
		g.set_color(0, Color(0.85, 0.9, 1.0, 0.9))
		g.set_color(1, Color(0.3, 0.45, 1.0, 0.0))
	else:
		g.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
		g.add_point(0.35, Color(1.0, 0.55, 0.18, 0.9))
		g.set_color(g.get_point_count() - 1, Color(0.9, 0.25, 0.05, 0.0))
	p.color_ramp = g
	return p


## World space smoke left behind the rocket, a rising column.
static func smoke_trail(r: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 420
	p.lifetime = 9.0
	# yeah, cursed: the Compatibility renderer draws particles that haven't been
	# born yet as black discs at the emitter, so we start one lifetime in
	p.preprocess = p.lifetime
	p.local_coords = false
	p.mesh = _puff_mesh(false, r * 4.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.6
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.gravity = Vector3(0.6, 0.15, 0)
	p.initial_velocity_min = r * 2.0
	p.initial_velocity_max = r * 5.0
	p.damping_min = r * 1.5
	p.damping_max = r * 2.5
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.max_value = 2.0
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 2.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.7, 0.55))
	g.add_point(0.1, Color(0.86, 0.85, 0.83, 0.5))
	g.set_color(g.get_point_count() - 1, Color(0.74, 0.75, 0.77, 0.0))
	p.color_ramp = g
	return p


## Soft round billboard. Flames glow (unshaded, additive), smoke takes the sun.
## _puff_mesh builds one smoke puff. Its size is set on the quad since particle
## scale alone left the puffs as specks.
static func _puff_mesh(glowing: bool, size_m: float) -> QuadMesh:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glowing:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		# billboards lit from behind turn into dark discs, so smoke carries its
		# own shade in the colour ramp instead of taking the sun
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size_m
	q.material = m
	return q
