extends Node
# Prueba del aimbot: el rival aparece a la espalda o al costado del jugador, a 3-4.5 m,
# sin defenderse ni atacar. Se cuentan los tajos que impactan con aimbot activado y
# desactivado. Se activa con "-- --autotest-aim".

var game: Node
var clock: float = 0.0
var trial: int = 0
var trial_clock: float = 0.0
var hits := {true: 0, false: 0}
var tries := {true: 0, false: 0}
var health_before: float = 0.0
const TRIALS_PER_MODE := 12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	clock += delta
	if clock < 0.5:
		return
	if trial == 0 and trial_clock == 0.0:
		game.call("start_duel_mustafar")
	var player: Node3D = game.get("player")
	var rival: Node3D = game.get("rival")
	if not is_instance_valid(rival):
		return
	# Rival pasivo: ni bloquea ni ataca.
	rival.set("stamina", 0.0)
	rival.set("guarding", false)
	rival.set("guard_commit", 0.0)
	rival.set("enemy_attack_delay", 99.0)
	rival.set("force_cooldown", 99.0)
	var aim_on: bool = trial < TRIALS_PER_MODE
	trial_clock += delta
	if trial_clock < 0.02:
		return
	if trial_clock < 0.1:
		# Colocar: jugador mirando a -Z, rival detras o al costado.
		player.set("lock_enabled", aim_on)
		player.set("lock_target", null)
		player.set("attack_cooldown", 0.0)
		player.set("stamina", 100.0)
		player.global_position = Vector3(0, 1.0, 2.0)
		player.rotation.y = 0.0
		var ang: float = PI * 0.5 + randf() * PI  # de lado a espalda
		var dist: float = randf_range(3.0, 4.5)
		rival.global_position = Vector3(sin(ang) * dist, 1.0, 2.0 - cos(ang) * dist)
		rival.set("knockback", Vector3.ZERO)
		rival.set("health", 1000.0)
		rival.set("max_health", 1000.0)
		rival.set("velocity", Vector3.ZERO)
		return
	if trial_clock >= 0.1 and trial_clock - delta < 0.1:
		health_before = float(rival.get("health"))
		player.call("attack")
	if trial_clock > 0.9:
		tries[aim_on] += 1
		if float(rival.get("health")) < health_before:
			hits[aim_on] += 1
		trial += 1
		trial_clock = 0.0
		if trial >= TRIALS_PER_MODE * 2:
			print("RESULTADO aimbot_on=", hits[true], "/", tries[true], " aimbot_off=", hits[false], "/", tries[false])
			get_tree().quit()
