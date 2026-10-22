extends Node
# Sonidos sintetizados al arrancar (sin archivos de audio): zumbido del sable,
# tajos, choques, quemaduras, encendido/apagado, empuje de la Fuerza y blaster.
# Uso: get_tree().get_first_node_in_group("sfx").play("clash")

const RATE := 22050
var streams: Dictionary = {}

func _ready() -> void:
	add_to_group("sfx")
	streams["hum"] = _make(1.0, _hum, true)
	streams["swing"] = _make(0.38, _swing)
	streams["clash"] = _make(0.7, _clash)
	streams["hit"] = _make(0.55, _hit)
	streams["ignite"] = _make(0.55, _ignite)
	streams["retract"] = _make(0.5, _retract)
	streams["push"] = _make(0.9, _push)
	streams["blaster"] = _make(0.28, _blaster)

# Genera la onda muestra a muestra. Los bucles se precalientan un segundo para que
# el filtro empiece y termine en el mismo estado (sin chasquido al repetir).
func _make(seconds: float, gen: Callable, loop: bool = false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := {"lp": 0.0, "ph": 0.0, "ph2": 0.0}
	var offset := RATE if loop else 0
	for i in range(offset):
		gen.call(float(i) / RATE, seconds, state)
	for i in range(n):
		var v: float = gen.call(float(i + offset) / RATE if loop else float(i) / RATE, seconds, state)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s

static func _saw(f: float, t: float) -> float:
	return 2.0 * fposmod(f * t, 1.0) - 1.0

static func _noise() -> float:
	return randf() * 2.0 - 1.0

func _hum(t: float, _T: float, st: Dictionary) -> float:
	var raw := _saw(90.0, t) * 0.5 + _saw(91.0, t) * 0.35 + sin(TAU * 180.0 * t) * 0.25
	st["lp"] += (raw - st["lp"]) * 0.08
	return st["lp"] * (0.85 + 0.15 * sin(TAU * 7.0 * t)) * 1.3

func _swing(t: float, T: float, st: Dictionary) -> float:
	var env := pow(sin(PI * t / T), 1.5)
	st["lp"] += (_noise() - st["lp"]) * (0.03 + 0.22 * env)
	st["ph"] += (95.0 + 140.0 * env) / RATE
	var tone := (2.0 * fposmod(st["ph"], 1.0) - 1.0) * 0.18
	return (st["lp"] * 2.4 + tone) * env

func _clash(t: float, _T: float, st: Dictionary) -> float:
	var n := _noise()
	st["lp"] += (n - st["lp"]) * 0.3
	var crack: float = (n - st["lp"]) * exp(-t * 14.0)
	var ring := sin(TAU * 2150.0 * t) * exp(-t * 16.0) * 0.45 + sin(TAU * 1430.0 * t) * exp(-t * 7.0) * 0.22 + sin(TAU * 3170.0 * t) * exp(-t * 22.0) * 0.18
	var sizzle := _noise() * exp(-t * 5.0) * 0.22 * (0.5 + 0.5 * sin(TAU * 45.0 * t))
	return crack * 0.95 + ring + sizzle

func _hit(t: float, _T: float, st: Dictionary) -> float:
	st["lp"] += (_noise() - st["lp"]) * 0.22
	var burn: float = st["lp"] * 2.2 * (0.6 + 0.4 * sin(TAU * 33.0 * t)) * exp(-t * 4.5)
	st["ph"] += (120.0 - 70.0 * t) / RATE
	var thud := (2.0 * fposmod(st["ph"], 1.0) - 1.0) * exp(-t * 6.0) * 0.3
	return burn + thud

func _ignite(t: float, T: float, st: Dictionary) -> float:
	var env := minf(t * 12.0, 1.0) * exp(-t * 2.2)
	st["ph"] += (55.0 + 75.0 * t / T) / RATE
	var raw := (2.0 * fposmod(st["ph"], 1.0) - 1.0) + _noise() * 0.3 * (1.0 - t / T)
	st["lp"] += (raw - st["lp"]) * (0.05 + 0.2 * t / T)
	return st["lp"] * env * 1.6

func _retract(t: float, T: float, st: Dictionary) -> float:
	var env := exp(-t * 5.0)
	st["ph"] += (125.0 - 85.0 * t / T) / RATE
	var raw := (2.0 * fposmod(st["ph"], 1.0) - 1.0) + _noise() * 0.25
	st["lp"] += (raw - st["lp"]) * (0.25 - 0.2 * t / T)
	return st["lp"] * env * 1.5

func _push(t: float, T: float, st: Dictionary) -> float:
	var env := sin(PI * t / T)
	st["lp"] += (_noise() - st["lp"]) * 0.02
	st["ph"] += (70.0 - 35.0 * t / T) / RATE
	return (st["lp"] * 5.0 + sin(TAU * st["ph"]) * 0.5) * env

func _blaster(t: float, _T: float, st: Dictionary) -> float:
	st["ph"] += (1900.0 * exp(-t * 9.0) + 250.0) / RATE
	return sin(TAU * st["ph"]) * exp(-t * 10.0) * 0.8

func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Zumbido continuo pegado al sable (sonido 3D: se oye por donde esta el personaje).
func make_hum(parent: Node3D, base_pitch: float = 1.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams["hum"]
	p.unit_size = 7.0
	p.volume_db = -80.0
	p.pitch_scale = base_pitch
	parent.add_child(p)
	p.play()
	return p
