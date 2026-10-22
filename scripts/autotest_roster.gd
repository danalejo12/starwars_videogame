extends Node
# Galeria del plantel: coloca a los 10 personajes en dos tandas de 5 frente a la camara
# en Mustafar y guarda una captura de cada tanda. Se activa con "-- --autotest-roster <carpeta>".

const Characters = preload("res://scripts/characters.gd")
const JediRigScript = preload("res://scripts/jedi_rig.gd")
var game: Node
var out_dir: String = ""
var clock: float = 0.0
var rigs: Array = []
var batch: int = -1
var cam: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	clock += delta
	if batch == -1 and clock > 0.5:
		game.set("arena_name", "mustafar")
		game.call("apply_arena")
		(game.get("menu_panel") as Control).visible = false
		(game.get("player") as Node3D).visible = false
		cam = Camera3D.new()
		cam.fov = 46.0
		game.add_child(cam)
		cam.global_position = Vector3(0, 1.5, 8.6)
		cam.look_at(Vector3(0, 0.95, 0))
		cam.current = true
		show_batch(0)
	for r in rigs:
		r.call("tick", delta, Vector3.ZERO, false, "idle", false)
	if batch == 0 and clock > 3.0:
		save("roster_1")
		show_batch(1)
	elif batch == 1 and clock > 5.5:
		save("roster_2")
		get_tree().quit()

func show_batch(index: int) -> void:
	for r in rigs:
		r.queue_free()
	rigs.clear()
	batch = index
	for i in range(5):
		var key: String = Characters.ORDER[index * 5 + i]
		var rig: Node3D = JediRigScript.new()
		game.add_child(rig)
		rig.position = Vector3(-4.4 + i * 2.2, 0.0, 0.0)
		rig.scale = Vector3.ONE * 1.12 * float(Characters.get_data(key)["scale"])
		rig.call("setup", key)
		rigs.append(rig)
		print("PERSONAJE ", key)

func save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("CAPTURA ", name)
