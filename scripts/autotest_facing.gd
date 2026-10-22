extends Node
# Prueba del encaramiento: el jugador se aleja dando la espalda al rival y se mide
# hacia donde mira cada vez que el rival le ataca. Se activa con "-- --autotest-facing".

var game: Node
var clock: float = 0.0
var samples_attacking: int = 0
var samples_facing: int = 0
var worst_dot: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	clock += delta
	if clock > 0.5 and clock - delta <= 0.5:
		game.call("start_duel_mustafar")
	if clock < 1.0:
		return
	var player: Node3D = game.get("player")
	var rival: Node3D = game.get("rival")
	if not is_instance_valid(rival):
		return
	# Caminar alternando direcciones para quedar a menudo de espaldas al rival.
	var phase := int(clock * 0.8) % 3
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press(["move_back", "move_left", "move_right"][phase])
	if rival.get("attack_pending"):
		var to_rival: Vector3 = rival.global_position - player.global_position
		to_rival.y = 0.0
		var dot: float = (-player.global_transform.basis.z).dot(to_rival.normalized())
		samples_attacking += 1
		# Al llegar el impacto (impact_timer casi agotado) debe estar de frente.
		if float(rival.get("impact_timer")) < 0.05:
			worst_dot = minf(worst_dot, dot)
			if dot > 0.10:
				samples_facing += 1
			else:
				print("NO ENCARADO dot=", dot)
	if clock > 14.0:
		print("RESULTADO muestras_ataque=", samples_attacking, " impactos_encarados=", samples_facing, " peor_dot=", worst_dot)
		get_tree().quit()
