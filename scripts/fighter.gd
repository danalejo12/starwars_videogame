extends CharacterBody3D

signal health_changed
signal defeated
signal resources_changed
signal action_message(message: String)

var is_player: bool = false
# Versus local: el jugador 2 es humano y usa acciones con prefijo "p2_".
var player_index: int = 1
var input_prefix: String = ""
const Characters = preload("res://scripts/characters.gd")
var speed_mult: float = 1.0
var power_mult: float = 1.0
var defense_mult: float = 1.0
var reach_mult: float = 1.0
var opponent: CharacterBody3D
var targets: Array[CharacterBody3D] = []
var unit_type: String = "jedi" # jedi, b1, b2
var shot_timer: float = 0.0
var fire_effect_time: float = 0.0
var player_character: String = "anakin"
var active: bool = false
var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var energy: float = 100.0
var guarding: bool = false
var dead: bool = false
var attack_cooldown: float = 0.0
var combo_window: float = 0.0
var combo: int = 0
var swing_duration: float = 0.0
var swing_total: float = 0.30
var enemy_attack_delay: float = 1.2
var force_cooldown: float = 0.0
var force_cast_time: float = 0.0 # Aviso antes del empuje del rival
var force_casting: bool = false
var dodge_cooldown: float = 0.0
var dodge_time: float = 0.0
var parry_time: float = 0.0
var stun_time: float = 0.0
var knockdown_time: float = 0.0
var knockdown_total: float = 2.15
var visual_root: Node3D
var imported_rig: Node3D
var rig_anim_player: AnimationPlayer
var rig_current_anim: String = ""
var left_arm_joint: Node3D
var right_arm_joint: Node3D
var left_leg_joint: Node3D
var right_leg_joint: Node3D
var head_joint: Node3D
var gait_clock: float = 0.0
var visual_animation_clock: float = 0.0
var knockback: Vector3 = Vector3.ZERO
var dodge_direction: Vector3 = Vector3.ZERO
var saber_pivot: Node3D
var blade_mesh: MeshInstance3D
var blade_light: OmniLight3D
var body_mesh: MeshInstance3D
var body_material: StandardMaterial3D
var body_base_color: Color
var hit_flash_time: float = 0.0
var wound_marks: Array = []
var clash_cooldown: float = 0.0
var current_attack_hit: bool = false
var strafe_sign: float = 1.0
var strafe_clock: float = 0.0
var accent_color: Color = Color(0.12, 0.6, 1.0)
# v0.7: Jedi procedimental con IK (sable agarrado con ambas manos y poses direccionales).
const JediRigScript = preload("res://scripts/jedi_rig.gd")
var rig: Node3D
# 0 Guardian: protege y contraataca; 1 Duelista: equilibrado; 2 Agresivo: presiona.
var style: int = 1
var attack_sequence: int = 0
var attack_pending: bool = false
var impact_timer: float = 0.0
var pending_damage: float = 0.0
var guard_commit: float = 0.0
var observed_attack: int = -1
var decision_cooldown: float = 0.0
# Solo afecta a la IA: el jugador mantiene los mismos controles y estadisticas.
var ai_difficulty: int = 3
# Reglas de supervivencia de IA: los golpes siguen siendo efectivos,
# pero el rival resiste mejor y debe ser superado tacticamente.
var ai_damage_resistance: float = 0.0
var ai_recovery_rate: float = 0.0
var ai_recovery_delay: float = 0.0
var ai_second_wind: bool = false
var ai_second_wind_used: bool = false

func difficulty_index() -> int:
	return clampi(ai_difficulty - 1, 0, 4)


func style_name() -> String:
	match style:
		0:
			return "GUARDIAN"
		1:
			return "DUELISTA"
		_:
			return "AGRESIVO"


const SPEED: float = 7.4
const RUN_SPEED: float = 12.2
const GRAVITY: float = 22.0
const JUMP_SPEED: float = 10.8
const ATTACK_RANGE: float = 2.9
const THREAT_TURN_SPEED: float = 18.0
# Aimbot (apuntado automatico). 0 = sin ayuda, 1 = apuntado total.
# El jugador lo usa al maximo (activable con T); la IA segun la dificultad.
const LOCK_RANGE: float = 14.0
const IDEAL_STRIKE_DISTANCE: float = 1.9
var aim_strength: float = 0.0
var lock_enabled: bool = true
var lock_target: CharacterBody3D

func _ready() -> void:
	name = ("Heroe" if player_index == 1 else "Jugador2") if is_player else "Rival"
	var first_side: bool = is_player and player_index == 1
	collision_layer = 2 if first_side else 4
	collision_mask = 1 | (4 if first_side else 2)
	accent_color = Color(0.16, 0.65, 1.0) if is_player else Color(1.0, 0.16, 0.12)
	if unit_type != "jedi":
		accent_color = Color(0.95, 0.37, 0.12)
	build_visuals()

func make_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.38
	node.material_override = mat
	parent.add_child(node)
	return node

# Figuras originales procedimentales con articulaciones que se mueven.
# No dependen de modelos comerciales ni archivos 3D externos.
func make_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, stretch: Vector3 = Vector3.ONE, metal: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.position = pos
	part.scale = stretch
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.42
	part.material_override = material
	parent.add_child(part)
	return part

func make_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.42
	part.material_override = material
	parent.add_child(part)
	return part

func add_arm(side: float, sleeve: Color, glove: Color) -> Node3D:
	var joint := Node3D.new()
	joint.position = Vector3(side * 0.49, 0.43, 0)
	visual_root.add_child(joint)
	make_sphere(joint, 0.16, Vector3.ZERO, sleeve)
	make_cylinder(joint, 0.14, 0.50, Vector3(0, -0.27, 0), sleeve)
	make_sphere(joint, 0.12, Vector3(0, -0.54, 0), glove)
	make_cylinder(joint, 0.12, 0.29, Vector3(0, -0.73, 0), glove)
	make_sphere(joint, 0.12, Vector3(0, -0.9, -0.02), glove)
	return joint

func add_leg(side: float, pants: Color, boot: Color) -> Node3D:
	var joint := Node3D.new()
	joint.position = Vector3(side * 0.23, -0.36, 0)
	visual_root.add_child(joint)
	make_cylinder(joint, 0.18, 0.52, Vector3(0, -0.25, 0), pants)
	make_sphere(joint, 0.16, Vector3(0, -0.51, 0), pants)
	make_cylinder(joint, 0.14, 0.42, Vector3(0, -0.73, 0), boot)
	make_box(joint, Vector3(0.3, 0.18, 0.42), Vector3(0, -0.96, -0.10), boot)
	return joint

func build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "PersonajeArticulado"
	add_child(visual_root)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.42
	col.shape = capsule
	add_child(col)
	var robot: bool = unit_type != "jedi"
	var heavy: bool = unit_type == "b2"
	var light_robot: bool = unit_type == "b1"
	var tunic: Color = Color(0.21, 0.27, 0.39) if is_player else Color(0.38, 0.15, 0.20)
	var cloth: Color = Color(0.13, 0.16, 0.25)
	var skin: Color = Color(0.83, 0.65, 0.51)
	var boots: Color = Color(0.11, 0.09, 0.09)
	var hair: Color = Color(0.21, 0.13, 0.09)
	if is_player and player_character == "obiwan":
		tunic = Color(0.58, 0.43, 0.29)
		cloth = Color(0.34, 0.24, 0.19)
		hair = Color(0.39, 0.24, 0.13)
	if robot:
		tunic = Color(0.29, 0.36, 0.44) if heavy else Color(0.71, 0.63, 0.46)
		cloth = tunic.darkened(0.30)
		skin = tunic.lightened(0.13)
		boots = cloth
	body_mesh = make_sphere(visual_root, 0.50 if heavy else 0.44, Vector3(0, 0.04, 0), tunic, Vector3(1.14 if heavy else 0.92, 1.30, 0.72), 0.72 if robot else 0.12)
	body_material = body_mesh.material_override as StandardMaterial3D
	body_base_color = tunic
	# Torso, cintura y panel frontal.
	make_box(visual_root, Vector3(0.66, 0.15, 0.44), Vector3(0, -0.4, 0), cloth)
	make_box(visual_root, Vector3(0.35, 0.12, 0.09), Vector3(0, -0.4, -0.25), Color(0.62, 0.56, 0.38), 0.65)
	if robot:
		make_box(visual_root, Vector3(0.45, 0.25, 0.09), Vector3(0, 0.25, -0.38), cloth, 0.6)
		for sx in [-1.0, 1.0]:
			make_sphere(visual_root, 0.09, Vector3(sx * 0.14, 0.27, -0.45), Color(0.93, 0.17, 0.07))
	else:
		make_box(visual_root, Vector3(0.11, 0.92, 0.085), Vector3(-0.13, 0.11, -0.34), cloth.lightened(0.24))
		make_box(visual_root, Vector3(0.11, 0.92, 0.085), Vector3(0.13, 0.11, -0.34), cloth.lightened(0.24))
		make_box(visual_root, Vector3(0.7, 0.30, 0.54), Vector3(0, -0.38, 0), tunic.darkened(0.13))
	# Cabeza articulada.
	head_joint = Node3D.new()
	head_joint.position = Vector3(0, 0.69, 0)
	visual_root.add_child(head_joint)
	if light_robot:
		make_cylinder(head_joint, 0.11, 0.35, Vector3(0, 0.11, 0), skin, 0.65)
		make_sphere(head_joint, 0.16, Vector3(0, 0.22, -0.04), skin, Vector3(0.8, 1.35, 0.9), 0.65)
		make_box(head_joint, Vector3(0.26, 0.1, 0.22), Vector3(0, 0.08, -0.15), cloth)
	elif heavy:
		make_sphere(head_joint, 0.26, Vector3(0, 0.11, 0), skin, Vector3(1.1, 0.85, 0.9), 0.75)
		make_box(head_joint, Vector3(0.43, 0.14, 0.14), Vector3(0, 0.08, -0.20), cloth)
	else:
		make_sphere(head_joint, 0.24, Vector3(0, 0.11, 0), skin, Vector3(0.88, 1.15, 0.86))
		make_sphere(head_joint, 0.25, Vector3(0, 0.27, 0.038), hair, Vector3(0.94, 0.43, 0.85))
		make_box(head_joint, Vector3(0.25, 0.08, 0.06), Vector3(0, -0.1, -0.19), hair)
	for sx in [-1.0, 1.0]:
		make_sphere(head_joint, 0.045, Vector3(sx * (0.10 if light_robot else 0.105), 0.13, -0.19), Color(0.98, 0.23, 0.11) if robot else Color(0.09, 0.17, 0.27))
	# Correas y paneles que diferencian tunicas de armazones roboticos.
	if not robot:
		make_box(visual_root, Vector3(0.82, 0.13, 0.54), Vector3(0, -0.49, 0), Color(0.18, 0.13, 0.11))
		make_box(visual_root, Vector3(0.11, 0.11, 0.08), Vector3(0, -0.49, -0.31), Color(0.66, 0.57, 0.37), 0.7)
		for sx in [-1.0, 1.0]:
			make_box(visual_root, Vector3(0.20, 0.66, 0.27), Vector3(sx * 0.26, -0.71, 0), tunic.darkened(0.18))
	else:
		for sx in [-1.0, 1.0]:
			make_box(visual_root, Vector3(0.14, 0.41, 0.14), Vector3(sx * 0.30, 0.18, -0.31), cloth, 0.85)
	left_arm_joint = add_arm(-1.0, tunic, cloth)
	right_arm_joint = add_arm(1.0, tunic, cloth)
	left_leg_joint = add_leg(-1.0, cloth, boots)
	right_leg_joint = add_leg(1.0, cloth, boots)
	# A diferencia del prototipo, la empunadura sigue ahora a la mano derecha.
	saber_pivot = Node3D.new()
	saber_pivot.position = Vector3(0, -0.95, -0.07)
	right_arm_joint.add_child(saber_pivot)
	make_cylinder(saber_pivot, 0.075, 0.36, Vector3(0, 0.0, 0), Color(0.14, 0.15, 0.18), 0.95)
	blade_mesh = make_cylinder(saber_pivot, 0.055, 2.05, Vector3(0, 1.18, 0), accent_color)
	var emissive := StandardMaterial3D.new()
	emissive.albedo_color = accent_color
	emissive.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emissive.emission_enabled = true
	emissive.emission = accent_color
	emissive.emission_energy_multiplier = 3.3
	blade_mesh.material_override = emissive
	blade_light = OmniLight3D.new()
	blade_light.position = Vector3(0, 1.25, 0)
	blade_light.light_color = accent_color
	blade_light.light_energy = 0.6
	blade_light.omni_range = 2.8
	saber_pivot.add_child(blade_light)
	if robot:
		saber_pivot.visible = false
		blade_mesh.visible = false
		blade_light.visible = false
		make_cylinder(right_arm_joint, 0.12, 0.48, Vector3(0, -0.94, -0.20), cloth, 0.8)
		make_sphere(right_arm_joint, 0.14, Vector3(0, -1.06, -0.42), Color(0.84, 0.19, 0.10), Vector3(0.7, 0.7, 1.1))

	if unit_type == "jedi":
		build_jedi_rig()
	else:
		# Droides: modelo GLB con esqueleto y 8 clips.
		attach_imported_rig()

func act(action: String) -> String:
	return input_prefix + action

# Estadisticas del personaje elegido (ver scripts/characters.gd).
func apply_stats() -> void:
	var data: Dictionary = Characters.get_data(player_character)
	speed_mult = data["speed"]
	power_mult = data["power"]
	defense_mult = data["defense"]
	reach_mult = data["reach"]

func build_jedi_rig() -> void:
	hide_procedural_meshes(visual_root)
	saber_pivot.visible = false
	if is_instance_valid(rig):
		rig.queue_free()
	rig = JediRigScript.new()
	rig.name = "Jedi_" + player_character
	# El rig mide ~1.77 y mira a +Z: se escala a la capsula (2 m) y se gira hacia -Z.
	rig.position = Vector3(0, -1.0, 0)
	rig.rotation.y = PI
	rig.scale = Vector3.ONE * 1.12 * float(Characters.get_data(player_character)["scale"])
	visual_root.add_child(rig)
	rig.call("setup", player_character)
	apply_stats()

# Cambia el heroe en caliente (el menu lo elige despues de crear al jugador).
func revive(spawn: Vector3, facing_yaw: float) -> void:
	dead = false
	active = true
	health = max_health
	stamina = 100.0
	energy = 100.0
	stun_time = 0.0
	knockdown_time = 0.0
	swing_duration = 0.0
	attack_pending = false
	guarding = false
	force_casting = false
	knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = spawn
	rotation.y = facing_yaw
	if is_instance_valid(visual_root):
		visual_root.rotation = Vector3.ZERO
		visual_root.position = Vector3.ZERO
	if is_instance_valid(rig):
		build_jedi_rig()
	health_changed.emit()
	resources_changed.emit()

func apply_character(character: String) -> void:
	player_character = character
	if unit_type == "jedi" and is_instance_valid(visual_root):
		build_jedi_rig()

func all_blades() -> Array:
	if is_instance_valid(rig):
		return rig.call("blade_segments")
	return [blade_points()]

func blade_points() -> Array:
	if is_instance_valid(rig):
		return rig.call("blade_segment")
	return [saber_pivot.to_global(Vector3(0.0, 0.28, 0.0)), saber_pivot.to_global(Vector3(0.0, 2.26, 0.0))]

func rig_play(clip_name: String, hit_time: float = -1.0, hold: bool = false) -> void:
	if is_instance_valid(rig):
		rig.call("play", clip_name, hit_time, hold)

func game_call(method: String, args: Array = []) -> void:
	var g := get_parent()
	if g != null and g.has_method(method):
		g.callv(method, args)

func _process(delta: float) -> void:
	if not is_instance_valid(rig):
		return
	var side := "idle"
	if is_instance_valid(opponent) and is_instance_valid(opponent.get("rig")):
		side = opponent.rig.call("incoming_block_side")
	rig.call("tick", delta, velocity, guarding, side, dead)

func hide_procedural_meshes(node: Node) -> void:
	# Preserve the weapon visuals: the skinned model replaces only the old primitive body.
	if node == saber_pivot:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		hide_procedural_meshes(child)

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result: AnimationPlayer = find_animation_player(child)
		if result != null:
			return result
	return null

func attach_imported_rig() -> void:
	var model_name: String = "anakin" if is_player and player_character == "anakin" else "obiwan"
	if unit_type == "b1" or unit_type == "b2":
		model_name = unit_type
	var path: String = "res://assets/characters/%s_rigged.glb" % model_name
	var resource: Resource = load(path)
	if not (resource is PackedScene):
		push_warning("Modelo 3D no disponible: " + path)
		return
	var scene: PackedScene = resource as PackedScene
	imported_rig = scene.instantiate() as Node3D
	if imported_rig == null:
		return
	hide_procedural_meshes(visual_root)
	visual_root.add_child(imported_rig)
	# Ajuste de escala: el GLB mide ~2.4-3.2 m y sus pies quedaban bajo el suelo.
	var meshes := imported_rig.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		var box: AABB = (meshes[0] as MeshInstance3D).get_aabb()
		var target_height: float = 2.25 if unit_type == "b2" else 1.9
		var k: float = target_height / maxf(box.size.y, 0.01)
		imported_rig.scale = Vector3.ONE * k
		imported_rig.position.y = -1.0 - box.position.y * k
	rig_anim_player = find_animation_player(imported_rig)
	# Godot may prefix imported names with the library name. Match by suffix.
	play_rig_animation("Idle")

func play_rig_animation(which: String) -> void:
	if rig_anim_player == null or not is_instance_valid(rig_anim_player):
		return
	if rig_current_anim == which:
		return
	var match_name: String = ""
	for anim_name in rig_anim_player.get_animation_list():
		if String(anim_name).get_slice("/", 1) == which or String(anim_name) == which or String(anim_name).ends_with("/" + which):
			match_name = String(anim_name)
			break
	if match_name.is_empty():
		return
	rig_current_anim = which
	rig_anim_player.play(match_name, 0.15)

func update_rig_animation(desired: Vector3) -> void:
	if dead:
		return
	var wanted: String = "Idle"
	if knockdown_time > 0.0 or stun_time > 0.0 or hit_flash_time > 0.0:
		wanted = "Hit"
	elif force_casting:
		wanted = "Push"
	elif swing_duration > 0.0:
		wanted = "Attack"
	elif guarding:
		wanted = "Block"
	elif not is_on_floor():
		wanted = "Jump"
	elif desired.length_squared() > 0.1:
		wanted = "Run" if is_player and Input.is_action_pressed(act("sprint")) else "Walk"
	play_rig_animation(wanted)

func animate_locomotion(delta: float, desired: Vector3) -> void:
	if not is_instance_valid(left_leg_joint):
		return
	visual_animation_clock += delta
	var movement: float = clampf(desired.length(), 0.0, 1.0)
	if stun_time > 0.0 or knockdown_time > 0.0:
		movement = 0.0
	gait_clock += delta * (12.0 if is_player and Input.is_action_pressed(act("sprint")) else 8.5) * movement
	var stride: float = sin(gait_clock) * movement
	left_leg_joint.rotation.x = lerpf(left_leg_joint.rotation.x, stride * 0.56, minf(1.0, delta * 12.0))
	right_leg_joint.rotation.x = lerpf(right_leg_joint.rotation.x, -stride * 0.56, minf(1.0, delta * 12.0))
	left_arm_joint.rotation.x = lerpf(left_arm_joint.rotation.x, -stride * 0.32 if swing_duration <= 0.0 else -0.45, minf(1.0, delta * 10.0))
	var weapon_raise: float = -0.12 if guarding else (-0.15 if swing_duration > 0.0 else -0.38)
	right_arm_joint.rotation.x = lerpf(right_arm_joint.rotation.x, weapon_raise, minf(1.0, delta * 12.0))
	var slash: float = sin(visual_animation_clock * 22.0) * 0.82 if swing_duration > 0.0 else 0.0
	right_arm_joint.rotation.z = lerpf(right_arm_joint.rotation.z, -0.53 if guarding else (slash - 0.07), minf(1.0, delta * 14.0))
	if is_instance_valid(visual_root) and knockdown_time <= 0.0:
		visual_root.rotation.z = lerpf(visual_root.rotation.z, 0.10 * stride, minf(1.0, delta * 7.0))
	if is_instance_valid(head_joint):
		head_joint.rotation.y = sin(visual_animation_clock * 1.4) * 0.03
	if knockdown_time <= 0.0:
		visual_root.position.y = lerpf(visual_root.position.y, 0.035 * sin(gait_clock * 2.0) * movement, minf(1.0, delta * 10.0))

func _physics_process(delta: float) -> void:
	if not active or dead:
		return
	if is_player and (not is_instance_valid(opponent) or opponent.dead):
		opponent = nearest_target()
	shot_timer = maxf(0.0, shot_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	force_cooldown = maxf(0.0, force_cooldown - delta)
	if force_casting:
		force_cast_time -= delta
		if force_cast_time <= 0.0:
			force_casting = false
			perform_force_push()
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	parry_time = maxf(0.0, parry_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	knockdown_time = maxf(0.0, knockdown_time - delta)
	swing_duration = maxf(0.0, swing_duration - delta)
	decision_cooldown = maxf(0.0, decision_cooldown - delta)
	hit_flash_time = maxf(0.0, hit_flash_time - delta)
	clash_cooldown = maxf(0.0, clash_cooldown - delta)
	if is_instance_valid(body_material):
		body_material.albedo_color = Color(1.0, 0.22, 0.16) if hit_flash_time > 0.0 else body_base_color
		body_material.emission_enabled = hit_flash_time > 0.0
		body_material.emission = Color(1.0, 0.06, 0.04)
		body_material.emission_energy_multiplier = 3.0
	ai_recovery_delay = maxf(0.0, ai_recovery_delay - delta)
	guard_commit = maxf(0.0, guard_commit - delta)
	if attack_pending:
		impact_timer -= delta
		if impact_timer <= 0.0:
			attack_pending = false
			resolve_attack()
	knockback = knockback.move_toward(Vector3.ZERO, (9.0 if knockdown_time > 0.0 else 18.0) * delta)
	# Todo el personaje cae lateralmente y se incorpora al acabar el derribo.
	var fall_ratio: float = minf(1.0, knockdown_time / 0.35) if knockdown_time > 0.0 else 0.0
	var fall_blend: float = minf(1.0, delta * (11.0 if knockdown_time > 0.0 else 5.0))
	visual_root.rotation.z = lerpf(visual_root.rotation.z, -1.45 * fall_ratio, fall_blend)
	visual_root.position.y = lerpf(visual_root.position.y, -0.55 * fall_ratio, fall_blend)
	var old_stamina := stamina
	var old_energy := energy
	if not guarding:
		stamina = minf(100.0, stamina + 21.0 * delta * (1.0 if is_player else [0.77, 0.9, 1.0, 1.17, 1.30][difficulty_index()]))
	energy = minf(100.0, energy + 6.0 * delta)
	var desired := Vector3.ZERO
	if stun_time <= 0.0 and knockdown_time <= 0.0 and not force_casting:
		if is_player:
			desired = Vector3(Input.get_axis(act("move_left"), act("move_right")), 0.0, Input.get_axis(act("move_forward"), act("move_back"))).normalized()
			if Input.is_action_just_pressed(act("block")) and stamina >= 8.0 and swing_duration <= 0.0:
				parry_time = 0.24
			guarding = Input.is_action_pressed(act("block")) and swing_duration <= 0.0 and stamina > 2.0
			if Input.is_action_just_pressed(act("style_guardian")):
				set_style(0)
			elif Input.is_action_just_pressed(act("style_duelist")):
				set_style(1)
			elif Input.is_action_just_pressed(act("style_aggressive")):
				set_style(2)
			if Input.is_action_just_pressed(act("attack")):
				attack()
			if Input.is_action_just_pressed(act("force_push")):
				force_push()
			if Input.is_action_just_pressed(act("dodge")):
				dodge(desired)
			if Input.is_action_just_pressed(act("jump")) and is_on_floor():
				velocity.y = JUMP_SPEED
				# Impulso horizontal corto para cubrir mas terreno durante el salto.
				if desired.length_squared() > 0.01:
					knockback += desired.normalized() * 2.4
		else:
			desired = droid_behavior(delta) if unit_type != "jedi" else enemy_behavior(delta)
	else:
		guarding = false
	if guarding:
		stamina = maxf(0.0, stamina - (5.0 if style == 0 else 8.0) * delta)
		if stamina < 1.0:
			guarding = false
			stun_time = maxf(stun_time, 0.45)
			guard_commit = 0.0
			action_message.emit("GUARDIA ROTA")
	var speed: float = (RUN_SPEED if is_player and Input.is_action_pressed(act("sprint")) else SPEED) * speed_mult
	if guarding:
		speed *= 0.44
	if dodge_time > 0.0:
		desired = dodge_direction
		speed = 15.0
	velocity.x = desired.x * speed + knockback.x
	velocity.z = desired.z * speed + knockback.z
	velocity.y -= GRAVITY * delta
	move_and_slide()
	# Movimiento libre en los 360 grados: el heroe mira hacia donde se mueve,
	# salvo cuando alguien le ataca: entonces se encara al atacante (ver incoming_threat).
	var can_turn: bool = swing_duration <= 0.0 and stun_time <= 0.0 and knockdown_time <= 0.0 and dodge_time <= 0.0
	var threat: CharacterBody3D = incoming_threat() if is_player else null
	if is_instance_valid(threat) and knockdown_time <= 0.0 and dodge_time <= 0.0:
		# Giro rapido: llega de frente antes del impacto y sigue moviendose de lado.
		face_towards(threat.global_position, THREAT_TURN_SPEED * delta)
	elif is_player and lock_enabled and knockdown_time <= 0.0 and dodge_time <= 0.0 and is_instance_valid(aim_target()):
		# Objetivo fijado: siempre de frente, moviendose en circulo alrededor del rival.
		face_towards(aim_target().global_position, 14.0 * delta)
	elif can_turn:
		if is_player and desired.length_squared() > 0.015:
			rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, 10.0 * delta))
		elif not is_player and is_instance_valid(opponent):
			var to_enemy: Vector3 = opponent.global_position - global_position
			to_enemy.y = 0.0
			if to_enemy.length_squared() > 0.01:
				# La IA debe girar fisicamente, no puede bloquear instantaneamente
				# golpes que entran por detras o por el costado.
				rotation.y = lerp_angle(rotation.y, atan2(-to_enemy.x, -to_enemy.z), minf(1.0, (4.2 + float(difficulty_index()) * 0.65) * (1.0 + aim_strength) * delta))
	if not is_instance_valid(rig):
		animate_locomotion(delta, desired)
		update_rig_animation(desired)
	# La hoja apunta al frente y barre de izquierda a derecha en cada ataque.
	var target_yaw: float = 0.0
	var target_pitch: float = -1.02
	var target_roll: float = -0.08
	if guarding:
		target_pitch = -0.42
		target_yaw = -0.32
	elif swing_duration > 0.0:
		var phase: float = clampf(1.0 - swing_duration / swing_total, 0.0, 1.0)
		var sweep: float = lerpf(-1.13, 1.13, phase)
		target_yaw = sweep if combo % 2 == 1 else -sweep
		target_pitch = -1.32
		target_roll = -0.12
	# Sin interpolacion en la hoja durante ataques: la deteccion de contacto
	# coincide con la postura visual de la espada.
	if swing_duration > 0.0:
		saber_pivot.rotation = Vector3(target_pitch, target_yaw, target_roll)
	else:
		saber_pivot.rotation.x = lerpf(saber_pivot.rotation.x, target_pitch, minf(1.0, delta * 12.0))
		saber_pivot.rotation.y = lerpf(saber_pivot.rotation.y, target_yaw, minf(1.0, delta * 12.0))
		saber_pivot.rotation.z = lerpf(saber_pivot.rotation.z, target_roll, minf(1.0, delta * 12.0))
	if absf(old_stamina - stamina) > 0.005 or absf(old_energy - energy) > 0.005:
		resources_changed.emit()

func set_style(new_style: int) -> void:
	style = new_style
	action_message.emit("ESTILO: " + style_name())

func enemy_behavior(delta: float) -> Vector3:
	if not is_instance_valid(opponent) or opponent.dead:
		guarding = false
		return Vector3.ZERO
	var offset: Vector3 = opponent.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	enemy_attack_delay -= delta
	# Evaluar un ataque una unica vez, antes de que conecte.
	# Un Guardian se defiende a menudo, mientras el Agresivo arriesga mas.
	if opponent.attack_pending and opponent.attack_sequence != observed_attack:
		observed_attack = opponent.attack_sequence
		if distance < 3.6 and stamina > 15.0 and swing_duration <= 0.0:
			var block_probability: float = [0.91, 0.75, 0.52][style] * [0.48, 0.78, 1.05, 1.19, 1.34][difficulty_index()]
			block_probability = minf(0.90, block_probability)
			if randf() < block_probability:
				guard_commit = 0.42
				guarding = true
				if randf() < (0.23 if style == 0 else 0.10) * [0.1, 0.45, 1.0, 1.5, 1.9][difficulty_index()]:
					parry_time = 0.20
				action_message.emit("RIVAL: DEFENSA")
	# La IA intenta usar la Fuerza de forma ocasional, a una distancia razonable.
	# Un aviso previo permite al jugador pulsar K para bloquearlo.
	if force_cooldown <= 0.0 and energy >= 35.0 and distance >= 2.7 and distance <= 6.2 and not guarding and guard_commit <= 0.0 and swing_duration <= 0.0 and stun_time <= 0.0 and knockdown_time <= 0.0:
		var use_force_chance: float = [0.0010, 0.0020, 0.0035, 0.0055, 0.0080][difficulty_index()] * delta * 60.0
		if randf() < use_force_chance:
			force_push()
			return Vector3.ZERO
	# La IA no puede atacar mientras bloquea: al terminar reacciona.
	if guard_commit > 0.0 and stamina > 1.0 and swing_duration <= 0.0:
		guarding = true
	else:
		guarding = false
	if distance < ATTACK_RANGE and absf(opponent.global_position.y - global_position.y) < 1.8 and enemy_attack_delay <= 0.0 and not guarding and swing_duration <= 0.0:
		attack()
		var tempo: float = [1.65, 1.28, 1.0, 0.79, 0.62][difficulty_index()]
		match style:
			0: enemy_attack_delay = randf_range(1.05, 1.55) * tempo
			1: enemy_attack_delay = randf_range(0.75, 1.15) * tempo
			2: enemy_attack_delay = randf_range(0.48, 0.85) * tempo
	var preferred_range: float = 2.35 if style != 0 else 2.65
	if distance > preferred_range and not guarding:
		return offset.normalized()
	# Rodear al enemigo para generar golpes laterales y, a veces, por la espalda.
	# La maniobra se interrumpe al atacar para mantener una direccion creible.
	strafe_clock -= delta
	if strafe_clock <= 0.0:
		strafe_clock = randf_range(1.1, 2.5)
		strafe_sign = -1.0 if randf() < 0.5 else 1.0
	if distance > 1.25 and distance < 3.8 and not guarding and swing_duration <= 0.0:
		var sideways: Vector3 = Vector3(-offset.z, 0.0, offset.x).normalized() * strafe_sign
		return (sideways * 0.68 + offset.normalized() * (0.22 if distance > 2.0 else -0.20)).normalized()
	# Guardian busca espacio para defenderse cuando le presionan.
	if style == 0 and distance < 1.6 and guard_commit <= 0.0:
		return -offset.normalized()
	return Vector3.ZERO

func dodge(direction: Vector3) -> void:
	if dodge_cooldown > 0.0 or stamina < 25.0 or guarding or knockdown_time > 0.0:
		return
	stamina -= 25.0
	dodge_cooldown = 0.8
	dodge_time = 0.30
	if direction.length_squared() < 0.01:
		dodge_direction = global_transform.basis.z
	else:
		dodge_direction = direction
	action_message.emit("ESQUIVA")
	resources_changed.emit()

func attack() -> void:
	if attack_cooldown > 0.0 or guarding or stamina < 9.0 or stun_time > 0.0 or knockdown_time > 0.0:
		return
	var cost: float = 8.0 if style == 1 else (10.0 if style == 0 else 12.0)
	if stamina < cost:
		return
	stamina -= cost
	aim_attack()
	combo = (combo % 3) + 1 if combo_window > 0.0 else 1
	combo_window = 1.05
	var duration_modifier: float = 1.13 if style == 0 else (1.0 if style == 1 else 0.82)
	attack_cooldown = (0.29 if combo < 3 else 0.54) * duration_modifier
	swing_total = (0.32 if combo < 3 else 0.45) * duration_modifier
	swing_duration = swing_total
	attack_sequence += 1
	current_attack_hit = false
	attack_pending = true
	# Da tiempo para reaccionar: impacto NO instantaneo.
	impact_timer = (0.21 if combo < 3 else 0.30) * duration_modifier * (1.0 if is_player else [1.35, 1.16, 1.0, 0.88, 0.78][difficulty_index()])
	pending_damage = (12.0 if combo < 3 else 22.0) * (0.9 if style == 0 else (1.0 if style == 1 else 1.12)) * power_mult
	if is_instance_valid(rig):
		var kind: String = ["slashR", "slashL", "overhead"][combo - 1]
		if combo == 1 and randf() < 0.35:
			kind = "rising" if randf() < 0.5 else "thrust"
		rig_play(kind, impact_timer)
		# Paso adelante natural al golpear.
		knockback += -global_transform.basis.z * 3.2
	if not is_player:
		pending_damage *= [0.56, 0.78, 1.0, 1.20, 1.38][difficulty_index()]
	resources_changed.emit()
	if is_player:
		action_message.emit("COMBO %d - %s" % [combo, style_name()])

func distance_point_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + ab * t)

func resolve_attack() -> void:
	if is_player:
		var locked: CharacterBody3D = aim_target() if lock_enabled else null
		opponent = locked if is_instance_valid(locked) else nearest_target(true)
	if not active or dead or stun_time > 0.0 or knockdown_time > 0.0 or current_attack_hit:
		return
	if not is_instance_valid(opponent) or opponent.dead:
		opponent = nearest_target()
	if not is_instance_valid(opponent) or opponent.dead:
		return
	var towards: Vector3 = opponent.global_position - global_position
	towards.y = 0.0
	var distance: float = towards.length()
	if absf(opponent.global_position.y - global_position.y) > 1.8:
		return
	if absf(opponent.global_position.x) > 12.5 or absf(opponent.global_position.z) > 12.5:
		return
	if distance < 0.01 or distance > ATTACK_RANGE:
		return
	# No mas dano desde atras ni con la espada apuntando a otro lado.
	var facing: Vector3 = -global_transform.basis.z
	if aim_active():
		face_towards(opponent.global_position, aim_strength)
		facing = -global_transform.basis.z
	if facing.dot(towards.normalized()) < 0.38:
		return
	# La colision compara el segmento visible de la hoja con el torso.
	var nearest_cut: float = INF
	var torso: Vector3 = opponent.global_position + Vector3(0.0, 0.05, 0.0)
	var chest: Vector3 = torso + Vector3(0.0, 0.48, 0.0)
	for seg in all_blades():
		nearest_cut = minf(nearest_cut, minf(distance_point_to_segment(torso, seg[0], seg[1]), distance_point_to_segment(chest, seg[0], seg[1])))
	if nearest_cut > 0.92 + (0.45 * aim_strength if aim_active() else 0.0):
		return
	current_attack_hit = true
	opponent.receive_damage(pending_damage, towards.normalized())

func force_push() -> void:
	if force_cooldown > 0.0 or energy < 35.0 or guarding or stun_time > 0.0 or knockdown_time > 0.0 or force_casting:
		return
	energy -= 35.0
	force_cooldown = 3.0 if is_player else [8.0, 7.0, 6.0, 5.2, 4.6][difficulty_index()]
	resources_changed.emit()
	if is_player:
		action_message.emit("EMPUJE DE ENERGIA")
		rig_play("push")
		perform_force_push()
	else:
		# El adversario avisa del empuje para que el jugador tenga tiempo de cubrirse.
		force_casting = true
		force_cast_time = [0.95, 0.85, 0.75, 0.65, 0.55][difficulty_index()]
		rig_play("push", force_cast_time)
		action_message.emit("¡RIVAL PREPARA EMPUJE! PULSA K")

# Limpia objetivos antiguos. Nunca conserva nodos eliminados en la lista de combate.
func cleanup_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		if not is_instance_valid(targets[i]):
			targets.remove_at(i)
			continue
		var candidate: CharacterBody3D = targets[i]
		if not candidate.is_inside_tree() or candidate.is_queued_for_deletion() or candidate.dead:
			targets.remove_at(i)

func perform_force_push() -> void:
	if dead or not active or not is_inside_tree() or is_queued_for_deletion():
		return
	game_call("play_sfx", ["push", -3.0, 1.0])
	var push_aim: CharacterBody3D = aim_target()
	if aim_active() and is_instance_valid(push_aim):
		face_towards(push_aim.global_position, aim_strength)
	if is_player:
		cleanup_targets()
		# Copia estable: las señales de daño/derrota pueden modificar targets.
		var push_targets: Array[CharacterBody3D] = targets.duplicate()
		var pushed: bool = false
		for target in push_targets:
			if not is_instance_valid(target):
				continue
			if not target.is_inside_tree() or target.is_queued_for_deletion() or target.dead or not target.active:
				continue
			var vector: Vector3 = target.global_position - global_position
			if absf(vector.y) > 2.5:
				continue
			vector.y = 0.0
			if vector.length() < 0.01 or vector.length() > 6.5:
				continue
			var direction: Vector3 = vector.normalized()
			if (-global_transform.basis.z).dot(direction) < 0.10:
				continue
			target.receive_force_push(11.0, direction, self)
			pushed = true
		if pushed:
			action_message.emit("EMPUJE MULTIPLE DE LA FUERZA")
		return
	if dead or not active or stun_time > 0.0 or knockdown_time > 0.0:
		return
	if not is_instance_valid(opponent):
		return
	if opponent.dead or not opponent.active or not opponent.is_inside_tree() or opponent.is_queued_for_deletion():
		return
	var offset: Vector3 = opponent.global_position - global_position
	var height_difference: float = absf(offset.y)
	offset.y = 0.0
	var distance: float = offset.length()
	if height_difference > 2.5 or distance > 6.5 or distance < 0.01:
		return
	var direction: Vector3 = offset.normalized()
	var forward: Vector3 = -global_transform.basis.z
	if forward.dot(direction) < 0.10:
		return
	opponent.receive_force_push(10.0 if is_player else [6.0, 8.0, 10.0, 12.0, 14.0][difficulty_index()], direction, self)

func receive_force_push(amount: float, direction: Vector3, attacker: CharacterBody3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if dead or not active or knockdown_time > 0.0 or dodge_time > 0.0:
		return
	var incoming: Vector3 = -direction.normalized()
	var front: Vector3 = -global_transform.basis.z
	# El rival puede anticipar un empuje y cubrirse segun su estilo y dificultad.
	if not is_player and not guarding and stamina > 19.0 and swing_duration <= 0.0 and stun_time <= 0.0:
		var chance: float = [0.78, 0.54, 0.34][style] * [0.34, 0.55, 0.78, 1.0, 1.16][difficulty_index()]
		if front.dot(incoming) > 0.10 and randf() < minf(0.93, chance):
			guarding = true
			guard_commit = 0.6
	var valid_guard: bool = guarding and stamina >= 16.0 and front.dot(incoming) > 0.10
	if valid_guard:
		stamina = maxf(0.0, stamina - (22.0 if style == 0 else (30.0 if style == 1 else 38.0)))
		if parry_time > 0.0:
			parry_time = 0.0
			if is_instance_valid(attacker):
				attacker.set("stun_time", maxf(float(attacker.get("stun_time")), 0.55))
			action_message.emit("¡EMPUJE RECHAZADO! PARADA PERFECTA")
		else:
			action_message.emit("¡EMPUJE BLOQUEADO!")
		# El escudo de Fuerza detiene el derribo, pero puede agotar la resistencia.
		if stamina < 1.0:
			guarding = false
			guard_commit = 0.0
			stun_time = maxf(stun_time, 0.50)
			action_message.emit("GUARDIA ROTA")
		resources_changed.emit()
		return
	# Si el empuje no fue bloqueado, hace dano y derriba al personaje.
	# receive_damage descarta dano mientras se esquiva o ya esta en el suelo.
	receive_damage(amount, direction)
	if not dead:
		apply_knockdown(direction)

func apply_knockdown(direction: Vector3) -> void:
	if dead:
		return
	knockdown_time = knockdown_total
	force_casting = false
	stun_time = maxf(stun_time, knockdown_total)
	guarding = false
	parry_time = 0.0
	swing_duration = 0.0
	attack_pending = false
	guard_commit = 0.0
	knockback = direction.normalized() * 23.0
	velocity.y = 2.6
	action_message.emit("¡DERRIBADO!")

func receive_blaster_damage(amount: float, shooter: CharacterBody3D) -> void:
	if not active or dead or dodge_time > 0.0 or knockdown_time > 0.0:
		return
	if not is_instance_valid(shooter):
		return
	var direction: Vector3 = (global_position - shooter.global_position).normalized()
	var incoming: Vector3 = -direction
	var front: Vector3 = -global_transform.basis.z
	if guarding and front.dot(incoming) > 0.10 and stamina > 3.0:
		stamina = maxf(0.0, stamina - 5.0)
		shooter.receive_damage(12.0 if parry_time > 0.0 else 6.0, -direction)
		action_message.emit("¡DISPARO DESVIADO!")
		game_call("play_sfx", ["clash", -9.0, 1.4])
		resources_changed.emit()
		return
	receive_damage(amount, direction)

# ---------------------------------------------------------------- aimbot
# Objetivo actual: el fijado (jugador) o el mejor candidato; la IA apunta a su oponente.
func aim_target() -> CharacterBody3D:
	if not is_player:
		return opponent if is_instance_valid(opponent) and not opponent.dead else null
	if is_instance_valid(lock_target) and not lock_target.dead and lock_target.active and global_position.distance_to(lock_target.global_position) < LOCK_RANGE * 1.3:
		return lock_target
	lock_target = best_target()
	return lock_target

# Mejor objetivo: cercano y delante; penaliza a los que quedan a la espalda.
func best_target(exclude: CharacterBody3D = null) -> CharacterBody3D:
	var selected: CharacterBody3D = null
	var best: float = INF
	for candidate in targets:
		if not is_instance_valid(candidate) or candidate.dead or not candidate.active or candidate == exclude:
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist > LOCK_RANGE:
			continue
		var ahead: float = (-global_transform.basis.z).dot(offset.normalized()) if dist > 0.01 else 1.0
		var score: float = dist * (1.6 - ahead * 0.6)
		if score < best:
			best = score
			selected = candidate
	return selected

# Cambia al siguiente objetivo (TAB / cruceta abajo).
func cycle_target() -> void:
	var next: CharacterBody3D = best_target(lock_target)
	if is_instance_valid(next):
		lock_target = next
		action_message.emit("OBJETIVO: " + target_label(next))

func target_label(target: CharacterBody3D) -> String:
	if target.unit_type == "b2":
		return "SUPERDROIDE B2"
	if target.unit_type == "b1":
		return "DROIDE B1"
	return Characters.display_name(target.player_character)

# Al atacar: girar hacia el objetivo y acercarse hasta la distancia ideal de golpe.
func aim_active() -> bool:
	return aim_strength > 0.0 and (lock_enabled or not is_player)

func aim_attack() -> void:
	if not aim_active():
		return
	var target: CharacterBody3D = aim_target()
	if not is_instance_valid(target):
		return
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0.0
	var dist: float = offset.length()
	if dist > ATTACK_RANGE + 3.0 * aim_strength or dist < 0.01:
		return
	face_towards(target.global_position, aim_strength)
	if is_player:
		opponent = target
	var gap: float = minf(dist - IDEAL_STRIKE_DISTANCE * reach_mult, 2.6 * aim_strength)
	if gap > 0.0:
		# El empuje decae a 18 u/s^2: recorre v^2/36 metros.
		knockback += offset.normalized() * sqrt(36.0 * gap)

func face_towards(point: Vector3, weight: float) -> void:
	var to_point: Vector3 = point - global_position
	to_point.y = 0.0
	if to_point.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to_point.x, -to_point.z), minf(1.0, weight))

# Enemigo que esta a punto de golpear al jugador: un tajo en curso, un empuje
# cargandose o un droide a punto de disparar. Al bloquear, cualquier enemigo cercano.
func incoming_threat() -> CharacterBody3D:
	var selected: CharacterBody3D = null
	var best: float = INF
	var candidates: Array = targets.duplicate()
	if is_instance_valid(opponent) and not candidates.has(opponent):
		candidates.append(opponent)
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead or not candidate.active:
			continue
		var dist: float = global_position.distance_to(candidate.global_position)
		var attacking: bool = dist < 7.0 and (candidate.attack_pending or candidate.swing_duration > 0.0 or candidate.force_casting)
		var shooting: bool = candidate.unit_type != "jedi" and dist < 14.0 and candidate.shot_timer < 0.6
		var defending: bool = guarding and dist < 9.0
		if (attacking or shooting or defending) and dist < best:
			best = dist
			selected = candidate
	return selected

func nearest_target(front_only: bool = false) -> CharacterBody3D:
	var selected: CharacterBody3D = null
	var best: float = INF
	for candidate in targets:
		if not is_instance_valid(candidate) or candidate.dead or not candidate.active:
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		if front_only and offset.length() > 0.01 and (-global_transform.basis.z).dot(offset.normalized()) < 0.38:
			continue
		var dist: float = offset.length()
		if dist < best:
			best = dist
			selected = candidate
	return selected

func droid_behavior(_delta: float) -> Vector3:
	if not is_instance_valid(opponent) or opponent.dead:
		return Vector3.ZERO
	var offset: Vector3 = opponent.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	guarding = false
	if shot_timer <= 0.0 and distance < 14.0 and distance > 0.6:
		shot_timer = randf_range(1.9, 3.0) * (1.25 if unit_type == "b2" else 1.0) * [1.4, 1.2, 1.0, 0.85, 0.70][difficulty_index()]
		var damage: float = (13.0 if unit_type == "b2" else 6.5) * [0.5, 0.75, 1.0, 1.15, 1.30][difficulty_index()]
		game_call("play_sfx", ["blaster", -9.0, randf_range(0.9, 1.12)])
		if randf() < 0.55 + 0.45 * aim_strength:
			opponent.receive_blaster_damage(damage, self)
			action_message.emit("¡DISPARO DE BLASTER!")
		else:
			action_message.emit("DISPARO FALLIDO")
	if distance > (7.0 if unit_type == "b2" else 5.5):
		return offset.normalized() * 0.58
	if distance < 3.0:
		return -offset.normalized() * 0.5
	return Vector3.ZERO

func receive_damage(amount: float, direction: Vector3) -> void:
	if dead or not active or dodge_time > 0.0 or knockdown_time > 0.0:
		return
	# Solo bloquea golpes que llegan de frente, no por la espalda.
	var incoming: Vector3 = -direction.normalized()
	var front: Vector3 = -global_transform.basis.z
	var valid_guard: bool = guarding and stamina > 1.0 and front.dot(incoming) > 0.10
	if valid_guard and parry_time > 0.0:
		show_blade_clash()
		parry_time = 0.0
		stamina = minf(100.0, stamina + 10.0)
		if is_instance_valid(opponent):
			opponent.stun_time = maxf(opponent.stun_time, 0.68)
			opponent.attack_pending = false
			opponent.guarding = false
			opponent.call("rig_play", "stagger")
		game_call("slow_motion", [0.3, 0.55])
		game_call("play_sfx", ["clash", 1.0, 1.2])
		guard_commit = 0.0
		action_message.emit("PARADA PERFECTA - CONTRAATACA")
		if not is_player:
			enemy_attack_delay = 0.06
		resources_changed.emit()
		return
	var actual: float = amount / maxf(defense_mult, 0.1)
	# Armadura de la IA: reduce ligeramente el dano sin negar los golpes.
	if not is_player:
		actual *= 1.0 - ai_damage_resistance
		ai_recovery_delay = 4.5
	if valid_guard:
		show_blade_clash()
		if is_instance_valid(rig):
			rig.call("push_back_blade")
		if is_instance_valid(opponent):
			opponent.call("rig_play", "recoil")
		actual = amount * (0.10 if style == 0 else (0.20 if style == 1 else 0.30))
		stamina = maxf(0.0, stamina - (10.0 if style == 0 else 15.0))
		action_message.emit("BLOQUEO %s" % style_name())
		if not is_player:
			enemy_attack_delay = minf(enemy_attack_delay, 0.30)
		if stamina < 1.0:
			guarding = false
			guard_commit = 0.0
			stun_time = maxf(stun_time, 0.45)
			action_message.emit("GUARDIA ROTA")
	health = maxf(0.0, health - actual)
	if actual > 0.01:
		hit_flash_time = 0.19
		show_hit_spark()
		if not valid_guard:
			show_small_wound()
			rig_play("hit")
			var cut := global_position + Vector3(0.0, 0.35, 0.0)
			if is_instance_valid(opponent):
				var oseg: Array = opponent.call("blade_points")
				cut = Geometry3D.get_closest_point_to_segment(cut, oseg[0], oseg[1]).lerp(cut, 0.4)
			game_call("spawn_sparks", [cut, Color(1.0, 0.55, 0.2), 36, 4.5])
			game_call("play_sfx", ["hit", -4.0, randf_range(0.9, 1.1)])
			game_call("hit_stop", [0.075])
		action_message.emit("¡IMPACTO! -%d VIDA" % int(ceilf(actual)))
	# Segunda oportunidad una sola vez, solo en Maestro y Leyenda.
	# No es una resurreccion infinita y se activa al recibir un golpe letal.
	if not is_player and health <= 0.0 and ai_second_wind and not ai_second_wind_used:
		ai_second_wind_used = true
		health = max_health * (0.16 if ai_difficulty == 4 else 0.22)
		stamina = minf(100.0, stamina + 40.0)
		guard_commit = 0.0
		action_message.emit("¡RIVAL: SEGUNDO ALIENTO!")
	if not valid_guard:
		knockback += direction * 2.0
	health_changed.emit()
	resources_changed.emit()
	if health <= 0.0:
		dead = true
		active = false
		guarding = false
		attack_pending = false
		force_casting = false
		blade_mesh.visible = false
		blade_light.visible = false
		body_mesh.rotation.z = 0.55
		if is_instance_valid(rig):
			rig.call("set_ignite", false)
			rig_play("ko", -1.0, true)
		game_call("slow_motion", [0.25, 1.2])
		defeated.emit()

# Destello corto en el punto de impacto para hacer visible cada herida.
func show_hit_spark() -> void:
	if not is_inside_tree():
		return
	var spark := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	spark.mesh = sphere
	# Destello aditivo y translucido: no tapa al personaje.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.6, 0.25, 0.55)
	spark.material_override = glow
	get_parent().add_child(spark)
	spark.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	var tween: Tween = spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector3(2.0, 2.0, 2.0), 0.14)
	tween.tween_property(glow, "albedo_color:a", 0.0, 0.14)
	tween.chain().tween_callback(spark.queue_free)

# Choque luminoso justo entre ambas hojas, solo si el bloqueo es frontal.
# No se produce una herida completa al bloquear: predomina la chispa del sable.
func show_blade_clash() -> void:
	if clash_cooldown > 0.0 or not is_instance_valid(opponent) or not is_instance_valid(saber_pivot):
		return
	clash_cooldown = 0.14
	# Par de hojas mas cercanas (con doble sable hay varias combinaciones).
	var pts: PackedVector3Array = PackedVector3Array([global_position, opponent.global_position])
	var best_gap: float = INF
	for mine in all_blades():
		for theirs in opponent.call("all_blades"):
			var cand: PackedVector3Array = Geometry3D.get_closest_points_between_segments(mine[0], mine[1], theirs[0], theirs[1])
			if cand[0].distance_to(cand[1]) < best_gap:
				best_gap = cand[0].distance_to(cand[1])
				pts = cand
	var center: Vector3 = (pts[0] + pts[1]) * 0.5
	# Las hojas se encuentran de verdad: cada rig corrige la mitad de la distancia.
	if is_instance_valid(rig) and is_instance_valid(opponent.get("rig")):
		rig.call("apply_contact", (pts[1] - pts[0]) * 0.5)
		opponent.rig.call("apply_contact", (pts[0] - pts[1]) * 0.5)
	spawn_glow(center, Color(0.90, 0.94, 1.0), 0.2, 0.16)
	game_call("spawn_sparks", [center, Color(1.0, 0.85, 0.6), 50, 5.5])
	game_call("play_sfx", ["clash", -3.0, randf_range(0.9, 1.1)])
	game_call("hit_stop", [0.07])
	action_message.emit("¡CHOQUE DE ESPADAS!")

func spawn_glow(point: Vector3, color: Color, radius: float, lifetime: float) -> void:
	if not is_inside_tree():
		return
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	spark.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	spark.material_override = mat
	get_parent().add_child(spark)
	spark.global_position = point
	var tween: Tween = spark.create_tween()
	tween.tween_property(spark, "scale", Vector3(0.05, 0.05, 0.05), lifetime)
	tween.tween_callback(spark.queue_free)

# Pequena marca roja sin desmembramientos ni sangre abundante.
# La mancha se coloca sobre el peto y desaparece gradualmente.
func show_small_wound() -> void:
	if not is_instance_valid(visual_root):
		return
	var mark := MeshInstance3D.new()
	var plane := SphereMesh.new()
	plane.radius = 0.09
	plane.height = 0.045
	mark.mesh = plane
	mark.position = Vector3(randf_range(-0.25, 0.25), randf_range(-0.34, 0.33), -0.267)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.025, 0.035, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.material_override = mat
	visual_root.add_child(mark)
	wound_marks.append(mark)
	# Nunca acumular manchas infinitas sobre el personaje.
	if wound_marks.size() > 5:
		# Sin tipo: la marca pudo liberarse ya al terminar su desvanecido.
		var oldest = wound_marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var tween: Tween = mark.create_tween()
	tween.tween_property(mat, "albedo_color", Color(0.5, 0.025, 0.035, 0.0), 4.0)
	tween.tween_callback(mark.queue_free)
