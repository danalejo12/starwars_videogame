extends Node3D

const FighterScript = preload("res://scripts/fighter.gd")
var player: CharacterBody3D
var rival: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
var selected_hero: String = "anakin"
var selected_rival: String = "obiwan"
const Characters = preload("res://scripts/characters.gd")
var rival_selector: OptionButton
var arena_selector: OptionButton
var hero_label: Label
var rival_label: Label
# Versus local al mejor de 3 rondas.
var versus_wins: Array[int] = [0, 0]
var versus_round: int = 1
# Pantalla de seleccion: personajes en 3D a ambos lados del menu.
const JediRigScript = preload("res://scripts/jedi_rig.gd")
const SHORT_NAMES := {"anakin": "ANAKIN", "obiwan": "OBI-WAN", "luke": "LUKE", "vader": "VADER", "maul": "MAUL",
	"yoda": "YODA", "mace": "MACE WINDU", "dooku": "DOOKU", "kylo": "KYLO REN", "rey": "REY"}
var preview_rigs: Array = [null, null]
var preview_timers: Array[float] = [2.0, 3.5]
var hero_pick_label: Label
var rival_pick_label: Label
var sfx: Node
var character_selector: OptionButton
var mission_enemies_remaining: int = 0
var mission_exit: Area3D
var mission_objective: Label
var exit_unlocked: bool = false
var camera: Camera3D
var player_bar: ProgressBar
var rival_bar: ProgressBar
var stamina_bar: ProgressBar
var energy_bar: ProgressBar
var status_label: Label
var mode_label: Label
var tip_label: Label
var menu_panel: PanelContainer
var menu_title: Label
var story_button: Button
var duel_button: Button
var difficulty_selector: OptionButton
var difficulty_label: Label
var difficulty: int = 3 # 1 Facil, 2 Normal, 3 Dificil, 4 Maestro, 5 Leyenda
var mode: String = ""
var stage: int = 1
var playing: bool = false
var ended: bool = false
var semi_camera: bool = false
var tip_timer: float = 0.0
var controller_label: Label
var camera_impact: float = 0.0
var camera_shake_clock: float = 0.0
# v0.7: pausa de impacto y camara lenta medidas en tiempo real.
var freeze_until: int = 0
var slow_until: int = 0
var slow_scale: float = 1.0
# Escenarios: "hangar" (historia y duelo clasico) o "mustafar".
const MustafarScript = preload("res://scripts/mustafar.gd")
var arena_name: String = "hangar"
var environment: Environment
var sun_light: DirectionalLight3D
var base_visuals: Node3D
var wall_meshes: Array[Node3D] = []
var mustafar: Node3D
# Aimbot: marcador bajo el objetivo y estado en el HUD.
var target_marker: MeshInstance3D
var aim_label: Label

func _ready() -> void:
	Engine.time_scale = 1.0
	sfx = load("res://scripts/sfx.gd").new()
	sfx.name = "Sonido"
	add_child(sfx)
	configure_inputs()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	create_arena()
	player = FighterScript.new()
	player.is_player = true
	player.position = Vector3(0.0, 1.08, 4.5)
	player.aim_strength = 1.0
	add_child(player)
	player.health_changed.connect(refresh_hud)
	player.resources_changed.connect(refresh_hud)
	player.defeated.connect(on_player_defeated)
	player.action_message.connect(show_tip)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68.0
	camera.position = Vector3(0, 8, 16)
	add_child(camera)
	create_hud()
	create_target_marker()
	refresh_controller_status()
	show_menu()
	apply_arena()
	build_preview(0)
	build_preview(1)
	var args := OS.get_cmdline_user_args()
	var roster_index := args.find("--autotest-roster")
	if roster_index >= 0 and roster_index + 1 < args.size():
		var roster_test: Node = load("res://scripts/autotest_roster.gd").new()
		roster_test.set("game", self)
		roster_test.set("out_dir", args[roster_index + 1])
		add_child(roster_test)
		return
	if args.has("--autotest-aim"):
		var aim_test: Node = load("res://scripts/autotest_aim.gd").new()
		aim_test.set("game", self)
		add_child(aim_test)
	if args.has("--autotest-facing"):
		var facing_test: Node = load("res://scripts/autotest_facing.gd").new()
		facing_test.set("game", self)
		add_child(facing_test)
	var test_index := args.find("--autotest")
	if test_index >= 0 and test_index + 1 < args.size():
		var tester: Node = load("res://scripts/autotest.gd").new()
		tester.set("game", self)
		tester.set("out_dir", args[test_index + 1])
		if args.has("--historia"):
			tester.set("mode", "historia")
		if args.has("--mustafar"):
			tester.set("mode", "mustafar")
		if args.has("--versus"):
			tester.set("mode", "versus")
		add_child(tester)

# Rescate extra si algun personaje logra atravesar el limite.
func rescue_if_outside(fighter: CharacterBody3D, spawn: Vector3) -> void:
	if not is_instance_valid(fighter) or fighter.dead:
		return
	var pos := fighter.global_position
	if absf(pos.x) > 12.8 or absf(pos.z) > 12.8 or pos.y < -3.0:
		fighter.global_position = spawn
		fighter.velocity = Vector3.ZERO
		fighter.knockback = Vector3.ZERO
		fighter.knockdown_time = 0.0
		fighter.stun_time = 0.35
		show_tip("PERSONAJE DEVUELTO A LA ARENA")

func _process(delta: float) -> void:
	camera_impact = maxf(0.0, camera_impact - delta / maxf(Engine.time_scale, 0.04) * 1.9)
	camera_shake_clock += delta * 35.0
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return # No usar objetos de la escena que se esta descargando.
	if Input.is_action_just_pressed("toggle_camera"):
		semi_camera = not semi_camera
		show_tip("CAMARA SEMILIBRE" if semi_camera else "CAMARA CLASICA")
	if playing and not ended:
		rescue_if_outside(player, Vector3(0, 1.08, 4.5))
		if mode == "historia":
			for enemy in enemies:
				if is_instance_valid(enemy):
					rescue_if_outside(enemy, Vector3(clampf(enemy.global_position.x, -8.0, 8.0), 1.08, -4.5))
		else:
			rescue_if_outside(rival, Vector3(0, 1.08, -4.5))
	if playing and mode == "historia" and not ended and exit_unlocked and is_instance_valid(player):
		if player.global_position.distance_to(Vector3(0.0, 1.08, -9.0)) < 2.4:
			finish_game(true)
	if tip_timer > 0.0:
		tip_timer -= delta
		if tip_timer <= 0.0:
			tip_label.text = ""
	var now := Time.get_ticks_msec()
	var scale := 1.0
	if now < slow_until:
		scale = slow_scale
	if now < freeze_until:
		scale = 0.12
	Engine.time_scale = scale
	update_aim(delta / maxf(scale, 0.04))
	update_previews(delta / maxf(scale, 0.04))
	if is_instance_valid(camera) and is_instance_valid(player):
		var focus := player.global_position + Vector3(0, 0.6, 0)
		var separation := 0.0
		if is_instance_valid(rival):
			focus = focus.lerp(rival.global_position + Vector3(0, 0.6, 0), 0.5)
			separation = player.global_position.distance_to(rival.global_position)
		# Encuadre cercano que sigue a ambos luchadores (los controles siguen siendo fijos).
		var desired := focus + Vector3(2.4 + separation * 0.2, 2.5 + separation * 0.22, 5.2 + separation * 0.5)
		# La camara nunca atraviesa muros ni techo del hangar.
		if arena_name == "mustafar":
			desired = Vector3(clampf(desired.x, -14.0, 14.0), clampf(desired.y, 1.6, 7.5), clampf(desired.z, -10.0, 15.0))
		else:
			desired = Vector3(clampf(desired.x, -9.4, 9.4), clampf(desired.y, 1.6, 4.9), clampf(desired.z, -9.0, 10.6))
		if menu_panel.visible:
			desired = Vector3(0, 2.3, 10.5)
			focus = Vector3(0, 1.7, 0)
		elif not playing:
			desired = Vector3(0, 8.4, 14.0)
		if semi_camera:
			desired = player.global_position + Vector3(0, 6.0, 10.0)
		camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta / maxf(Engine.time_scale, 0.04) * 3.8))
		if camera_impact > 0.0:
			camera.global_position += Vector3(sin(camera_shake_clock * 1.7), cos(camera_shake_clock * 1.2), 0.0) * camera_impact * 0.075
		camera.look_at(focus, Vector3.UP)

func create_target_marker() -> void:
	target_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.72
	ring.rings = 32
	target_marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.25, 0.15, 0.9)
	target_marker.material_override = mat
	target_marker.scale = Vector3(1, 0.2, 1)
	target_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_marker.visible = false
	add_child(target_marker)

# Controles del aimbot y marcador bajo el objetivo fijado.
func update_aim(real_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(target_marker):
		return
	if playing and not ended:
		if Input.is_action_just_pressed("lock_toggle"):
			player.lock_enabled = not player.lock_enabled
			show_tip("AIMBOT ACTIVADO" if player.lock_enabled else "AIMBOT DESACTIVADO")
		if Input.is_action_just_pressed("switch_target"):
			player.call("cycle_target")
	var target: CharacterBody3D = null
	if playing and not ended and player.lock_enabled:
		target = player.call("aim_target")
	target_marker.visible = is_instance_valid(target)
	if target_marker.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
		target_marker.global_position = Vector3(target.global_position.x, 0.06, target.global_position.z)
		target_marker.scale = Vector3(pulse, 0.2, pulse)
		target_marker.rotate_y(real_delta * 1.5)
		aim_label.text = "AIMBOT: ON | OBJETIVO: " + String(player.call("target_label", target))
	elif playing:
		aim_label.text = "AIMBOT: OFF (T)" if not player.lock_enabled else "AIMBOT: ON | SIN OBJETIVO"
	else:
		aim_label.text = ""

func hit_stop(duration: float) -> void:
	freeze_until = maxi(freeze_until, Time.get_ticks_msec() + int(duration * 1000.0))

func slow_motion(time_scale: float, duration: float) -> void:
	slow_scale = time_scale
	slow_until = Time.get_ticks_msec() + int(duration * 1000.0)
	camera_impact = maxf(camera_impact, 0.9)

# Chispas alargadas que salen disparadas del punto de choque, con destello de luz.
func spawn_sparks(point: Vector3, color: Color, amount: int = 40, speed: float = 5.0) -> void:
	var fx := CPUParticles3D.new()
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = amount
	fx.lifetime = 0.5
	fx.direction = Vector3.UP
	fx.spread = 180.0
	fx.initial_velocity_min = speed * 0.3
	fx.initial_velocity_max = speed
	fx.gravity = Vector3(0, -9.8, 0)
	fx.particle_flag_align_y = true
	fx.scale_amount_min = 0.5
	fx.scale_amount_max = 1.2
	var streak := BoxMesh.new()
	streak.size = Vector3(0.012, 0.13, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	streak.material = mat
	fx.mesh = streak
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	fx.color_ramp = ramp
	add_child(fx)
	fx.global_position = point
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = color.lerp(Color.WHITE, 0.5)
	flash.light_energy = 5.0
	flash.omni_range = 4.5
	add_child(flash)
	flash.global_position = point
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	refresh_controller_status()

func refresh_controller_status() -> void:
	if not is_instance_valid(controller_label):
		return
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		controller_label.text = "MANDO: no detectado | teclado habilitado"
	else:
		var device_id: int = devices[0]
		controller_label.text = "MANDO CONECTADO: " + Input.get_joy_name(device_id)

func add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

# Entradas compatibles con mapeo SDL: PS4, otros mandos y teclado.
# -1 aplica el mapeo a cualquier mando conectado.
func add_pad_button(action: String, button: JoyButton, device: int = 0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	InputMap.action_add_event(action, event)

func add_pad_axis(action: String, axis: JoyAxis, direction: float, device: int = 0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_set_deadzone(action, 0.24)
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func configure_controller_inputs() -> void:
	# Stick izquierdo: desplazamiento 360 grados.
	add_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	add_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	# Cruceta: seleccion de estilo.
	add_pad_button("style_guardian", JOY_BUTTON_DPAD_LEFT)
	add_pad_button("style_duelist", JOY_BUTTON_DPAD_UP)
	add_pad_button("style_aggressive", JOY_BUTTON_DPAD_RIGHT)
	# Botones de PlayStation: X/cruz, circulo, cuadrado y triangulo.
	add_pad_button("jump", JOY_BUTTON_A)
	add_pad_button("dodge", JOY_BUTTON_B)
	add_pad_button("attack", JOY_BUTTON_X)
	add_pad_button("force_push", JOY_BUTTON_Y)
	add_pad_button("block", JOY_BUTTON_LEFT_SHOULDER)
	add_pad_button("force_push", JOY_BUTTON_RIGHT_SHOULDER)
	add_pad_button("sprint", JOY_BUTTON_LEFT_STICK)
	add_pad_button("toggle_camera", JOY_BUTTON_RIGHT_STICK)
	add_pad_button("restart", JOY_BUTTON_START)
	add_pad_button("lock_toggle", JOY_BUTTON_BACK)
	add_pad_button("switch_target", JOY_BUTTON_DPAD_DOWN)
	# Los gatillos son ejes analogicos, no botones ordinarios.
	add_pad_axis("block", JOY_AXIS_TRIGGER_LEFT, 1.0)
	add_pad_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)

# Jugador 2: flechas + teclado numerico (o M , . N para portatiles) y el segundo mando.
func configure_player2_inputs() -> void:
	add_key("p2_move_forward", KEY_UP)
	add_key("p2_move_back", KEY_DOWN)
	add_key("p2_move_left", KEY_LEFT)
	add_key("p2_move_right", KEY_RIGHT)
	for pair in [["p2_attack", KEY_KP_1], ["p2_attack", KEY_M], ["p2_block", KEY_KP_2], ["p2_block", KEY_COMMA],
			["p2_dodge", KEY_KP_3], ["p2_dodge", KEY_PERIOD], ["p2_force_push", KEY_KP_0], ["p2_force_push", KEY_N],
			["p2_jump", KEY_KP_ENTER], ["p2_sprint", KEY_KP_ADD],
			["p2_style_guardian", KEY_KP_7], ["p2_style_duelist", KEY_KP_8], ["p2_style_aggressive", KEY_KP_9]]:
		add_key(pair[0], pair[1])
	add_pad_axis("p2_move_left", JOY_AXIS_LEFT_X, -1.0, 1)
	add_pad_axis("p2_move_right", JOY_AXIS_LEFT_X, 1.0, 1)
	add_pad_axis("p2_move_forward", JOY_AXIS_LEFT_Y, -1.0, 1)
	add_pad_axis("p2_move_back", JOY_AXIS_LEFT_Y, 1.0, 1)
	add_pad_button("p2_style_guardian", JOY_BUTTON_DPAD_LEFT, 1)
	add_pad_button("p2_style_duelist", JOY_BUTTON_DPAD_UP, 1)
	add_pad_button("p2_style_aggressive", JOY_BUTTON_DPAD_RIGHT, 1)
	add_pad_button("p2_jump", JOY_BUTTON_A, 1)
	add_pad_button("p2_dodge", JOY_BUTTON_B, 1)
	add_pad_button("p2_attack", JOY_BUTTON_X, 1)
	add_pad_button("p2_force_push", JOY_BUTTON_Y, 1)
	add_pad_button("p2_block", JOY_BUTTON_LEFT_SHOULDER, 1)
	add_pad_button("p2_force_push", JOY_BUTTON_RIGHT_SHOULDER, 1)
	add_pad_button("p2_sprint", JOY_BUTTON_LEFT_STICK, 1)
	add_pad_axis("p2_block", JOY_AXIS_TRIGGER_LEFT, 1.0, 1)
	add_pad_axis("p2_attack", JOY_AXIS_TRIGGER_RIGHT, 1.0, 1)

func configure_inputs() -> void:
	configure_controller_inputs()
	configure_player2_inputs()
	add_key("move_forward", KEY_W)
	add_key("move_back", KEY_S)
	add_key("move_left", KEY_A)
	add_key("move_right", KEY_D)
	add_key("jump", KEY_SPACE)
	add_key("sprint", KEY_SHIFT)
	add_key("attack", KEY_J)
	add_key("block", KEY_K)
	add_key("force_push", KEY_Q)
	add_key("dodge", KEY_E)
	add_key("toggle_camera", KEY_C)
	add_key("restart", KEY_R)
	add_key("lock_toggle", KEY_T)
	add_key("switch_target", KEY_TAB)
	add_key("style_guardian", KEY_1)
	add_key("style_duelist", KEY_2)
	add_key("style_aggressive", KEY_3)
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", left_click)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("block", right_click)

func mesh_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> void:
	var mesh_instance := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh_instance.mesh = cube
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.45
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

# Barreras visibles y fisicas: el material por si solo no detiene personajes.
func create_wall(size: Vector3, pos: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = "Muro_Colision"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = pos
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	mesh_box(wall, size, Vector3.ZERO, Color(0.16, 0.20, 0.29))
	wall_meshes.append(wall.get_child(wall.get_child_count() - 1))
	add_child(wall)
	# Franja luminosa superior para identificar el limite.
	mesh_box(base_visuals, Vector3(size.x, 0.12, size.z), pos + Vector3(0, size.y * 0.5, 0), Color(0.05, 0.7, 1.0), true)

func create_arena() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.023, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.28, 0.44)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.85
	world.environment = env
	add_child(world)
	environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 0.85
	add_child(sun)
	sun_light = sun
	base_visuals = Node3D.new()
	base_visuals.name = "ArenaBase"
	add_child(base_visuals)
	mesh_box(base_visuals, Vector3(24, 0.55, 24), Vector3(0, -0.3, 0), Color(0.13, 0.16, 0.24))
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 0.5, 24)
	shape.shape = box
	floor.position = Vector3(0, -0.25, 0)
	floor.add_child(shape)
	add_child(floor)
	for i in range(-5, 6):
		mesh_box(base_visuals, Vector3(0.07, 0.025, 22), Vector3(i * 2.0, 0.01, 0), Color(0.08, 0.55, 0.72), true)
		mesh_box(base_visuals, Vector3(22, 0.025, 0.07), Vector3(0, 0.012, i * 2.0), Color(0.08, 0.55, 0.72), true)
	for x in [-11.0, 11.0]:
		for z in [-11.0, 11.0]:
			mesh_box(base_visuals, Vector3(1.6, 7.0, 1.6), Vector3(x, 3.5, z), Color(0.17, 0.21, 0.32))
			mesh_box(base_visuals, Vector3(1.8, 0.18, 1.8), Vector3(x, 6.8, z), Color(0.08, 0.70, 1.0), true)
	# Centro de los muros en +/-11.65: quedan dentro del borde del suelo.
	# Altura 4.0, para que un empuje fuerte no los atraviese.
	for x in [-11.65, 11.65]:
		create_wall(Vector3(0.7, 4.0, 23.9), Vector3(x, 1.75, 0))
	for z in [-11.65, 11.65]:
		create_wall(Vector3(23.9, 4.0, 0.7), Vector3(0, 1.75, z))

func make_label(parent: Node, content: String, pos: Vector2, font_size: int = 17) -> Label:
	var node := Label.new()
	node.text = content
	node.position = pos
	node.add_theme_font_size_override("font_size", font_size)
	parent.add_child(node)
	return node

func make_bar(parent: Node, pos: Vector2, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(width, 20)
	bar.max_value = 100
	bar.value = 100
	parent.add_child(bar)
	return bar

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	make_label(ui, "DUELO ESTELAR PC | v0.7 - DUELO CINEMATICO", Vector2(22, 13), 24)
	hero_label = make_label(ui, "HEROE", Vector2(24, 55))
	player_bar = make_bar(ui, Vector2(24, 78), 325)
	make_label(ui, "RESISTENCIA", Vector2(24, 105), 13)
	stamina_bar = make_bar(ui, Vector2(24, 125), 325)
	make_label(ui, "ENERGIA", Vector2(24, 152), 13)
	energy_bar = make_bar(ui, Vector2(24, 172), 325)
	rival_label = make_label(ui, "RIVAL", Vector2(946, 55))
	rival_bar = make_bar(ui, Vector2(946, 78), 310)
	mode_label = make_label(ui, "", Vector2(946, 110), 17)
	make_label(ui, "TECLADO: WASD MOVER | J ATACAR | K BLOQUEAR | E ESQUIVAR | Q EMPUJE | 1/2/3 ESTILOS | T AIMBOT | TAB OBJETIVO", Vector2(24, 649), 15)
	make_label(ui, "J2: FLECHAS MOVER | M/NUM1 ATACAR | ,/NUM2 BLOQUEAR | ./NUM3 ESQUIVAR | N/NUM0 EMPUJE | O SEGUNDO MANDO", Vector2(24, 626), 15)
	make_label(ui, "PS4 (J1 MANDO 1): STICK MOVER | CUADRADO/R2 ATACAR | L1/L2 BLOQUEAR | TRIANGULO/R1 EMPUJE | CIRCULO ESQUIVAR", Vector2(24, 672), 15)
	controller_label = make_label(ui, "", Vector2(24, 205), 15)
	aim_label = make_label(ui, "", Vector2(946, 140), 15)
	mission_objective = make_label(ui, "", Vector2(24, 230), 17)
	status_label = make_label(ui, "", Vector2(420, 155), 30)
	tip_label = make_label(ui, "", Vector2(460, 240), 22)
	menu_panel = PanelContainer.new()
	menu_panel.position = Vector2(330, 54)
	menu_panel.custom_minimum_size = Vector2(620, 0)
	ui.add_child(menu_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	menu_panel.add_child(content)
	menu_title = Label.new()
	menu_title.text = "DUELO ESTELAR PC - ELIGE TUS PERSONAJES"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 22)
	content.add_child(menu_title)
	hero_pick_label = Label.new()
	content.add_child(hero_pick_label)
	content.add_child(make_roster_grid("p1"))
	rival_pick_label = Label.new()
	content.add_child(rival_pick_label)
	content.add_child(make_roster_grid("p2"))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	content.add_child(options)
	arena_selector = OptionButton.new()
	arena_selector.custom_minimum_size = Vector2(300, 40)
	arena_selector.add_item("ESCENARIO: MUSTAFAR")
	arena_selector.add_item("ESCENARIO: HANGAR")
	arena_selector.item_selected.connect(on_arena_selected)
	arena_name = "mustafar"
	options.add_child(arena_selector)
	difficulty_selector = OptionButton.new()
	difficulty_selector.custom_minimum_size = Vector2(300, 40)
	for option_name in ["1 - FACIL", "2 - NORMAL", "3 - DIFICIL", "4 - MAESTRO", "5 - LEYENDA"]:
		difficulty_selector.add_item("DIFICULTAD IA: " + option_name)
	difficulty_selector.select(2)
	difficulty_selector.item_selected.connect(on_difficulty_selected)
	options.add_child(difficulty_selector)
	difficulty_label = Label.new()
	difficulty_label.visible = false
	content.add_child(difficulty_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)
	var versus_button := Button.new()
	versus_button.text = "VERSUS\n2 JUGADORES"
	versus_button.custom_minimum_size = Vector2(200, 56)
	versus_button.pressed.connect(start_versus)
	buttons.add_child(versus_button)
	duel_button = Button.new()
	duel_button.text = "DUELO\nVS IA"
	duel_button.custom_minimum_size = Vector2(200, 56)
	duel_button.pressed.connect(start_mode.bind("duelo"))
	buttons.add_child(duel_button)
	story_button = Button.new()
	story_button.text = "HISTORIA\nDROIDES"
	story_button.custom_minimum_size = Vector2(200, 56)
	story_button.pressed.connect(start_mode.bind("historia"))
	buttons.add_child(story_button)
	refresh_pick_labels()
	versus_button.grab_focus.call_deferred()

# Rejilla de 10 personajes para un lado (p1 o p2), coloreada con el color de cada sable.
func make_roster_grid(side: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	for key in Characters.ORDER:
		var d: Dictionary = Characters.get_data(key)
		var c: Color = d["saber"]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = SHORT_NAMES[key]
		b.custom_minimum_size = Vector2(118, 38)
		b.tooltip_text = "%s - %s" % [d["name"], d["title"]]
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.07, 0.08, 0.11, 0.92)
		normal.border_color = c.darkened(0.35)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(4)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.14, 0.16, 0.22, 0.95)
		var picked := normal.duplicate() as StyleBoxFlat
		picked.bg_color = c.darkened(0.5)
		picked.border_color = c.lightened(0.3)
		picked.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", picked)
		b.add_theme_stylebox_override("hover_pressed", picked)
		b.button_pressed = key == (selected_hero if side == "p1" else selected_rival)
		b.pressed.connect(on_pick.bind(side, key))
		grid.add_child(b)
	return grid

func on_pick(side: String, key: String) -> void:
	if side == "p1":
		selected_hero = key
		build_preview(0)
	else:
		selected_rival = key
		build_preview(1)
	refresh_pick_labels()

func stat_line(key: String) -> String:
	var d: Dictionary = Characters.get_data(key)
	return "%s - %s   VEL %d  DANO %d  DEF %d" % [d["name"], d["title"], roundi(float(d["speed"]) * 100.0), roundi(float(d["power"]) * 100.0), roundi(float(d["defense"]) * 100.0)]

func refresh_pick_labels() -> void:
	if is_instance_valid(hero_pick_label):
		hero_pick_label.text = "JUGADOR 1:  " + stat_line(selected_hero)
		rival_pick_label.text = "RIVAL / JUGADOR 2:  " + stat_line(selected_rival)

func on_arena_selected(index: int) -> void:
	arena_name = "mustafar" if index == 0 else "hangar"
	apply_arena()

# Personaje de muestra a cada lado del menu, a escala grande y con su nombre encima.
func build_preview(side_index: int) -> void:
	if is_instance_valid(preview_rigs[side_index]):
		preview_rigs[side_index].queue_free()
	var key: String = selected_hero if side_index == 0 else selected_rival
	var rig: Node3D = JediRigScript.new()
	rig.name = "Vista_%d" % side_index
	add_child(rig)
	rig.position = Vector3(-7.8 if side_index == 0 else 7.8, 0.0, 2.0)
	rig.rotation.y = 0.5 if side_index == 0 else -0.5
	rig.scale = Vector3.ONE * 1.9 * float(Characters.get_data(key)["scale"])
	rig.call("setup", key)
	var tag := Label3D.new()
	tag.text = ("J1  " if side_index == 0 else "J2  ") + String(SHORT_NAMES[key])
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 64
	tag.outline_size = 12
	tag.modulate = (Characters.get_data(key)["saber"] as Color).lightened(0.35)
	tag.pixel_size = 0.0035 / float(Characters.get_data(key)["scale"])
	tag.position = Vector3(0, 2.05, 0)
	rig.add_child(tag)
	rig.visible = menu_panel.visible
	preview_rigs[side_index] = rig
	preview_timers[side_index] = randf_range(1.2, 2.5)

func update_previews(delta: float) -> void:
	for i in range(2):
		var rig: Node3D = preview_rigs[i]
		if not is_instance_valid(rig):
			continue
		rig.visible = menu_panel.visible
		if not rig.visible:
			continue
		rig.call("tick", delta, Vector3.ZERO, false, "idle", false)
		preview_timers[i] -= delta
		if preview_timers[i] <= 0.0:
			preview_timers[i] = randf_range(2.5, 4.5)
			rig.call("play", ["slashR", "slashL", "overhead", "thrust", "rising"][randi() % 5])

func play_sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if is_instance_valid(sfx):
		sfx.call("play", sound, volume_db, pitch)

func make_roster_selector(parent: Control, prefix: String, selected: int) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(380, 40)
	for key in Characters.ORDER:
		var d: Dictionary = Characters.get_data(key)
		selector.add_item("%s%s | %s" % [prefix, d["name"], d["title"]])
	selector.select(selected)
	parent.add_child(selector)
	return selector

func start_versus() -> void:
	start_mode("versus")

func on_difficulty_selected(index: int) -> void:
	difficulty = index + 1
	difficulty_label.text = "DIFICULTAD: " + difficulty_selector.get_item_text(index)

func difficulty_name() -> String:
	return ["FACIL", "NORMAL", "DIFICIL", "MAESTRO", "LEYENDA"][difficulty - 1]

func show_menu() -> void:
	player.visible = false
	playing = false
	ended = false
	menu_panel.visible = true
	status_label.text = ""
	mode_label.text = "SELECCIONA MODO"
	mission_objective.text = ""
	player.active = false
	if is_instance_valid(rival):
		rival.active = false
	refresh_hud()

func start_duel_mustafar() -> void:
	arena_name = "mustafar"
	start_mode("duelo")

# Muestra el escenario elegido y oculta el otro (las colisiones de la arena son comunes).
func apply_arena() -> void:
	var in_mustafar := arena_name == "mustafar"
	base_visuals.visible = not in_mustafar
	for mesh in wall_meshes:
		mesh.visible = not in_mustafar
	if has_node("HangarDecoracion"):
		get_node("HangarDecoracion").visible = not in_mustafar
	if in_mustafar and not is_instance_valid(mustafar):
		mustafar = MustafarScript.new()
		add_child(mustafar)
		mustafar.call("build", environment, sun_light)

func start_mode(selected_mode: String) -> void:
	mode = selected_mode
	if mode == "historia":
		arena_name = "hangar"
	apply_arena()
	stage = 1
	playing = true
	ended = false
	menu_panel.visible = false
	status_label.text = ""
	player.max_health = 100.0
	player.health = 100.0
	player.stamina = 100.0
	player.energy = 100.0
	player.dead = false
	player.style = int(Characters.get_data(selected_hero)["style"])
	player.attack_pending = false
	player.combo = 0
	player.stun_time = 0.0
	player.knockdown_time = 0.0
	player.guarding = false
	player.active = true
	player.visible = true
	player.position = Vector3(0, 1.08, 6.0 if mode == "historia" else 4.5)
	player.call("apply_character", selected_hero)
	player.opponent = null
	player.targets.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.active = false
			enemy.opponent = null
			enemy.queue_free()
	enemies.clear()
	rival = null
	exit_unlocked = false
	hero_label.text = ("J1: " if mode == "versus" else "") + Characters.display_name(selected_hero)
	if mode == "historia":
		spawn_hangar_mission()
		rival_label.text = "DROIDES"
	else:
		if arena_name == "hangar":
			create_hangar_props()
		if mode == "versus":
			versus_wins = [0, 0]
			versus_round = 1
			spawn_player2()
		else:
			spawn_rival()
		rival_label.text = ("J2: " if mode == "versus" else "") + Characters.display_name(selected_rival)
	var intro := "DUELO: DERROTA AL RIVAL | " + difficulty_name()
	if mode == "historia":
		intro = "MISION: ELIMINA LOS DROIDES | " + difficulty_name()
	elif mode == "versus":
		intro = "RONDA 1 - ¡LUCHAD!"
	elif arena_name == "mustafar" and selected_hero in ["anakin", "obiwan"] and selected_rival in ["anakin", "obiwan"]:
		intro = "MUSTAFAR: ¡TE HAS VUELTO CONTRA MI!"
	show_tip(intro)

func spawn_rival() -> void:
	if is_instance_valid(rival):
		rival.active = false
		if is_instance_valid(player):
			player.opponent = null
		rival.queue_free()
	rival = FighterScript.new()
	rival.is_player = false
	rival.player_character = selected_rival
	rival.style = (stage - 1) % 3 if mode == "historia" else int(Characters.get_data(selected_rival)["style"])
	rival.position = Vector3(0, 1.08, -4.5)
	add_child(rival)
	rival.ai_difficulty = difficulty
	rival.aim_strength = [0.3, 0.5, 0.7, 0.85, 1.0][difficulty - 1]
	# Mas vida y menos dano recibido: encuentros largos sin convertir la IA en invencible.
	# La fase de Historia sigue aumentando la resistencia del jefe.
	rival.max_health = (135.0 + 25.0 * float(stage)) * [0.85, 1.0, 1.15, 1.35, 1.60][difficulty - 1]
	rival.health = rival.max_health
	rival.ai_damage_resistance = [0.0, 0.06, 0.12, 0.19, 0.25][difficulty - 1]
	rival.ai_recovery_rate = [0.0, 0.0, 0.7, 1.1, 1.6][difficulty - 1]
	rival.ai_recovery_delay = 4.5
	rival.ai_second_wind = difficulty >= 4
	rival.ai_second_wind_used = false
	rival.enemy_attack_delay = (1.6 - minf(0.55, float(stage - 1) * 0.25)) * [1.35, 1.16, 1.0, 0.80, 0.67][difficulty - 1]
	rival.active = true
	player.opponent = rival
	player.targets.clear()
	player.targets.append(rival)
	rival.opponent = player
	rival.health_changed.connect(refresh_hud)
	rival.action_message.connect(show_tip)
	rival.defeated.connect(on_rival_defeated)
	mode_label.text = (("HISTORIA %d/3 | %s" % [stage, rival.style_name()]) if mode == "historia" else ("DUELO | RIVAL %s" % rival.style_name())) + " | " + difficulty_name()
	refresh_hud()

# Segundo jugador humano: mismas reglas y vida que el jugador 1.
func spawn_player2() -> void:
	if is_instance_valid(rival):
		rival.queue_free()
	rival = FighterScript.new()
	rival.is_player = true
	rival.player_index = 2
	rival.input_prefix = "p2_"
	rival.player_character = selected_rival
	rival.style = int(Characters.get_data(selected_rival)["style"])
	rival.aim_strength = 1.0
	rival.position = Vector3(0, 1.08, -4.5)
	rival.rotation.y = PI
	add_child(rival)
	rival.max_health = 100.0
	rival.health = 100.0
	rival.active = true
	player.opponent = rival
	player.targets.clear()
	player.targets.append(rival)
	rival.opponent = player
	rival.targets.append(player)
	rival.health_changed.connect(refresh_hud)
	rival.resources_changed.connect(refresh_hud)
	rival.action_message.connect(show_tip)
	rival.defeated.connect(on_rival_defeated)
	update_versus_label()
	refresh_hud()

func update_versus_label() -> void:
	mode_label.text = "VERSUS | RONDA %d | J1 %d - %d J2" % [versus_round, versus_wins[0], versus_wins[1]]

func versus_round_end(winner: int) -> void:
	if ended or not playing:
		return
	versus_wins[winner - 1] += 1
	update_versus_label()
	var winner_name: String = Characters.display_name(selected_hero if winner == 1 else selected_rival)
	if versus_wins[winner - 1] >= 2:
		ended = true
		playing = false
		player.active = false
		rival.active = false
		status_label.text = "¡GANA JUGADOR %d - %s!  R REINICIAR" % [winner, winner_name]
		show_tip("FIN DEL VERSUS")
		return
	status_label.text = "RONDA PARA JUGADOR %d - %s" % [winner, winner_name]
	# Pausa real (ignora la camara lenta del KO) y nueva ronda.
	await get_tree().create_timer(3.0, true, false, true).timeout
	if ended or mode != "versus" or not is_instance_valid(rival):
		return
	versus_round += 1
	status_label.text = ""
	player.call("revive", Vector3(0, 1.08, 4.5), 0.0)
	rival.call("revive", Vector3(0, 1.08, -4.5), PI)
	update_versus_label()
	refresh_hud()
	show_tip("RONDA %d - ¡LUCHAD!" % versus_round)

func on_rival_defeated() -> void:
	if mode == "versus":
		versus_round_end(1)
	elif not ended:
		finish_game(true)

func on_player_defeated() -> void:
	if mode == "versus":
		versus_round_end(2)
	else:
		finish_game(false)

func finish_game(won: bool) -> void:
	ended = true
	playing = false
	player.active = false
	if is_instance_valid(rival):
		rival.active = false
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.active = false
	status_label.text = "VICTORIA - R REINICIAR" if won else "DERROTA - R REINICIAR"
	show_tip("MISIÓN 01 COMPLETADA" if won and mode == "historia" else "FIN DEL COMBATE")

func show_tip(message: String) -> void:
	if not is_instance_valid(tip_label):
		return
	tip_label.text = message
	tip_timer = 1.4
	if message.contains("IMPACTO") or message.contains("CHOQUE") or message.contains("PARADA"):
		camera_impact = maxf(camera_impact, 0.75)
	elif message.contains("DERRIBADO") or message.contains("EMPUJE"):
		camera_impact = maxf(camera_impact, 1.0)

func refresh_hud() -> void:
	if is_instance_valid(player) and is_instance_valid(player_bar):
		player_bar.max_value = player.max_health
		player_bar.value = player.health
		stamina_bar.value = player.stamina
		energy_bar.value = player.energy
	if mode == "historia" and is_instance_valid(rival_bar):
		rival_bar.max_value = 5.0
		rival_bar.value = mission_enemies_remaining
	elif is_instance_valid(rival) and is_instance_valid(rival_bar):
		rival_bar.max_value = rival.max_health
		rival_bar.value = rival.health
	elif is_instance_valid(rival_bar):
		rival_bar.value = 0


# Primera mision 3D, inspirada en el abordaje del crucero.
# Los personajes y objetos de esta demo son figuras primitivas originales.
func spawn_hangar_mission() -> void:
	mode_label.text = "HISTORIA 01 | INVISIBLE HAND | " + difficulty_name()
	mission_objective.text = "OBJETIVO: 5 DROIDES | Desvia disparos con L1/L2"
	mission_enemies_remaining = 5
	create_hangar_props()
	var positions: Array[Vector3] = [Vector3(-7.0, 1.08, -3.0), Vector3(-3.0, 1.08, -6.0), Vector3(3.5, 1.08, -5.0), Vector3(7.0, 1.08, -2.0), Vector3(0.0, 1.08, -7.0)]
	for i in range(5):
		var droid: CharacterBody3D = FighterScript.new()
		droid.is_player = false
		droid.unit_type = "b2" if i == 4 else "b1"
		droid.position = positions[i]
		add_child(droid)
		droid.name = "Superdroide_B2" if i == 4 else "Droide_B1_%d" % (i + 1)
		droid.ai_difficulty = difficulty
		droid.aim_strength = [0.3, 0.5, 0.7, 0.85, 1.0][difficulty - 1]
		droid.max_health = (85.0 if i == 4 else 30.0) * [0.90, 1.0, 1.1, 1.25, 1.4][difficulty - 1]
		droid.health = droid.max_health
		droid.ai_damage_resistance = 0.10 if i == 4 else 0.0
		droid.ai_second_wind = false
		droid.opponent = player
		droid.active = true
		droid.health_changed.connect(refresh_hud)
		droid.action_message.connect(show_tip)
		# La muerte puede producirse dentro de un empuje multiple.
		# Cambiar objetivos al terminar el fotograma evita referencias obsoletas.
		droid.defeated.connect(on_droid_defeated_deferred.bind(droid))
		enemies.append(droid)
		player.targets.append(droid)
	rival = enemies[0]
	player.opponent = rival
	refresh_hud()

func on_droid_defeated_deferred(droid: CharacterBody3D) -> void:
	call_deferred("on_droid_defeated", droid)

func on_droid_defeated(_droid: CharacterBody3D) -> void:
	if ended or mode != "historia":
		return
	# Elimina el derrotado de la lista de objetivos del personaje.
	if is_instance_valid(player):
		player.cleanup_targets()
	mission_enemies_remaining = maxi(0, mission_enemies_remaining - 1)
	mission_objective.text = "OBJETIVO: DROIDES RESTANTES %d / 5" % mission_enemies_remaining
	show_tip("¡DROIDE DESTRUIDO! QUEDAN %d" % mission_enemies_remaining)
	if mission_enemies_remaining == 0:
		exit_unlocked = true
		mission_objective.text = "¡SALIDA ABIERTA! VE A LA PUERTA DEL FONDO (Z = -9)"
		show_tip("¡HANGAR DESPEJADO! ALCANZA LA SALIDA")
	else:
		if is_instance_valid(player):
			var next_enemy: CharacterBody3D = player.nearest_target()
			if is_instance_valid(next_enemy):
				rival = next_enemy
				player.opponent = next_enemy
			else:
				rival = null
				player.opponent = null
	refresh_hud()

# Primer escenario de producción: geometría modular, luces y cobertura.
# Todos los elementos son originales creados mediante primitivas de Godot.
func add_light_to(parent: Node3D, location: Vector3, color: Color, power: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = location
	lamp.light_color = color
	lamp.light_energy = power
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	parent.add_child(lamp)

func create_hangar_props() -> void:
	if has_node("HangarDecoracion"):
		return
	var hangar := Node3D.new()
	hangar.name = "HangarDecoracion"
	add_child(hangar)
	# Piso mecanizado: placas, carriles de aterrizaje y luz direccional.
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		mesh_box(hangar, Vector3(0.075, 0.05, 21.0), Vector3(x, 0.045, 0), Color(0.13, 0.35, 0.44), true)
	for z in [-9.5, -5.5, -1.5, 2.5, 6.5, 9.5]:
		mesh_box(hangar, Vector3(21.0, 0.06, 0.10), Vector3(0, 0.055, z), Color(0.14, 0.20, 0.29))
	# Costillas estructurales laterales y techo industrial.
	for z in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for x in [-10.8, 10.8]:
			mesh_box(hangar, Vector3(0.52, 6.8, 0.65), Vector3(x, 3.1, z), Color(0.24, 0.31, 0.40))
			mesh_box(hangar, Vector3(0.21, 4.1, 0.72), Vector3(x * 0.94, 3.0, z), Color(0.10, 0.47, 0.65), true)
		mesh_box(hangar, Vector3(22.0, 0.42, 0.64), Vector3(0, 6.7, z), Color(0.27, 0.35, 0.45))
		mesh_box(hangar, Vector3(17.0, 0.11, 0.30), Vector3(0, 6.45, z), Color(0.06, 0.55, 0.79), true)
	# Paneles del techo: no obstaculizan el salto alto.
	for x in [-7.0, -3.5, 3.5, 7.0]:
		for z in [-7.0, 0.0, 7.0]:
			mesh_box(hangar, Vector3(1.7, 0.10, 1.2), Vector3(x, 6.35, z), Color(0.86, 0.92, 1.0), true)
			add_light_to(hangar, Vector3(x, 5.5, z), Color(0.50, 0.72, 1.0), 0.42, 7.0)
	# Contenedores de carga laterales, con barreras físicas.
	for x in [-8.5, 8.5]:
		for z in [-6.8, -0.8, 5.8]:
			mesh_box(hangar, Vector3(1.6, 1.5, 1.45), Vector3(x, 0.78, z), Color(0.30, 0.36, 0.43))
			mesh_box(hangar, Vector3(1.34, 0.08, 1.22), Vector3(x, 1.56, z), Color(0.93, 0.55, 0.14), true)
			mesh_box(hangar, Vector3(0.14, 1.4, 1.48), Vector3(x - 0.63, 0.79, z), Color(0.08, 0.17, 0.24))
			mesh_box(hangar, Vector3(0.14, 1.4, 1.48), Vector3(x + 0.63, 0.79, z), Color(0.08, 0.17, 0.24))
	# Consolas laterales con hologramas y monitores brillantes.
	for x in [-9.75, 9.75]:
		for z in [-3.5, 3.5]:
			mesh_box(hangar, Vector3(0.82, 1.25, 1.8), Vector3(x, 0.65, z), Color(0.12, 0.17, 0.24))
			mesh_box(hangar, Vector3(0.06, 0.62, 1.37), Vector3(x + (0.45 if x < 0 else -0.45), 1.05, z), Color(0.10, 0.78, 0.88), true)
	# Puerta del fondo, luces verdes al despejar los droides.
	mesh_box(hangar, Vector3(5.6, 5.4, 0.28), Vector3(0, 2.6, -11.12), Color(0.10, 0.14, 0.21))
	mesh_box(hangar, Vector3(4.55, 3.8, 0.13), Vector3(0, 1.85, -10.90), Color(0.22, 0.29, 0.38))
	mesh_box(hangar, Vector3(5.5, 0.24, 0.30), Vector3(0, 4.8, -10.8), Color(0.95, 0.48, 0.14), true)
	for x in [-2.65, 2.65]:
		mesh_box(hangar, Vector3(0.15, 4.4, 0.24), Vector3(x, 2.4, -10.82), Color(0.94, 0.47, 0.09), true)
	mesh_box(hangar, Vector3(2.2, 0.075, 2.1), Vector3(0, 0.07, -9.0), Color(0.14, 0.95, 0.46), true)
	add_light_to(hangar, Vector3(0, 4.3, -9.8), Color(0.20, 0.94, 0.74), 1.0, 8.0)
	build_cinematic_hangar(hangar)
	# Hangar de despegue: marcadores de entrada y zona de aterrizaje.
	mesh_box(hangar, Vector3(7.4, 0.05, 0.22), Vector3(0, 0.08, 8.4), Color(0.96, 0.58, 0.12), true)
	for x in [-3.2, 3.2]:
		mesh_box(hangar, Vector3(0.11, 0.04, 3.5), Vector3(x, 0.09, 6.9), Color(0.96, 0.58, 0.12), true)

# v0.6 - Diseño modular original inspirado en un crucero espacial.
# Elementos decorativos sin colision para mantener el combate y el mando PS4.
func build_cinematic_hangar(hangar: Node3D) -> void:
	var steel := Color(0.12, 0.17, 0.22)
	var trim := Color(0.27, 0.34, 0.41)
	var dark := Color(0.055, 0.075, 0.11)
	var amber := Color(0.98, 0.36, 0.09)
	var blue := Color(0.14, 0.52, 0.74)
	# Rejillas de cubierta y placas individuales.
	for ix in range(-10, 11, 2):
		for iz in range(-10, 11, 2):
			mesh_box(hangar, Vector3(1.84, 0.018, 1.83), Vector3(float(ix), 0.041, float(iz)), steel)
			mesh_box(hangar, Vector3(1.55, 0.019, 0.035), Vector3(float(ix), 0.052, float(iz)-0.78), trim)
			mesh_box(hangar, Vector3(0.035, 0.019, 1.57), Vector3(float(ix)-0.79, 0.052, float(iz)), trim)
	# Dos corredores elevados laterales que dan escala al interior.
	for side in [-1.0, 1.0]:
		var x: float = side * 10.35
		mesh_box(hangar, Vector3(1.35, 0.25, 20.4), Vector3(x, 3.24, 0), trim)
		for iz in range(-9, 10, 2):
			var z := float(iz)
			mesh_box(hangar, Vector3(0.13, 1.1, 0.14), Vector3(x-side*0.62, 3.9, z), trim)
			mesh_box(hangar, Vector3(0.11, 0.10, 2.0), Vector3(x-side*0.62, 4.46, z), blue, true)
			mesh_box(hangar, Vector3(0.10, 3.3, 0.11), Vector3(x, 1.55, z), dark)
		# Conductos paralelos al techo.
		for y in [5.55, 5.92]:
			mesh_box(hangar, Vector3(0.22, 0.22, 20.5), Vector3(side*9.1, y, 0), dark)
			for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
				mesh_box(hangar, Vector3(0.36, 0.36, 0.18), Vector3(side*9.1, y, z), trim)
	# Cerchas, armaduras y cruces de mantenimiento.
	for z in [-8.5, -4.25, 0.0, 4.25, 8.5]:
		mesh_box(hangar, Vector3(17.7, 0.18, 0.24), Vector3(0, 5.86, z), trim)
		for x in [-7.7, 7.7]:
			mesh_box(hangar, Vector3(0.26, 1.0, 0.26), Vector3(x, 5.45, z), steel)
		for x in [-5.5, -2.75, 0.0, 2.75, 5.5]:
			mesh_box(hangar, Vector3(0.08, 0.08, 0.34), Vector3(x, 5.72, z), amber, true)
	# Porton de servicio blindado y paneles industriales segmentados.
	for side in [-1.0, 1.0]:
		for y in [0.7, 1.6, 2.5, 3.4, 4.3]:
			mesh_box(hangar, Vector3(2.1, 0.09, 0.24), Vector3(side*3.85, y, -10.86), trim)
	for z in [-9.7, 9.7]:
		for x in [-6.0, -3.0, 3.0, 6.0]:
			mesh_box(hangar, Vector3(1.8, 0.08, 0.18), Vector3(x, 0.13, z), amber, true)
	# Grúas de carga y aparatos mecánicos suspendidos.
	for x in [-6.9, 6.9]:
		mesh_box(hangar, Vector3(1.5, 0.24, 5.0), Vector3(x, 5.3, 1.3), trim)
		mesh_box(hangar, Vector3(0.17, 2.1, 0.16), Vector3(x, 4.2, 0.0), dark)
		mesh_box(hangar, Vector3(1.3, 0.17, 1.3), Vector3(x, 3.15, 0), trim)
		for sx in [-0.45, 0.45]:
			mesh_box(hangar, Vector3(0.09, 0.7, 0.12), Vector3(x+sx, 2.8, 0), amber)
	# Maquinaria de refrigeracion y franjas visuales de peligro.
	for x in [-9.0, 9.0]:
		for z in [-7.8, 2.2, 7.8]:
			mesh_box(hangar, Vector3(0.88, 1.1, 1.55), Vector3(x, 0.56, z), dark)
			for k in range(4):
				mesh_box(hangar, Vector3(0.94, 0.09, 0.14), Vector3(x, 0.2+float(k)*0.26, z), trim)
			mesh_box(hangar, Vector3(0.96, 0.07, 1.6), Vector3(x, 1.16, z), amber, true)
	# Proyectores frios y balizas de emergencia.
	for x in [-8.0, 0.0, 8.0]:
		add_light_to(hangar, Vector3(x, 5.5, 4.5), Color(0.30, 0.57, 0.95), 0.8, 9.0)
	for x in [-9.0, 9.0]:
		for z in [-8.0, 0.0, 8.0]:
			mesh_box(hangar, Vector3(0.28, 0.15, 0.28), Vector3(x, 3.2, z), amber, true)
	# Decoracion no interactiva al fondo: siluetas de naves de apoyo.
	for x in [-5.5, 5.5]:
		var ship := Node3D.new()
		ship.position = Vector3(x, 0.56, 8.75)
		hangar.add_child(ship)
		mesh_box(ship, Vector3(1.65, 0.28, 2.15), Vector3(0, 0.32, 0), trim)
		mesh_box(ship, Vector3(0.9, 0.25, 1.15), Vector3(0, 0.67, -0.32), dark)
		mesh_box(ship, Vector3(3.25, 0.12, 0.7), Vector3(0, 0.37, 0.35), steel)
		mesh_box(ship, Vector3(0.3, 0.15, 0.12), Vector3(0, 0.28, 1.12), blue, true)
