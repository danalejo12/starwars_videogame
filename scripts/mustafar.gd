extends Node3D
# Escenario de Mustafar: plataforma del complejo minero sobre un mar de lava.
# Todo se genera con primitivas y shaders de Godot (sin modelos externos).
# La zona jugable coincide con el suelo y los muros invisibles de la arena (24 x 24).

const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float flow = 0.0;
uniform float scale = 0.06;
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++){ v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = flow > 0.5 ? vec2(UV.x * 5.0, UV.y * 8.0 + TIME * 1.3) : wpos.xz * scale;
	float t = TIME * 0.05;
	float a = fbm(p + vec2(t, t * 0.7));
	float b = fbm(p * 2.2 - vec2(t * 1.3, -t) + a * 1.5);
	float v = clamp(a * 0.6 + b * 0.6, 0.0, 1.0);
	float crust = smoothstep(0.45, 0.66, v);
	vec3 c = mix(vec3(1.5, 0.42, 0.05), vec3(0.05, 0.012, 0.006), crust);
	c = mix(c, vec3(2.0, 1.2, 0.35), smoothstep(0.36, 0.2, v) * 0.8);
	ALBEDO = c;
}
"""

const SKY_SHADER := """
shader_type sky;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++){ v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
void sky(){
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 top = vec3(0.045, 0.012, 0.012);
	vec3 hor = vec3(0.95, 0.30, 0.07);
	vec3 low = vec3(0.30, 0.06, 0.01);
	vec3 c = y > 0.0 ? mix(hor, top, pow(clamp(y, 0.0, 1.0), 0.42)) : mix(hor, low, clamp(-y * 4.0, 0.0, 1.0));
	// Humo volcanico que cruza el cielo lentamente
	vec2 uv = d.xz / (abs(y) + 0.22);
	float smoke = fbm(uv * 1.3 + vec2(TIME * 0.012, TIME * 0.004));
	c = mix(c, c * 0.3, smoothstep(0.42, 0.78, smoke) * smoothstep(0.02, 0.35, y));
	c += hor * 0.55 * exp(-abs(y) * 11.0);
	COLOR = c;
}
"""

var burst_timer: float = 0.0
var lava_lights: Array[OmniLight3D] = []
var clock: float = 0.0

func build(env: Environment, sun: DirectionalLight3D) -> void:
	name = "Mustafar"
	_setup_environment(env, sun)
	_build_lava()
	_build_platform()
	_build_surroundings()
	_build_particles()

# ---------------------------------------------------------------- ayudas
func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _glow(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _light(pos: Vector3, color: Color, energy: float, reach: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = shadows
	add_child(l)
	return l

# ---------------------------------------------------------------- cielo, niebla, luz
func _setup_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var sky_mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky_mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.2, 0.15)
	env.ambient_light_energy = 0.38
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.09, 0.035)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.25
	env.glow_hdr_threshold = 0.9
	# Sol velado por la ceniza: luz baja y anaranjada con sombras largas
	sun.light_color = Color(1.0, 0.58, 0.34)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-28, 38, 0)
	sun.shadow_enabled = true
	# Rebote de la lava desde abajo: ilumina barbillas, mangas y la parte baja de los sables
	var bounce := DirectionalLight3D.new()
	bounce.light_color = Color(1.0, 0.35, 0.08)
	bounce.light_energy = 0.45
	bounce.rotation_degrees = Vector3(70, 0, 0)
	add_child(bounce)

# ---------------------------------------------------------------- lava
func _lava_material(flow: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LAVA_SHADER
	m.shader = sh
	m.set_shader_parameter("flow", 1.0 if flow else 0.0)
	return m

func _build_lava() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	sea.mesh = plane
	sea.material_override = _lava_material(false)
	sea.position = Vector3(0, -7.0, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# Cascadas de lava que caen de los acantilados lejanos
	var falls := _lava_material(true)
	for data in [[Vector3(-70, 18, -95), 18.0], [Vector3(55, 20, -110), 26.0], [Vector3(110, 16, -30), 14.0], [Vector3(-120, 22, 20), 22.0]]:
		var f := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(data[1], 52)
		f.mesh = q
		f.material_override = falls
		add_child(f)
		f.position = data[0]
		f.look_at(Vector3(0, data[0].y, 0), Vector3.UP)
		f.rotate_object_local(Vector3.UP, PI)
		# Acantilado oscuro detras de la cascada
		var outward: Vector3 = Vector3(data[0].x, 0, data[0].z).normalized()
		var cliff := _box(self, Vector3(data[1] + 30.0, 60, 16), data[0] + outward * 9.0 + Vector3(0, -2, 0), _mat(Color(0.07, 0.045, 0.04), 0.95))
		cliff.look_at(Vector3(0, cliff.position.y, 0), Vector3.UP)
	# Luz de la lava bajo la plataforma
	for p in [Vector3(-13, -3.5, -13), Vector3(13, -3.5, -13), Vector3(-13, -3.5, 13), Vector3(13, -3.5, 13)]:
		lava_lights.append(_light(p, Color(1.0, 0.38, 0.08), 3.0, 16.0))

# ---------------------------------------------------------------- plataforma jugable
func _build_platform() -> void:
	var metal := _mat(Color(0.24, 0.22, 0.21), 0.5, 0.65)
	var noise_tex := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.035
	noise_tex.noise = fn
	noise_tex.seamless = true
	noise_tex.width = 512
	noise_tex.height = 512
	metal.albedo_texture = noise_tex
	metal.uv1_triplanar = true
	metal.uv1_scale = Vector3(0.12, 0.12, 0.12)
	var dark := _mat(Color(0.05, 0.05, 0.055), 0.6, 0.6)
	var orange := _glow(Color(1.0, 0.42, 0.08), 2.8)
	# Cubierta principal (la colision la aporta el suelo de la arena)
	_box(self, Vector3(24.2, 0.6, 24.2), Vector3(0, -0.31, 0), metal)
	# Juntas de las placas
	for i in range(-3, 4):
		_box(self, Vector3(0.06, 0.02, 23.6), Vector3(i * 3.4, 0.0, 0), dark)
		_box(self, Vector3(23.6, 0.02, 0.06), Vector3(0, 0.0, i * 3.4), dark)
	# Sello central con anillo incandescente
	_cyl(self, 4.2, 4.2, 0.04, Vector3(0, 0.01, 0), _mat(Color(0.08, 0.075, 0.075), 0.35, 0.85), 48)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.0
	torus.outer_radius = 4.12
	ring.mesh = torus
	ring.material_override = orange
	ring.scale = Vector3(1, 0.15, 1)
	ring.position = Vector3(0, 0.03, 0)
	add_child(ring)
	# Borde incandescente y barandillas en el limite jugable
	for s in [-1.0, 1.0]:
		_box(self, Vector3(24.2, 0.05, 0.12), Vector3(0, 0.0, s * 12.05), orange)
		_box(self, Vector3(0.12, 0.05, 24.2), Vector3(s * 12.05, 0.0, 0), orange)
		_box(self, Vector3(23.4, 0.07, 0.07), Vector3(0, 1.1, s * 11.65), dark)
		_box(self, Vector3(0.07, 0.07, 23.4), Vector3(s * 11.65, 1.1, 0), dark)
		_box(self, Vector3(23.4, 0.05, 0.05), Vector3(0, 0.6, s * 11.65), dark)
		_box(self, Vector3(0.05, 0.05, 23.4), Vector3(s * 11.65, 0.6, 0), dark)
		for k in range(-5, 6):
			_box(self, Vector3(0.09, 1.1, 0.09), Vector3(k * 2.3, 0.55, s * 11.65), dark)
			_box(self, Vector3(0.09, 1.1, 0.09), Vector3(s * 11.65, 0.55, k * 2.3), dark)
	# Torres de las esquinas con balizas
	for x in [-11.4, 11.4]:
		for z in [-11.4, 11.4]:
			_box(self, Vector3(1.1, 5.5, 1.1), Vector3(x, 2.75, z), dark)
			_box(self, Vector3(1.3, 0.2, 1.3), Vector3(x, 5.6, z), orange)
	_light(Vector3(-11.4, 6.3, -11.4), Color(1.0, 0.5, 0.2), 1.6, 12.0)
	_light(Vector3(11.4, 6.3, -11.4), Color(1.0, 0.5, 0.2), 1.6, 12.0)
	# Consolas de control con pantallas
	for x in [-6.5, 6.5]:
		var console := _box(self, Vector3(2.2, 1.15, 0.8), Vector3(x, 0.58, -10.6), dark)
		_box(console, Vector3(1.8, 0.45, 0.05), Vector3(0, 0.25, 0.42), _glow(Color(1.0, 0.55, 0.2), 1.6))
		for k in range(4):
			_box(console, Vector3(0.12, 0.08, 0.05), Vector3(-0.6 + k * 0.4, -0.18, 0.42), _glow([Color(1, 0.2, 0.1), Color(0.2, 1, 0.4), Color(1, 0.8, 0.2), Color(0.3, 0.6, 1)][k], 2.0))
	# Pilares de soporte que se hunden en la lava
	for p in [Vector3(-8, -4.2, -8), Vector3(8, -4.2, -8), Vector3(-8, -4.2, 8), Vector3(8, -4.2, 8), Vector3(0, -4.2, 0)]:
		_cyl(self, 1.3, 1.9, 7.4, p, dark, 10)
	# Tuberias bajo el borde
	for s in [-1.0, 1.0]:
		var pipe := _cyl(self, 0.28, 0.28, 26.0, Vector3(s * 12.6, -0.9, 0), dark, 12)
		pipe.rotation.x = PI / 2.0
	# Pasarela hacia un brazo colector (decorativa, fuera de la zona jugable)
	_box(self, Vector3(22, 0.3, 3.0), Vector3(23.5, -0.2, 3.0), metal)
	for k in range(6):
		_box(self, Vector3(0.08, 1.0, 0.08), Vector3(14.0 + k * 3.8, 0.5, 4.45), dark)
		_box(self, Vector3(0.08, 1.0, 0.08), Vector3(14.0 + k * 3.8, 0.5, 1.55), dark)
	_box(self, Vector3(22, 0.06, 0.06), Vector3(23.5, 1.0, 4.45), dark)
	_box(self, Vector3(22, 0.06, 0.06), Vector3(23.5, 1.0, 1.55), dark)

# ---------------------------------------------------------------- entorno lejano
func _build_surroundings() -> void:
	var rock := _mat(Color(0.075, 0.05, 0.045), 0.95)
	var dark_metal := _mat(Color(0.04, 0.04, 0.045), 0.55, 0.6)
	var window := _glow(Color(1.0, 0.62, 0.3), 2.2)
	# Centro de control del complejo minero, al fondo
	var center := Node3D.new()
	center.position = Vector3(0, 0, -34)
	add_child(center)
	_box(center, Vector3(30, 7, 9), Vector3(0, 0.5, 0), dark_metal)
	var roof := _box(center, Vector3(30, 1.2, 10.5), Vector3(0, 4.4, 0.4), dark_metal)
	roof.rotation.x = -0.12
	_box(center, Vector3(27, 1.0, 0.1), Vector3(0, 2.2, 4.56), window)
	_box(center, Vector3(8, 12, 7), Vector3(-9, 6, -3), dark_metal)
	_box(center, Vector3(7.4, 0.6, 0.1), Vector3(-9, 9.5, 0.56), window)
	_cyl(center, 0.25, 0.4, 10, Vector3(9, 9, -2), dark_metal, 8)
	_box(center, Vector3(0.6, 0.6, 0.6), Vector3(9, 14.2, -2), _glow(Color(1, 0.2, 0.1), 3.0))
	for x in [-12.0, -4.0, 4.0, 12.0]:
		_cyl(center, 0.9, 1.4, 14, Vector3(x, -7.5, 0), dark_metal, 8)
	# Torres colectoras con brazos sobre la lava
	for data in [[Vector3(-38, 0, -18), 0.6], [Vector3(42, 0, -26), -0.7], [Vector3(-46, 0, 30), 2.4], [Vector3(36, 0, 38), -2.2]]:
		var t := Node3D.new()
		t.position = data[0]
		t.rotation.y = data[1]
		add_child(t)
		_cyl(t, 1.4, 2.4, 34, Vector3(0, 10, 0), dark_metal, 8)
		var arm := _box(t, Vector3(1.6, 1.6, 24), Vector3(0, 25, 9), dark_metal)
		arm.rotation.x = 0.32
		_box(t, Vector3(0.5, 9, 0.5), Vector3(0, 20, 19), dark_metal)
		_box(t, Vector3(1.2, 1.2, 1.2), Vector3(0, 27.5, 0), _glow(Color(1, 0.45, 0.15), 2.5))
		_cyl(t, 3.5, 3.5, 1.2, Vector3(0, -6.4, 0), dark_metal, 10)
	# Agujas de roca volcanica
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	for i in range(46):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(24.0, 130.0)
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if pos.z < -20 and absf(pos.x) < 20:
			continue
		var h := rng.randf_range(8.0, 38.0) * (1.0 if r > 40.0 else 0.5)
		var spire := _cyl(self, rng.randf_range(0.0, 1.5), rng.randf_range(3.0, 8.0), h, pos + Vector3(0, -7.0 + h * 0.5, 0), rock, 6)
		spire.rotation.y = rng.randf() * TAU
		spire.rotation.z = rng.randf_range(-0.12, 0.12)
	# Volcan lejano con crater incandescente
	_cyl(self, 10.0, 75.0, 60.0, Vector3(-60, 22, -230), rock, 10)
	_cyl(self, 9.5, 9.5, 1.0, Vector3(-60, 52.2, -230), _glow(Color(1.0, 0.45, 0.1), 3.0), 10)
	_light(Vector3(-60, 60, -225), Color(1, 0.4, 0.1), 6.0, 80.0)

# ---------------------------------------------------------------- particulas
func _particle_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _round_texture()
	return m

# Punto suave y redondo para brasas y ceniza (sin cuadrados visibles).
func _round_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t

func _build_particles() -> void:
	# Brasas que suben desde la lava y cruzan la plataforma
	var embers := CPUParticles3D.new()
	embers.amount = 420
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(30, 1, 30)
	embers.position = Vector3(0, -5, 0)
	embers.direction = Vector3(0.2, 1, 0.1)
	embers.spread = 25.0
	embers.initial_velocity_min = 1.2
	embers.initial_velocity_max = 3.0
	embers.gravity = Vector3(0.3, 0.15, 0)
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = _particle_material(Color(1.0, 0.5, 0.12))
	embers.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	fade.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	embers.color_ramp = fade
	add_child(embers)
	# Ceniza gris que cae lentamente
	var ash := CPUParticles3D.new()
	ash.amount = 260
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(28, 1, 28)
	ash.position = Vector3(0, 14, 0)
	ash.direction = Vector3(0.4, -1, 0)
	ash.spread = 20.0
	ash.initial_velocity_min = 0.4
	ash.initial_velocity_max = 1.0
	ash.gravity = Vector3(0.2, -0.3, 0)
	var aq := QuadMesh.new()
	aq.size = Vector2(0.05, 0.05)
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	am.albedo_color = Color(0.32, 0.29, 0.28, 0.75)
	am.albedo_texture = _round_texture()
	aq.material = am
	ash.mesh = aq
	add_child(ash)

# Erupciones de lava aleatorias y pulso de luz del magma.
func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	for i in lava_lights.size():
		lava_lights[i].light_energy = 3.0 + sin(clock * 1.7 + float(i) * 1.3) * 0.6
	burst_timer -= delta
	if burst_timer > 0.0:
		return
	burst_timer = randf_range(0.6, 1.8)
	var ang := randf() * TAU
	var r := randf_range(15.0, 45.0)
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 40
	burst.lifetime = 1.8
	burst.direction = Vector3.UP
	burst.spread = 18.0
	burst.initial_velocity_min = 5.0
	burst.initial_velocity_max = 10.0
	burst.gravity = Vector3(0, -9.8, 0)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.5
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 0.25)
	q.material = _particle_material(Color(1.0, 0.45, 0.1))
	burst.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.8, 0.35, 1.0))
	fade.set_color(1, Color(0.8, 0.12, 0.0, 0.0))
	burst.color_ramp = fade
	add_child(burst)
	burst.position = Vector3(cos(ang) * r, -7.0, sin(ang) * r)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
