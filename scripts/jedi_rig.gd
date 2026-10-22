extends Node3D
# Personaje Jedi procedimental: cuerpo articulado, sable de luz y cinematica inversa.
# El sable sigue poses clave (anticipacion, golpe, seguimiento) y los brazos y
# piernas se resuelven con IK de dos huesos, asi las manos siempre agarran la
# empunadura y los pies pisan el suelo.
# Espacio local del rig: mira hacia +Z y su derecha es -X (el luchador lo gira 180).

const ARM_A := 0.29
const ARM_B := 0.27
const LEG_A := 0.43
const LEG_B := 0.43
const GRIP_R := 0.035
const GRIP_L := -0.095
const POLE_R := Vector3(-0.6, -0.9, -0.55)
const POLE_L := Vector3(0.6, -0.9, -0.55)
const POLE_KR := Vector3(-0.15, 0.0, 1.0)
const POLE_KL := Vector3(0.15, 0.0, 1.0)
const BLADE_LEN := 0.95
const BLADE_BASE := 0.135
# Lado por el que entra el golpe del atacante -> guardia del defensor que lo intercepta.
const SIDE_TO_BLOCK := {"R": "L", "L": "R", "H": "H", "M": "M", "Lo": "Lo"}

const Characters = preload("res://scripts/characters.gd")

static var CLIPS: Dictionary = {}
static var BLOCKS: Dictionary = {}

var look_name: String = "anakin"
var look: Dictionary = {}
var grip_r: float = GRIP_R
var grip_l: float = GRIP_L
var cape_hinges: Array[Node3D] = []
var blades: Array = []  # [{node, tip, sign}] una o dos hojas
var hilt_half: float = 0.0
var saber_color: Color = Color(0.3, 0.6, 1.0)
var guard_pose: Dictionary
var pose: Dictionary
var clip: Dictionary = {}
var clip_name: String = ""
var clip_t: float = 0.0
var clip_speed: float = 1.0
var hold_clip: bool = false
var ignite: float = 0.0
var ignite_target: float = 1.0
var corr_world: Vector3 = Vector3.ZERO
var kick: Vector3 = Vector3.ZERO
var gait: float = 0.0
var stride: float = 0.0
var move_dir: Vector3 = Vector3(0, 0, 1)
var bob: float = 0.0
var one_hand_smooth: float = 0.0
var head_dip: float = 0.0
var clock: float = 0.0
var seed_offset: float = 0.0

var body: Node3D
var pelvis: Node3D
var spine: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var sh_r: Node3D
var el_r: Node3D
var ha_r: Node3D
var sh_l: Node3D
var el_l: Node3D
var ha_l: Node3D
var hp_r: Node3D
var kn_r: Node3D
var hp_l: Node3D
var kn_l: Node3D
var ft_r: Node3D
var ft_l: Node3D
var saber: Node3D
var blade: Node3D
var blade_tip: Node3D
var blade_light: OmniLight3D
var blade_glow_mat: StandardMaterial3D
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_mat: StandardMaterial3D
var trail_points: Array = []
var sfx: Node
var hum: AudioStreamPlayer3D
var swing_cooldown: float = 0.0

# ---------------------------------------------------------------- poses
static func P(hx: float, hy: float, hz: float, dx: float, dy: float, dz: float, o: Dictionary = {}) -> Dictionary:
	return {
		"h": Vector3(hx, hy, hz), "d": Vector3(dx, dy, dz).normalized(),
		"lh": o.get("lh", Vector3(0.34, 1.0, 0.12)), "tw": float(o.get("tw", 0.0)),
		"ln": float(o.get("ln", 0.0)), "cr": float(o.get("cr", 0.08)), "oh": float(o.get("oh", 0.0)),
		"st": float(o.get("st", 0.0)),
	}

static func _static_init() -> void:
	CLIPS = {
		"slashR": {"side": "R", "hit": 0.27, "keys": [
			[0.15, "io", P(-0.42, 1.36, 0.02, -0.75, 0.5, -0.42, {"tw": -0.55, "cr": 0.11, "st": -0.25})],
			[0.27, "in", P(-0.25, 1.22, 0.45, 0.12, 0.08, 1.0, {"ln": 0.18, "cr": 0.14, "st": 1.0})],
			[0.37, "out", P(0.26, 1.08, 0.36, 0.85, -0.12, 0.25, {"tw": 0.5, "ln": 0.2, "cr": 0.14, "st": 1.0})],
			[0.6, "io", "guard"]]},
		"slashL": {"side": "L", "hit": 0.27, "keys": [
			[0.15, "io", P(0.27, 1.38, 0.08, 0.72, 0.5, -0.45, {"tw": 0.55, "cr": 0.11, "st": -0.25})],
			[0.27, "in", P(0.12, 1.22, 0.45, -0.12, 0.08, 1.0, {"ln": 0.18, "cr": 0.14, "st": 1.0})],
			[0.37, "out", P(-0.32, 1.08, 0.34, -0.85, -0.12, 0.25, {"tw": -0.45, "ln": 0.2, "cr": 0.14, "st": 1.0})],
			[0.6, "io", "guard"]]},
		"overhead": {"side": "H", "hit": 0.33, "keys": [
			[0.18, "io", P(-0.06, 1.74, -0.04, -0.05, 0.5, -0.86, {"ln": -0.12, "cr": 0.05, "st": -0.35})],
			[0.33, "in", P(-0.06, 1.32, 0.44, 0.0, 0.28, 0.96, {"ln": 0.2, "cr": 0.15, "st": 1.1})],
			[0.43, "out", P(-0.04, 0.98, 0.42, 0.0, -0.55, 0.83, {"ln": 0.32, "cr": 0.22, "st": 1.1})],
			[0.72, "io", "guard"]]},
		"thrust": {"side": "M", "hit": 0.27, "keys": [
			[0.16, "io", P(-0.25, 1.12, -0.06, 0.05, 0.12, 1.0, {"tw": -0.5, "cr": 0.13, "st": -0.3})],
			[0.27, "in", P(-0.12, 1.22, 0.55, 0.0, 0.04, 1.0, {"tw": 0.15, "ln": 0.22, "cr": 0.16, "oh": 0.85, "lh": Vector3(0.42, 1.15, -0.22), "st": 1.35})],
			[0.36, "out", P(-0.12, 1.2, 0.5, 0.0, 0.02, 1.0, {"tw": 0.12, "ln": 0.2, "cr": 0.16, "oh": 0.85, "lh": Vector3(0.42, 1.15, -0.22), "st": 1.3})],
			[0.62, "io", "guard"]]},
		"rising": {"side": "Lo", "hit": 0.28, "keys": [
			[0.16, "io", P(0.26, 0.92, 0.12, 0.55, -0.65, 0.45, {"tw": 0.45, "cr": 0.2, "st": -0.2})],
			[0.28, "in", P(0.0, 1.12, 0.45, -0.25, 0.45, 0.86, {"ln": 0.12, "cr": 0.13, "st": 0.9})],
			[0.38, "out", P(-0.3, 1.5, 0.25, -0.55, 0.8, -0.1, {"tw": -0.45, "cr": 0.08, "st": 0.9})],
			[0.64, "io", "guard"]]},
		"recoil": {"keys": [
			[0.1, "out", P(-0.16, 1.24, 0.22, 0.18, 0.88, 0.3, {"ln": -0.06, "cr": 0.1, "st": 0.3})],
			[0.34, "io", "guard"]]},
		"stagger": {"keys": [
			[0.12, "out", P(-0.3, 1.5, -0.1, -0.45, 0.7, -0.55, {"ln": -0.3, "tw": -0.4, "cr": 0.05, "st": -0.7})],
			[0.55, "io", P(-0.25, 1.4, -0.02, -0.3, 0.8, -0.4, {"ln": -0.22, "tw": -0.3, "cr": 0.08, "st": -0.6})],
			[0.85, "io", "guard"]]},
		"hit": {"keys": [
			[0.08, "out", P(-0.15, 0.98, 0.16, 0.3, 0.6, 0.5, {"ln": -0.25, "cr": 0.13, "tw": 0.2, "st": -0.5})],
			[0.42, "io", "guard"]]},
		"push": {"hit": 0.24, "keys": [
			[0.14, "io", P(-0.32, 1.12, -0.02, -0.3, 0.85, -0.3, {"tw": -0.35, "cr": 0.12, "oh": 1.0, "lh": Vector3(0.2, 1.3, 0.1), "st": -0.2})],
			[0.24, "out", P(-0.34, 1.14, -0.04, -0.3, 0.85, -0.3, {"tw": 0.1, "ln": 0.12, "cr": 0.14, "oh": 1.0, "lh": Vector3(0.08, 1.42, 0.66), "st": 0.7})],
			[0.5, "io", P(-0.34, 1.14, -0.04, -0.3, 0.85, -0.3, {"tw": 0.1, "ln": 0.1, "cr": 0.12, "oh": 1.0, "lh": Vector3(0.08, 1.42, 0.62), "st": 0.6})],
			[0.8, "io", "guard"]]},
		"ko": {"keys": [
			[0.25, "out", P(-0.1, 0.95, 0.2, 0.4, 0.7, 0.5, {"ln": -0.2, "cr": 0.15})],
			[0.9, "io", P(0.05, 0.58, 0.38, 0.2, -0.25, 0.95, {"ln": 0.55, "cr": 0.42, "oh": 1.0, "lh": Vector3(0.25, 0.55, 0.35)})]]},
	}
	BLOCKS = {
		"L": P(0.14, 1.06, 0.34, 0.12, 0.95, 0.3, {"tw": 0.4, "cr": 0.12}),
		"R": P(-0.3, 1.05, 0.34, -0.15, 0.95, 0.28, {"tw": -0.3, "cr": 0.12}),
		"H": P(-0.18, 1.58, 0.32, 1.0, 0.12, 0.15, {"tw": -0.25, "cr": 0.1}),
		"M": P(-0.22, 1.02, 0.38, 0.75, 0.6, 0.25, {"cr": 0.13}),
		"Lo": P(-0.24, 0.92, 0.36, -0.15, -0.7, 0.65, {"tw": -0.2, "cr": 0.18}),
		"idle": P(-0.08, 1.12, 0.3, 0.35, 0.88, 0.3, {"cr": 0.1}),
	}

static func _ease(kind: String, t: float) -> float:
	match kind:
		"in": return t * t
		"out": return 1.0 - (1.0 - t) * (1.0 - t)
		"lin": return t
	return t * t * (3.0 - 2.0 * t)

static func _crm(p0, p1, p2, p3, t: float):
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((p1 * 2.0) + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t3)

static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from.dot(to) < -0.9999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(from, to)

# ---------------------------------------------------------------- construccion
func setup(character: String, blade_color: Color = Color(0, 0, 0, 0)) -> void:
	look_name = character
	look = Characters.get_data(character)
	saber_color = blade_color if blade_color.a > 0.0 else look["saber"]
	seed_offset = randf() * 10.0
	match String(look.get("guard", "")):
		"upright":
			guard_pose = P(-0.04, 1.12, 0.26, 0.02, 0.96, 0.28, {"tw": -0.08, "cr": 0.05})
		"double":
			guard_pose = P(-0.04, 1.1, 0.28, -0.8, 0.5, 0.25, {"tw": -0.2, "cr": 0.14})
		"fencer":
			# Esgrima clasica de Dooku: una mano, hoja adelantada, la otra atras.
			guard_pose = P(-0.2, 1.15, 0.3, 0.12, 0.62, 0.78, {"tw": -0.35, "cr": 0.06, "oh": 1.0, "lh": Vector3(0.32, 1.22, -0.12)})
		_:
			if character == "anakin" or character == "luke" or character == "rey":
				guard_pose = P(-0.1, 1.12, 0.26, 0.28, 0.85, 0.45, {"tw": -0.2, "cr": 0.09})
			else:
				guard_pose = P(-0.06, 1.1, 0.28, 0.1, 0.92, 0.38, {"tw": -0.15, "cr": 0.08})
	if look.get("double", false):
		grip_r = 0.075
		grip_l = -0.075
	pose = guard_pose.duplicate()
	_build_skeleton()
	_dress()
	_build_saber()
	_build_trail()
	sfx = get_tree().get_first_node_in_group("sfx") if is_inside_tree() else null
	if is_instance_valid(sfx):
		var base_pitch: float = clampf(1.0 / float(look.get("scale", 1.0)), 0.85, 1.2)
		if look_name == "vader" or look_name == "kylo":
			base_pitch = 0.82
		hum = sfx.call("make_hum", saber, base_pitch)
		sfx.call("play", "ignite", -8.0, base_pitch)

func _joint(parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j

func _mat(c: Color, rough: float = 0.8, metal: float = 0.0, double_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _cap(r: float, len: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = len + r * 2.0
	m.radial_segments = 14
	m.rings = 6
	return m

func _cyl(rt: float, rb: float, h: float, open: bool = false) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 18
	m.rings = 1
	if open:
		m.cap_top = false
		m.cap_bottom = false
	return m

func _sph(r: float, hemi: bool = false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * (1.0 if hemi else 2.0)
	m.is_hemisphere = hemi
	m.radial_segments = 20
	m.rings = 10
	return m

func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

func _build_skeleton() -> void:
	body = _joint(self, Vector3(0, 0.95, 0))
	pelvis = _joint(body)
	spine = _joint(pelvis, Vector3(0, 0.08, 0))
	chest = _joint(spine, Vector3(0, 0.22, 0))
	neck = _joint(chest, Vector3(0, 0.26, 0))
	head = _joint(neck, Vector3(0, 0.13, 0))
	sh_r = _joint(chest, Vector3(-0.19, 0.22, 0))
	el_r = _joint(sh_r, Vector3(0, -ARM_A, 0))
	ha_r = _joint(el_r, Vector3(0, -ARM_B, 0))
	sh_l = _joint(chest, Vector3(0.19, 0.22, 0))
	el_l = _joint(sh_l, Vector3(0, -ARM_A, 0))
	ha_l = _joint(el_l, Vector3(0, -ARM_B, 0))
	hp_r = _joint(pelvis, Vector3(-0.095, -0.04, 0))
	kn_r = _joint(hp_r, Vector3(0, -LEG_A, 0))
	hp_l = _joint(pelvis, Vector3(0.095, -0.04, 0))
	kn_l = _joint(hp_l, Vector3(0, -LEG_A, 0))
	ft_r = _joint(self, Vector3(-0.14, 0.08, -0.2))
	ft_l = _joint(self, Vector3(0.13, 0.08, 0.21))

func _dress() -> void:
	var L := look
	var skin := _mat(L["skin"], 0.6)
	var torso := _mat(L["torso"], 0.85)
	var over := _mat(L["over"], 0.6)
	var sleeve := _mat(L["sleeve"], 0.9)
	var legs := _mat(L["legs"], 0.9)
	var glossy: bool = L.has("helmet")
	var boots := _mat(L["boots"], 0.25 if glossy else 0.5, 0.3 if glossy else 0.1)
	var belt := _mat(L["belt"], 0.5, 0.4)
	var glove := _mat(Color(0.02, 0.02, 0.02), 0.35, 0.2)
	var hair := _mat(L.get("hair", Color(0.1, 0.1, 0.1)), 0.95)
	if glossy:
		over.metallic = 0.5
		over.roughness = 0.3
	# Tronco
	_add(pelvis, _cyl(0.15, 0.16, 0.2), legs, Vector3(0, -0.02, 0), Vector3(1, 1, 0.75))
	_add(spine, _cyl(0.145, 0.15, 0.26), torso, Vector3(0, 0.08, 0), Vector3(1, 1, 0.72))
	_add(chest, _cyl(0.185, 0.15, 0.32), over, Vector3(0, 0.07, 0), Vector3(1, 1, 0.68))
	for s in [-1.0, 1.0]:
		_add(chest, _sph(0.072), sleeve, Vector3(s * 0.19, 0.2, 0))
		if not glossy:
			var strip := _add(chest, _box(Vector3(0.07, 0.3, 0.015)), _mat((L["torso"] as Color).darkened(0.15)), Vector3(s * 0.045, 0.06, 0.112))
			strip.rotation.z = -s * 0.32
	_add(neck, _cyl(0.05, 0.056, 0.14), skin, Vector3(0, 0.03, 0))
	_add(pelvis, _cyl(0.16, 0.16, 0.07), belt, Vector3(0, 0.08, 0), Vector3(1, 1, 0.76))
	_add(pelvis, _box(Vector3(0.06, 0.045, 0.02)), _mat(Color(0.7, 0.7, 0.72), 0.3, 0.9), Vector3(0, 0.08, 0.122))
	var skirt_len: float = L.get("skirt", 0.44)
	_add(pelvis, _cyl(0.165, 0.25 + skirt_len * 0.05, skirt_len, true), _mat(L["torso"], 0.85, 0.0, true), Vector3(0, 0.06 - skirt_len * 0.5, 0), Vector3(1, 1, 0.8))
	# Brazos
	for data in [[sh_r, el_r, ha_r, glove if L.get("glove_r", false) else skin], [sh_l, el_l, ha_l, glove if L.get("glove_l", false) else skin]]:
		_add(data[0], _cap(0.052, 0.2), sleeve, Vector3(0, -0.145, 0))
		if L.get("wide_sleeves", false):
			_add(data[1], _cyl(0.047, 0.078, 0.22, true), _mat(L["sleeve"], 0.9, 0.0, true), Vector3(0, -0.12, 0))
		_add(data[1], _cap(0.044, 0.18), sleeve, Vector3(0, -0.135, 0))
		_add(data[2], _sph(0.046), data[3], Vector3(0, -0.01, 0), Vector3(0.9, 1.15, 0.8))
	# Piernas
	for data in [[hp_r, kn_r, ft_r], [hp_l, kn_l, ft_l]]:
		_add(data[0], _cap(0.074, 0.3), legs, Vector3(0, -0.215, 0))
		_add(data[1], _cap(0.06, 0.3), legs, Vector3(0, -0.215, 0))
		_add(data[1], _cyl(0.07, 0.064, 0.28), boots, Vector3(0, -0.29, 0))
		_add(data[2], _box(Vector3(0.105, 0.085, 0.25)), boots, Vector3(0, -0.035, 0.05))
	if L.get("chest_box", false):
		_add(chest, _box(Vector3(0.13, 0.1, 0.03)), _mat(Color(0.4, 0.41, 0.44), 0.35, 0.85), Vector3(0, 0.08, 0.122))
		var lights := [Color(1, 0.1, 0.1), Color(0.1, 1, 0.3), Color(0.2, 0.4, 1), Color(1, 0.1, 0.1), Color(1, 1, 1), Color(0.1, 1, 0.3)]
		for i in lights.size():
			var lm := StandardMaterial3D.new()
			lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lm.albedo_color = lights[i]
			_add(chest, _box(Vector3(0.016, 0.012, 0.01)), lm, Vector3(-0.035 + (i % 3) * 0.035, 0.1 - (0.03 if i > 2 else 0.0), 0.139))
		for s in [-1.0, 1.0]:
			_add(chest, _sph(0.088, true), over, Vector3(s * 0.2, 0.21, 0), Vector3(1.1, 0.75, 1.0))
	if L.has("cape"):
		_build_cape(L["cape"])
	_build_head(skin, hair)

func _build_cape(color: Color) -> void:
	var mat := _mat(color, 0.95, 0.0, true)
	var parent: Node3D = chest
	var pos := Vector3(0, 0.22, -0.11)
	var width := 0.4
	for i in range(3):
		var hinge := _joint(parent, pos)
		_add(hinge, _box(Vector3(width, 0.5, 0.02)), mat, Vector3(0, -0.25, 0))
		cape_hinges.append(hinge)
		parent = hinge
		pos = Vector3(0, -0.5, 0)
		width += 0.07

func _build_head(skin: StandardMaterial3D, hair: StandardMaterial3D) -> void:
	var L := look
	var helmet: String = L.get("helmet", "")
	var face: String = L.get("face", "")
	if face == "yoda":
		head.scale = Vector3.ONE * 1.45
	if helmet == "vader":
		var gloss := _mat(Color(0.02, 0.02, 0.025), 0.15, 0.8)
		var mask := _mat(Color(0.1, 0.1, 0.11), 0.3, 0.85)
		_add(head, _sph(0.135, true), gloss, Vector3(0, 0.015, -0.004), Vector3(1, 1.05, 1.08))
		_add(head, _cyl(0.135, 0.19, 0.17, true), _mat(Color(0.02, 0.02, 0.025), 0.15, 0.8, true), Vector3(0, -0.07, -0.01))
		_add(head, _sph(0.12), mask, Vector3(0, -0.01, 0.025), Vector3(0.95, 1.0, 0.9))
		var lens := _mat(Color(0.08, 0.01, 0.01), 0.05, 0.3)
		for s in [-1.0, 1.0]:
			_add(head, _sph(0.031), lens, Vector3(s * 0.045, 0.0, 0.115), Vector3(1.15, 0.8, 0.55))
		_add(head, _box(Vector3(0.14, 0.02, 0.03)), gloss, Vector3(0, 0.036, 0.118))
		var grill := _add(head, _cyl(0.0, 0.05, 0.09), _mat(Color(0.25, 0.25, 0.27), 0.35, 0.9), Vector3(0, -0.088, 0.105), Vector3(1, 1, 0.55))
		(grill.mesh as CylinderMesh).radial_segments = 3
		grill.rotation.x = PI
		return
	if helmet == "kylo":
		var black := _mat(Color(0.03, 0.03, 0.03), 0.25, 0.6)
		var silver := _mat(Color(0.75, 0.75, 0.78), 0.25, 0.95)
		_add(head, _sph(0.13), black, Vector3(0, 0.005, 0), Vector3(1, 1.08, 1.1))
		_add(head, _box(Vector3(0.17, 0.012, 0.012)), silver, Vector3(0, 0.02, 0.138))
		_add(head, _box(Vector3(0.012, 0.09, 0.012)), silver, Vector3(0, -0.028, 0.141))
		_add(head, _box(Vector3(0.05, 0.03, 0.012)), _mat(Color(0.12, 0.12, 0.13), 0.4, 0.8), Vector3(0, -0.085, 0.128))
		_add(neck, _cyl(0.075, 0.12, 0.12), _mat(Color(0.04, 0.04, 0.04), 0.9), Vector3(0, -0.02, 0))
		return
	# Cabeza descubierta
	var head_scale := Vector3(0.92, 1.06, 1.0)
	if face == "yoda":
		head_scale = Vector3(1.12, 0.92, 1.02)
	_add(head, _sph(0.11), skin, Vector3.ZERO, head_scale)
	var eye_color := Color(0.06, 0.08, 0.12)
	var white_color := Color(0.95, 0.93, 0.9)
	if face == "maul":
		eye_color = Color(0.1, 0.05, 0.0)
		white_color = Color(1.0, 0.75, 0.05)
	elif face == "yoda":
		white_color = Color(0.55, 0.45, 0.2)
	var eye := _mat(eye_color, 0.2)
	var white := _mat(white_color, 0.4)
	var brow := hair if L.has("hair") else _mat((L["skin"] as Color).darkened(0.35))
	for s in [-1.0, 1.0]:
		var eye_size := 1.6 if face == "yoda" else 1.0
		_add(head, _sph(0.016 * eye_size), white, Vector3(s * 0.037 * (1.15 if face == "yoda" else 1.0), 0.012, 0.094), Vector3(1.2, 0.7 if face != "yoda" else 0.9, 0.6))
		_add(head, _sph(0.009 * eye_size), eye, Vector3(s * 0.037 * (1.15 if face == "yoda" else 1.0), 0.012, 0.102))
		_add(head, _box(Vector3(0.034, 0.008, 0.01)), brow, Vector3(s * 0.038, 0.036, 0.101))
	_add(head, _box(Vector3(0.012, 0.03, 0.02)), skin, Vector3(0, -0.012, 0.108))
	_add(head, _box(Vector3(0.032, 0.006, 0.01)), _mat((L["skin"] as Color).darkened(0.45)), Vector3(0, -0.048, 0.1))
	if face == "maul":
		# Tatuajes negros alrededor de ojos, frente y barbilla; cuernos en la coronilla.
		var ink := _mat(Color(0.02, 0.02, 0.02), 0.5)
		for s in [-1.0, 1.0]:
			_add(head, _sph(0.03), ink, Vector3(s * 0.04, 0.014, 0.085), Vector3(1.3, 0.8, 0.5))
			_add(head, _box(Vector3(0.012, 0.07, 0.01)), ink, Vector3(s * 0.025, 0.07, 0.092))
			var cheek := _add(head, _box(Vector3(0.012, 0.05, 0.01)), ink, Vector3(s * 0.06, -0.035, 0.085))
			cheek.rotation.z = s * 0.4
		_add(head, _sph(0.04), ink, Vector3(0, -0.07, 0.07), Vector3(1.0, 0.7, 0.6))
	if L.get("horns", false):
		var horn := _mat(Color(0.9, 0.86, 0.76), 0.5)
		for hp in [[0.0, 0.2], [0.6, 0.45], [-0.6, 0.45], [1.2, 0.6], [-1.2, 0.6], [1.9, 0.62], [-1.9, 0.62], [2.6, 0.55], [-2.6, 0.55], [0.0, 0.6]]:
			var n := Vector3(sin(hp[1]) * sin(hp[0]), cos(hp[1]), sin(hp[1]) * cos(hp[0]))
			var h := _add(head, _cyl(0.0, 0.011, 0.038), horn, n * Vector3(0.1, 0.115, 0.1) + n * 0.019)
			h.quaternion = _arc(Vector3.UP, n)
	if face == "yoda":
		# Orejas grandes inclinadas hacia arriba y atras
		for s in [-1.0, 1.0]:
			var ear := _add(head, _sph(0.05), skin, Vector3(s * 0.15, 0.025, -0.01), Vector3(2.2, 0.55, 0.25))
			ear.rotation = Vector3(0, s * 0.3, s * 0.35)
	match String(L.get("hair_style", "none")):
		"short", "long", "buns":
			var cap := _add(head, _sph(0.118, true), hair, Vector3(0, 0.008, -0.004), Vector3(0.95, 1.05, 1.03))
			cap.rotation.x = -0.45
			if L["hair_style"] == "long":
				_add(head, _box(Vector3(0.2, 0.17, 0.07)), hair, Vector3(0, -0.04, -0.085))
				for s in [-1.0, 1.0]:
					var lock := _add(head, _box(Vector3(0.035, 0.16, 0.09)), hair, Vector3(s * 0.1, -0.03, -0.02))
					lock.rotation.z = s * 0.12
			elif L["hair_style"] == "buns":
				for k in range(3):
					_add(head, _sph(0.035), hair, Vector3(0, 0.06 - k * 0.055, -0.115))
		"wisps":
			for k in range(6):
				var a := -1.2 + k * 0.48
				_add(head, _sph(0.02), hair, Vector3(sin(a) * 0.1, -0.01, cos(a) * -0.08), Vector3(1.5, 0.6, 1.0))
	if L.get("beard", false):
		_add(head, _sph(0.085), hair, Vector3(0, -0.068, 0.035), Vector3(1.05, 0.95 if look_name != "dooku" else 0.8, 0.78))
		_add(head, _box(Vector3(0.06, 0.012, 0.014)), hair, Vector3(0, -0.034, 0.104))

func _blade_glow_material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(saber_color.r, saber_color.g, saber_color.b, alpha)
	return m

# Crea una hoja (nucleo blanco + resplandor + halo) que sale del punto base hacia "sign".
func _make_blade(base_y: float, dir_sign: float, length: float, core: Material) -> Dictionary:
	var node := _joint(saber, Vector3(0, base_y, 0))
	if dir_sign < 0.0:
		node.rotation.z = PI
	var inner := _joint(node)
	_add(inner, _cyl(0.011, 0.011, 1.0), core, Vector3(0, 0.5, 0))
	_add(inner, _cyl(0.028, 0.028, 1.0), blade_glow_mat, Vector3(0, 0.5, 0))
	_add(inner, _cyl(0.065, 0.065, 1.0), _blade_glow_material(0.16), Vector3(0, 0.5, 0))
	var tip := _joint(node, Vector3(0, length, 0))
	_add(tip, _sph(0.011), core)
	_add(tip, _sph(0.028), blade_glow_mat)
	return {"node": node, "inner": inner, "tip": tip, "sign": dir_sign, "base": base_y, "len": length}

func _build_saber() -> void:
	saber = _joint(body)
	var silver := _mat(Color(0.78, 0.8, 0.84), 0.3, 0.9)
	var grip := _mat(Color(0.06, 0.06, 0.06), 0.5, 0.4)
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = Color(1, 1, 1)
	blade_glow_mat = _blade_glow_material(0.75)
	if look.get("double", false):
		# Empunadura larga de doble hoja
		hilt_half = 0.22
		_add(saber, _cyl(0.019, 0.019, 0.44), grip, Vector3.ZERO)
		for s in [-1.0, 1.0]:
			_add(saber, _cyl(0.021, 0.021, 0.06), silver, Vector3(0, s * 0.19, 0))
			_add(saber, _cyl(0.024, 0.018, 0.05) if s > 0 else _cyl(0.018, 0.024, 0.05), silver, Vector3(0, s * 0.235, 0))
		blades.append(_make_blade(0.26, 1.0, BLADE_LEN, core))
		blades.append(_make_blade(-0.26, -1.0, BLADE_LEN, core))
	else:
		_add(saber, _cyl(0.019, 0.019, 0.06), silver, Vector3(0, -0.15, 0))
		_add(saber, _cyl(0.018, 0.018, 0.16), grip, Vector3(0, -0.04, 0))
		_add(saber, _cyl(0.019, 0.019, 0.04), silver, Vector3(0, 0.06, 0))
		_add(saber, _cyl(0.024, 0.018, 0.05), silver, Vector3(0, 0.105, 0))
		if look.get("curved", false):
			# Empunadura curva de Dooku
			var crook := _add(saber, _cyl(0.018, 0.02, 0.1), silver, Vector3(0.016, -0.215, 0))
			crook.rotation.z = 0.4
		blades.append(_make_blade(BLADE_BASE, 1.0, BLADE_LEN, core))
		if look.get("crossguard", false):
			# Gavilanes laterales de la espada de Kylo Ren
			_add(saber, _box(Vector3(0.12, 0.03, 0.03)), grip, Vector3(0, 0.11, 0))
			for s in [-1.0, 1.0]:
				var q := _joint(saber, Vector3(s * 0.06, 0.11, 0))
				q.rotation.z = -s * PI * 0.5
				var qi := _joint(q)
				qi.scale = Vector3(1, 0.13, 1)
				_add(qi, _cyl(0.008, 0.008, 1.0), core, Vector3(0, 0.5, 0))
				_add(qi, _cyl(0.022, 0.022, 1.0), blade_glow_mat, Vector3(0, 0.5, 0))
	blade = blades[0]["node"]
	blade_tip = blades[0]["tip"]
	blade_light = OmniLight3D.new()
	blade_light.light_color = saber_color
	blade_light.omni_range = 2.6
	blade_light.light_energy = 0.6
	blade_light.position = Vector3(0, 0.0 if blades.size() > 1 else 0.55, 0)
	saber.add_child(blade_light)

func _build_trail() -> void:
	trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.mesh = trail_mesh
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_mat = StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_mat.vertex_color_use_as_albedo = true
	add_child(trail)

# ---------------------------------------------------------------- control
func play(name_: String, hit_time: float = -1.0, hold: bool = false) -> void:
	if not CLIPS.has(name_):
		return
	var def: Dictionary = CLIPS[name_]
	var keys: Array = [[0.0, "io", pose.duplicate()]]
	for k in def["keys"]:
		var p: Dictionary = guard_pose.duplicate() if typeof(k[2]) == TYPE_STRING else (k[2] as Dictionary).duplicate()
		keys.append([k[0], k[1], p])
	clip = {"keys": keys, "dur": keys[keys.size() - 1][0], "side": def.get("side", ""), "hit": def.get("hit", -1.0)}
	clip_name = name_
	clip_t = 0.0
	hold_clip = hold
	clip_speed = 1.0
	if hit_time > 0.0 and float(def.get("hit", -1.0)) > 0.0:
		clip_speed = clampf(float(def["hit"]) / hit_time, 0.35, 2.5)

func is_playing(name_: String) -> bool:
	return not clip.is_empty() and clip_name == name_

# Guardia que el DEFENSOR debe adoptar ante el ataque que este rig esta ejecutando.
func incoming_block_side() -> String:
	if clip.is_empty() or String(clip["side"]) == "":
		return "idle"
	return SIDE_TO_BLOCK.get(String(clip["side"]), "idle")

func set_ignite(on: bool) -> void:
	var target := 1.0 if on else 0.0
	if target != ignite_target and is_instance_valid(sfx):
		sfx.call("play", "ignite" if on else "retract", -8.0)
	ignite_target = target

func push_back_blade() -> void:
	kick = Vector3(randf_range(-0.03, 0.03), 0.02, -0.08)

func blade_segment() -> Array:
	return blade_segments()[0]

func blade_segments() -> Array:
	var out: Array = []
	var e := ignite * (2.0 - ignite)
	for b in blades:
		var base: float = b["base"]
		var dir_sign: float = b["sign"]
		var len_now: float = float(b["len"]) * maxf(e, 0.001)
		out.append([saber.to_global(Vector3(0, base, 0)), saber.to_global(Vector3(0, base + dir_sign * len_now, 0))])
	return out

# Correccion de contacto: desplaza la empunadura para que las hojas se toquen de verdad.
func apply_contact(offset_world: Vector3) -> void:
	corr_world = offset_world.limit_length(0.35)

func _eval_clip() -> void:
	var keys: Array = clip["keys"]
	var n := keys.size()
	if clip_t >= float(keys[n - 1][0]):
		pose = (keys[n - 1][2] as Dictionary).duplicate()
		return
	var i := 0
	while i < n - 2 and clip_t >= float(keys[i + 1][0]):
		i += 1
	var k0: Dictionary = keys[maxi(0, i - 1)][2]
	var k1: Dictionary = keys[i][2]
	var k2: Dictionary = keys[i + 1][2]
	var k3: Dictionary = keys[mini(n - 1, i + 2)][2]
	var span := maxf(0.0001, float(keys[i + 1][0]) - float(keys[i][0]))
	var u := _ease(String(keys[i + 1][1]), clampf((clip_t - float(keys[i][0])) / span, 0.0, 1.0))
	for c in ["h", "d", "lh", "tw", "ln", "cr", "oh", "st"]:
		pose[c] = _crm(k0[c], k1[c], k2[c], k3[c], u)
	var d: Vector3 = pose["d"]
	pose["d"] = d.normalized() if d.length_squared() > 0.0001 else k2["d"]
	pose["oh"] = clampf(pose["oh"], 0.0, 1.0)

func _damp_pose(target: Dictionary, lam: float, delta: float) -> void:
	var k := 1.0 - exp(-lam * delta)
	pose["h"] = (pose["h"] as Vector3).lerp(target["h"], k)
	var d: Vector3 = (pose["d"] as Vector3).lerp(target["d"], k)
	if d.length_squared() > 0.0001:
		pose["d"] = d.normalized()
	pose["lh"] = (pose["lh"] as Vector3).lerp(target["lh"], k)
	for c in ["tw", "ln", "cr", "oh", "st"]:
		pose[c] = lerpf(pose[c], target[c], k)

# Llamado cada fotograma por el luchador.
func tick(delta: float, velocity_world: Vector3, guarding: bool, block_side: String, dead: bool) -> void:
	clock += delta
	if not clip.is_empty():
		clip_t += delta * clip_speed
		_eval_clip()
		if clip_t >= float(clip["dur"]) and not hold_clip:
			clip = {}
			clip_name = ""
	elif not dead:
		var target: Dictionary
		if guarding:
			target = BLOCKS.get(block_side, BLOCKS["idle"])
			_damp_pose(target, 26.0, delta)
		else:
			target = guard_pose.duplicate()
			var t := clock + seed_offset
			target["h"] = (target["h"] as Vector3) + Vector3(sin(t * 1.3) * 0.012, sin(t * 2.1) * 0.012, 0.0)
			var d: Vector3 = target["d"]
			target["d"] = (d + Vector3(sin(t * 0.9) * 0.05, 0, 0)).normalized()
			_damp_pose(target, 10.0, delta)
	corr_world = corr_world * exp(-5.0 * delta)
	kick = kick * exp(-10.0 * delta)
	head_dip = lerpf(head_dip, 0.5 if dead else 0.0, 1.0 - exp(-3.0 * delta))
	var step := delta / 0.26
	ignite = minf(ignite_target, ignite + step) if ignite_target > ignite else maxf(ignite_target, ignite - step * 0.85)
	_apply(delta, velocity_world, dead)
	_update_blade(delta)

func _apply(delta: float, velocity_world: Vector3, dead: bool) -> void:
	var cr: float = pose["cr"]
	var tw: float = pose["tw"]
	var ln: float = pose["ln"]
	var body_y := 0.95 - cr + bob
	# El peso del cuerpo acompana al paso: adelante al golpear, atras al recibir.
	body.position = Vector3(0, body_y, 0.07 * float(pose.get("st", 0.0)))
	pelvis.rotation = Vector3(0, tw * 0.3, 0)
	spine.rotation = Vector3(ln * 0.45, tw * 0.3, 0)
	chest.rotation = Vector3(ln * 0.55, tw * 0.4, 0)
	neck.rotation = Vector3(-ln * 0.75 + head_dip, -tw * 0.9, 0)
	var corr_local: Vector3 = global_transform.basis.inverse() * corr_world
	var h: Vector3 = pose["h"]
	saber.position = h + corr_local + kick - Vector3(0, body_y, body.position.z)
	saber.quaternion = _arc(Vector3.UP, pose["d"])
	_update_feet(delta, velocity_world, dead, body_y)
	# Manos sobre la empunadura (la izquierda se suelta si no llega o si la pose lo pide)
	var hand_r := saber.to_global(Vector3(0, grip_r, 0))
	var hand_l := saber.to_global(Vector3(0, grip_l, 0))
	var lh: Vector3 = pose["lh"]
	var free := body.to_global(lh - Vector3(0, body_y, body.position.z))
	var reach := (ARM_A + ARM_B) * global_transform.basis.get_scale().x
	var ratio := sh_l.global_position.distance_to(hand_l) / maxf(reach, 0.001)
	var want := maxf(pose["oh"], smoothstep(0.94, 1.06, ratio))
	one_hand_smooth = lerpf(one_hand_smooth, want, 1.0 - exp(-16.0 * delta))
	hand_l = hand_l.lerp(free, one_hand_smooth)
	_ik(chest, sh_r, el_r, ARM_A, ARM_B, hand_r, POLE_R)
	_ik(chest, sh_l, el_l, ARM_A, ARM_B, hand_l, POLE_L)
	_ik(pelvis, hp_r, kn_r, LEG_A, LEG_B, ft_r.global_position, POLE_KR)
	_ik(pelvis, hp_l, kn_l, LEG_A, LEG_B, ft_l.global_position, POLE_KL)
	if not cape_hinges.is_empty():
		var sp := velocity_world.length()
		cape_hinges[0].rotation.x = -ln + 0.1 + sp * 0.025 + sin(clock * 1.7) * 0.025
		cape_hinges[1].rotation.x = 0.06 + sp * 0.018 + sin(clock * 2.1 + 1.0) * 0.03
		cape_hinges[2].rotation.x = 0.05 + sp * 0.014 + sin(clock * 2.6 + 2.0) * 0.04

func _update_feet(delta: float, velocity_world: Vector3, dead: bool, _body_y: float) -> void:
	var v_local: Vector3 = global_transform.basis.inverse() * velocity_world
	v_local.y = 0.0
	var sp := v_local.length()
	if sp > 0.05:
		move_dir = v_local.normalized()
	gait += delta * sp * 6.4
	stride = lerpf(stride, minf(sp * 0.15, 0.26), 1.0 - exp(-10.0 * delta))
	var sn := sin(gait)
	var cs := cos(gait)
	var lift := minf(sp, 1.2) * 0.1
	var st_r := Vector3(-0.14, 0.08, -0.46) if dead else Vector3(-0.14, 0.08, -0.2)
	var st_l := Vector3(0.14, 0.08, 0.3) if dead else Vector3(0.13, 0.08, 0.21)
	var step: float = pose.get("st", 0.0)
	ft_r.position = st_r + move_dir * stride * sn + Vector3(0, maxf(0.0, cs) * lift, -0.06 * maxf(step, 0.0))
	ft_l.position = st_l - move_dir * stride * sn + Vector3(0, maxf(0.0, -cs) * lift, 0.3 * step)
	ft_r.rotation.y = -0.45
	ft_l.rotation.y = 0.05
	bob = -absf(sn) * 0.03 * minf(sp, 1.0)

func _ik(parent: Node3D, j1: Node3D, j2: Node3D, a: float, b: float, target: Vector3, pole: Vector3) -> void:
	var T := parent.to_local(target) - j1.position
	var d := maxf(T.length(), 0.0001)
	var t := T / d
	var dc := clampf(d, absf(a - b) + 0.001, a + b - 0.0001)
	var cos_a := clampf((a * a + dc * dc - b * b) / (2.0 * a * dc), -1.0, 1.0)
	var n := pole - t * pole.dot(t)
	if n.length_squared() < 0.000001:
		n = Vector3(0, 0, 1) - t * t.z
	n = n.normalized()
	var u := t * cos_a + n * sin(acos(cos_a))
	j1.quaternion = _arc(Vector3.DOWN, u)
	var f := (t * dc - u * a).normalized()
	j2.quaternion = _arc(Vector3.DOWN, j1.quaternion.inverse() * f)

var _tip_prev: Vector3 = Vector3.ZERO
var _tip_speed: float = 0.0
var _root_prev: Vector3 = Vector3.ZERO

func _update_blade(delta: float) -> void:
	var e := ignite * (2.0 - ignite)
	var unstable: bool = look.get("unstable", false)
	for b in blades:
		var jitter := randf_range(0.97, 1.03) if unstable else 1.0
		(b["inner"] as Node3D).scale = Vector3(jitter, float(b["len"]) * maxf(e, 0.001), jitter)
		(b["node"] as Node3D).visible = e > 0.01
		(b["tip"] as Node3D).position = Vector3(0, float(b["len"]) * e, 0)
	blade_light.light_energy = 0.6 * e * (randf_range(0.6, 1.1) if unstable else randf_range(0.92, 1.0))
	blade_glow_mat.albedo_color.a = (randf_range(0.45, 0.95) if unstable else 0.75 * randf_range(0.9, 1.0))
	# Estela: velocidad de la punta relativa al cuerpo (caminar no la activa)
	var seg := blade_segment()
	var root_now := global_position
	if delta > 0.0:
		var rel: Vector3 = (seg[1] - _tip_prev) - (root_now - _root_prev)
		_tip_speed = lerpf(_tip_speed, rel.length() / delta, 1.0 - exp(-20.0 * delta))
	_tip_prev = seg[1]
	_root_prev = root_now
	var inten := clampf((_tip_speed - 3.0) / 8.0, 0.0, 1.0) * e
	# El zumbido sube de tono y volumen con la velocidad de la hoja; silbido en cada tajo.
	var swing_amount := clampf(_tip_speed / 14.0, 0.0, 1.0)
	if is_instance_valid(hum):
		hum.volume_db = linear_to_db(maxf(e * (0.35 + 0.65 * swing_amount), 0.0001)) - 12.0
		hum.pitch_scale = lerpf(hum.pitch_scale, (0.82 if look_name in ["vader", "kylo"] else 1.0) * (1.0 + 0.3 * swing_amount), 1.0 - exp(-12.0 * delta))
	swing_cooldown -= delta
	if _tip_speed > 7.0 and swing_cooldown <= 0.0 and e > 0.9 and is_instance_valid(sfx):
		swing_cooldown = 0.26
		sfx.call("play", "swing", -10.0 + 6.0 * swing_amount, randf_range(0.88, 1.12))
	trail_points.push_front([seg[0], seg[1], inten])
	if trail_points.size() > 12:
		trail_points.pop_back()
	trail_mesh.clear_surfaces()
	var any := false
	for p in trail_points:
		if p[2] > 0.02:
			any = true
	if not any or trail_points.size() < 2:
		return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, trail_mat)
	var n := trail_points.size()
	for i in range(n - 1):
		var a: Array = trail_points[i]
		var b: Array = trail_points[i + 1]
		var fa := pow(1.0 - float(i) / float(n - 1), 1.6) * float(a[2])
		var fb := pow(1.0 - float(i + 1) / float(n - 1), 1.6) * float(b[2])
		var ca_tip := Color(saber_color.r, saber_color.g, saber_color.b, fa * 0.8)
		var cb_tip := Color(saber_color.r, saber_color.g, saber_color.b, fb * 0.8)
		var ca_base := Color(saber_color.r, saber_color.g, saber_color.b, fa * 0.1)
		var cb_base := Color(saber_color.r, saber_color.g, saber_color.b, fb * 0.1)
		for v in [[a[0], ca_base], [a[1], ca_tip], [b[1], cb_tip], [a[0], ca_base], [b[1], cb_tip], [b[0], cb_base]]:
			trail_mesh.surface_set_color(v[1])
			trail_mesh.surface_add_vertex(v[0])
	trail_mesh.surface_end()
