class_name SpacecraftModel
extends Node3D
## Builds a CubeSat out of primitive meshes from the parts in a design. Each
## part's `model` field in components.json picks its look; anything unknown
## falls back to the plain look of its category. Units are meters, the long
## axis is Y, the camera looks down (-Y), the antenna end is up (+Y).

const U := 0.1
const RAIL := 0.0085

## structure model -> body size (x, y, z)
const BODY_SIZES := {
	"frame_3u": Vector3(0.1, 0.34, 0.1),
	"frame_6u": Vector3(0.226, 0.366, 0.1),
}

var inside_view := false:
	set(v):
		inside_view = v
		_apply_shell_alpha()

var body := BODY_SIZES["frame_3u"]
var has_structure := false
## hinges of deployable wings, the view animates their rotation
var hinges: Array[Node3D] = []

var _shell: Array[MeshInstance3D] = []
var _mats := {}


## Clears and rebuilds from catalog entries (Dictionaries) of every chosen part.
func rebuild(parts: Array) -> void:
	for child in get_children():
		child.free()
	_shell.clear()
	hinges.clear()
	var by_cat := {}
	for p in parts:
		by_cat[str(p.get("category", ""))] = str(p.get("model", ""))

	has_structure = by_cat.has("structure")
	body = BODY_SIZES.get(by_cat.get("structure", ""), BODY_SIZES["frame_3u"])
	_build_frame(by_cat.get("solar", "") == "body_panels")
	if by_cat.has("solar"):
		_build_solar(by_cat["solar"])
	if by_cat.has("comms"):
		_build_radio(by_cat["comms"])
	if by_cat.has("instrument"):
		_build_camera(by_cat["instrument"])
	if by_cat.has("adcs"):
		_build_adcs(by_cat["adcs"])
	_build_inside(by_cat)
	_apply_shell_alpha()


# --- outside -----------------------------------------------------------------

func _build_frame(body_solar: bool) -> void:
	var h := body / 2.0
	if not has_structure:
		# nothing picked yet: a faint ghost of a 3U so the view isn't empty
		var ghost := _box(body, _mat("ghost"), Vector3.ZERO)
		_shell.append(ghost)
		return
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var rx: float = sx * (h.x - RAIL / 2.0)
			var rz: float = sz * (h.z - RAIL / 2.0)
			# rails stick out 7 mm at both ends, that's what the deployer pushes on
			_box(Vector3(RAIL, body.y + 0.014, RAIL), _mat("rail"), Vector3(rx, 0, rz))
			for sy in [-1, 1]:
				_cyl(0.0022, 0.004, _mat("aluminium"), Vector3(rx, sy * (h.y + 0.009), rz))
	for sy in [-1, 1]:
		_shell.append(_box(Vector3(body.x - 0.002, 0.004, body.z - 0.002), _mat("aluminium"), Vector3(0, sy * h.y, 0)))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_cyl(0.0018, 0.0015, _mat("screw"), Vector3(sx * (h.x - 0.018), sy * (h.y + 0.0025), sz * (h.z - 0.018)))
	# side skins: solar cells if the panels are body mounted, gold foil otherwise
	var skin := _mat("solar") if body_solar else _mat("mli")
	var inset := body - Vector3(RAIL * 2.0, 0.01, RAIL * 2.0)
	_shell.append(_box(Vector3(inset.x, inset.y, 0.002), skin, Vector3(0, 0, h.z - 0.001)))
	_shell.append(_box(Vector3(inset.x, inset.y, 0.002), skin, Vector3(0, 0, -h.z + 0.001)))
	_shell.append(_box(Vector3(0.002, inset.y, inset.z), skin, Vector3(h.x - 0.001, 0, 0)))
	_shell.append(_box(Vector3(0.002, inset.y, inset.z), skin, Vector3(-h.x + 0.001, 0, 0)))


func _build_solar(look: String) -> void:
	match look:
		"wings_double":
			_wings(2, U * 1.0)
		"wings_single":
			_wings(1, body.x)
		_:
			pass # body panels are already the skin


## One wing per side, hinged on the back edge of the ±X faces. They start
## folded flat against the body; the view swings them open.
func _wings(panels: int, panel_w: float) -> void:
	var h := body / 2.0
	for side in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * h.x, 0, -h.z)
		hinge.set_meta("side", side)
		add_child(hinge)
		hinges.append(hinge)
		for i in panels:
			var x: float = side * (panel_w * (i + 0.5) + 0.004 * (i + 1))
			_box(Vector3(panel_w, body.y * 0.97, 0.0016), _mat("solar"), Vector3(x, 0, 0.0008), hinge)
			# PCB substrate behind the cells, green-black like the real ones
			_box(Vector3(panel_w + 0.003, body.y * 0.97 + 0.003, 0.0016), _mat("substrate"), Vector3(x, 0, -0.0008), hinge)
			for k in [-0.3, 0.3]:
				var pin := _cyl(0.0022, 0.012, _mat("aluminium"), Vector3(side * (panel_w * i + 0.004 * i + 0.002), body.y * k, 0), hinge)
				pin.rotation = Vector3.ZERO


func _build_radio(look: String) -> void:
	var h := body / 2.0
	match look:
		"uhf_whips":
			# four tape measure whips off the top plate
			# antenna module box with four tape spring whips, deployed in a cross
			_box(Vector3(body.x * 0.95, 0.007, body.z * 0.95), _mat("black"), Vector3(0, h.y + 0.006, 0))
			for i in 4:
				var a := i * PI / 2.0
				var whip := _box(Vector3(0.17, 0.0005, 0.005), _mat("bronze"), Vector3.ZERO)
				whip.position = Vector3(cos(a) * (0.085 + body.x * 0.3), h.y + 0.008, sin(a) * (0.085 + body.z * 0.3))
				whip.rotation = Vector3(0, -a, 0)
		"patch_x":
			for i in 2:
				for j in 2:
					_box(Vector3(0.022, 0.022, 0.003), _mat("gold"), Vector3(-0.013 + i * 0.026, -h.y + 0.06 + j * 0.026, h.z + 0.002))
		_:
			_box(Vector3(0.05, 0.05, 0.004), _mat("patch"), Vector3(0, h.y - 0.05, h.z + 0.002))


func _build_camera(look: String) -> void:
	var h := body / 2.0
	var r := 0.032
	var barrel := _mat("black")
	match look:
		"lens_thermal":
			barrel = _mat("gold")
		"lens_cooled":
			r = 0.04
			# radiator for the cryocooler on the back face
			_box(Vector3(body.x * 0.8, body.y * 0.35, 0.003), _mat("radiator"), Vector3(0, -h.y + body.y * 0.2, -h.z - 0.003))
	_cyl(r, 0.03, barrel, Vector3(0, -h.y - 0.012, 0))
	# baffle lip, then the lens sits a little recessed inside it
	_cyl(r * 1.05, 0.004, _mat("aluminium"), Vector3(0, -h.y - 0.028, 0))
	_cyl(r * 0.8, 0.002, _mat("glass"), Vector3(0, -h.y - 0.026, 0))


func _build_adcs(_look: String) -> void:
	var h := body / 2.0
	# sun sensor on the top plate, the only bit of the ADCS you see from outside
	_box(Vector3(0.018, 0.006, 0.018), _mat("black"), Vector3(0.025, h.y + 0.004, 0.02))
	_box(Vector3(0.01, 0.002, 0.01), _mat("glass"), Vector3(0.025, h.y + 0.008, 0.02))


# --- inside, only visible with inside_view ------------------------------------

func _build_inside(by_cat: Dictionary) -> void:
	var h := body / 2.0
	var w := minf(body.x, body.z) - RAIL * 2.5
	var y := -h.y + (0.09 if by_cat.has("instrument") else 0.02)
	if by_cat.has("instrument"):
		_box(Vector3(w * 0.8, 0.075, w * 0.8), _mat("black"), Vector3(0, -h.y + 0.045, 0))
	if by_cat.has("adcs"):
		_box(Vector3(w, 0.004, w), _mat("pcb"), Vector3(0, y, 0))
		var wheel_r := 0.016 if by_cat["adcs"] == "wheels_small" else 0.021
		for axis in 3:
			var wheel := _cyl(wheel_r, 0.012, _mat("aluminium"), Vector3(-0.022 + axis * 0.022, y + 0.025, 0))
			wheel.rotation = [Vector3(0, 0, PI / 2.0), Vector3.ZERO, Vector3(PI / 2.0, 0, 0)][axis]
		y += 0.055
	if by_cat.has("battery"):
		_box(Vector3(w, 0.004, w), _mat("pcb"), Vector3(0, y, 0))
		var rows := 2 if by_cat["battery"] == "battery_small" else 4
		# 18650 cells lying flat, two side by side, kept inside the stack footprint
		for i in rows:
			for j in 2:
				var cell := _cyl(0.009, w * 0.95, _mat("battery"), Vector3(0, y + 0.012 + i * 0.019, -w * 0.22 + j * w * 0.44))
				cell.rotation = Vector3(0, 0, PI / 2.0)
		y += 0.02 + rows * 0.019
	if by_cat.has("obc"):
		_box(Vector3(w, 0.004, w), _mat("pcb"), Vector3(0, y, 0))
		_box(Vector3(0.02, 0.004, 0.02), _mat("black"), Vector3(0.01, y + 0.004, 0.005))
		y += 0.025
	if by_cat.has("comms"):
		_box(Vector3(w, 0.004, w), _mat("pcb"), Vector3(0, y, 0))
		_box(Vector3(0.03, 0.01, 0.025), _mat("aluminium"), Vector3(-0.01, y + 0.007, 0))


# --- helpers -----------------------------------------------------------------

## Inside view is a cutaway: skins and end plates go, rails and parts stay.
## hmm, per instance transparency would be nicer but the Compatibility
## renderer ignores it, so hiding is the honest option.
func _apply_shell_alpha() -> void:
	for m in _shell:
		m.visible = not inside_view


func _box(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, mat, pos, parent)


func _cyl(radius: float, height: float, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _add(mesh, mat, pos, parent)


func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"aluminium":
			_pbr(m, Color(0.82, 0.83, 0.86), 1.0, 0.3)
		"rail":
			# hard anodized rails, darker and duller than bare aluminium
			_pbr(m, Color(0.3, 0.31, 0.33), 0.8, 0.42)
		"screw":
			_pbr(m, Color(0.6, 0.6, 0.62), 1.0, 0.35)
		"mli":
			# crinkled gold foil, the normal map does all the work
			_pbr(m, Color(0.9, 0.66, 0.3), 1.0, 0.34)
			m.normal_enabled = true
			m.normal_texture = _crinkle_texture()
			m.normal_scale = 0.35
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(6, 6, 6)
		"gold":
			_pbr(m, Color(0.95, 0.75, 0.3), 1.0, 0.22)
		"bronze":
			_pbr(m, Color(0.75, 0.55, 0.35), 1.0, 0.3)
		"black":
			_pbr(m, Color(0.035, 0.035, 0.045), 0.2, 0.62)
		"substrate":
			_pbr(m, Color(0.06, 0.1, 0.08), 0.1, 0.5)
		"glass":
			_pbr(m, Color(0.02, 0.03, 0.06), 0.0, 0.02)
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.0
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.2
		"patch":
			_pbr(m, Color(0.92, 0.9, 0.82), 0.1, 0.6)
		"radiator":
			_pbr(m, Color(0.93, 0.94, 0.96), 0.0, 0.7)
		"pcb":
			_pbr(m, Color(0.05, 0.3, 0.15), 0.1, 0.32)
		"battery":
			_pbr(m, Color(0.2, 0.45, 0.85), 0.6, 0.35)
		"ghost":
			_pbr(m, Color(0.4, 0.8, 1.0, 0.18), 0.0, 1.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"solar":
			# cells under cover glass: dark, glossy, the sky shows up in them
			_pbr(m, Color.WHITE, 0.35, 0.12)
			m.albedo_texture = _solar_texture()
			# triplanar in local meters: one 256 px tile is two 4 cm cells
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(12.5, 12.5, 12.5)
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.05
	_mats[kind] = m
	return m


func _pbr(m: StandardMaterial3D, color: Color, metallic: float, roughness: float) -> void:
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness


## Triple junction cells: dark blue-violet, cropped corners (cut from round
## wafers), thin silver grid fingers and a bus bar, white substrate in the gaps.
func _solar_texture() -> ImageTexture:
	const N := 256
	const CELL := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var gap := Color(0.82, 0.83, 0.85)
	for x in N:
		for y in N:
			var cx := x % CELL
			var cy := y % CELL
			var c := Color(0.06, 0.07, 0.2).lerp(Color(0.12, 0.08, 0.28), float(cy) / CELL)
			var edge := mini(mini(cx, CELL - 1 - cx), mini(cy, CELL - 1 - cy))
			var corner := mini(cx, CELL - 1 - cx) + mini(cy, CELL - 1 - cy)
			if edge < 3 or corner < 22:
				c = gap
			elif cy % 11 == 0:
				c = Color(0.45, 0.47, 0.55)
			elif absi(cx - CELL / 2) < 2:
				c = Color(0.75, 0.76, 0.8)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _crinkle_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = noise
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 2.5
	return t
