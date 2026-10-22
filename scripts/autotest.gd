extends Node
# Prueba automatica: solo se activa con "-- --autotest <carpeta>".
# Inicia un duelo, simula entradas y guarda capturas para revisar la escena.

var game: Node
var out_dir: String = ""
var clock: float = 0.0
var step: int = 0
var mode: String = "duelo"

const SCRIPT_STEPS := [
	[0.4, "shot:00_menu"],
	[0.6, "start"],
	[0.7, "wide"],
	[2.0, "shot:00_plano_general"],
	[2.05, "unwide"],
	[2.6, "shot:01_duelo"],
	[2.4, "press:move_forward"],
	[3.0, "release:move_forward"],
	[3.05, "tap:attack"],
	[3.2, "shot:02_ataque_a"],
	[3.35, "shot:02_ataque_b"],
	[3.5, "tap:attack"],
	[3.75, "shot:03_combo"],
	[4.4, "press:block"],
	[4.8, "shot:04_bloqueo"],
	[5.0, "shot:04_bloqueo_b"],
	[5.2, "shot:04_bloqueo_c"],
	[5.4, "shot:04_bloqueo_d"],
	[5.6, "shot:04_bloqueo_e"],
	[5.8, "shot:04_bloqueo_f"],
	[6.2, "shot:05_bloqueo_g"],
	[6.4, "release:block"],
	[6.6, "tap:force_push"],
	[6.9, "shot:06_empuje"],
	[7.6, "clash"],
	[7.66, "shot:08_chispas"],
	[8.5, "shot:07_final"],
	[8.6, "probe"],
	[8.7, "press:p2_move_back"],
	[9.5, "release:p2_move_back"],
	[9.55, "probe"],
	[9.6, "tap:p2_attack"],
	[9.8, "shot:09_j2_ataca"],
	[10.0, "versus_ko"],
	[10.4, "shot:10_ko"],
	[10.6, "probe"],
	[14.5, "shot:11_ronda2"],
	[14.6, "probe"],
	[15.0, "quit"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	clock += delta
	while step < SCRIPT_STEPS.size() and clock >= SCRIPT_STEPS[step][0]:
		run(String(SCRIPT_STEPS[step][1]))
		step += 1

func run(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"start":
			if mode == "mustafar":
				game.call("start_duel_mustafar")
			elif mode == "versus":
				game.set("selected_hero", "vader")
				game.set("selected_rival", "maul")
				game.call("start_versus")
			else:
				game.call("start_mode", mode)
		"wide":
			game.set("playing", false)
		"unwide":
			game.set("playing", true)
		"clash":
			var pl: Node = game.get("player")
			pl.set("clash_cooldown", 0.0)
			pl.call("show_blade_clash")
			print("CHOQUE FORZADO OK")
		"probe":
			var r: Node3D = game.get("rival")
			if is_instance_valid(r):
				print("SONDA j2_pos=", r.global_position, " j2_vida=", r.get("health"), " j2_muerto=", r.get("dead"), " marcador=", game.get("versus_wins"), " ronda=", game.get("versus_round"))
		"versus_ko":
			if mode == "versus":
				var r2: Node = game.get("rival")
				r2.call("receive_damage", 999.0, Vector3(0, 0, -1))
		"press":
			Input.action_press(parts[1])
		"release":
			Input.action_release(parts[1])
		"tap":
			Input.action_press(parts[1])
			get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release(parts[1]))
		"shot":
			var img := get_viewport().get_texture().get_image()
			img.save_png(out_dir.path_join(parts[1] + ".png"))
			print("CAPTURA ", parts[1])
		"quit":
			get_tree().quit()
