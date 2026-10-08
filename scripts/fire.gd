extends Node3D
## Something still burning. Two sizes:
##   spot  - a smoldering stump: a coal, a glow, a thread of smoke. Two seconds
##           of water puts it out.
##   blaze - a rekindle in a debris pile: real flames, sparks, a smoke column,
##           crackling. Takes several seconds of steady water, and if you stop
##           too early it creeps back up.
## Hit with water, it throws steam. When it goes out, it hisses and the smoke
## turns white, then stops.

signal extinguished(fire)

var big := false
var heat := 1.0
var out := false
var player
var since_water := 99.0
var t := 0.0
var seed := 0.0

var smoke: CPUParticles3D
var steam: CPUParticles3D
var flames: CPUParticles3D
var sparks: CPUParticles3D
var light: OmniLight3D
var coal_mat: StandardMaterial3D
var _crackle: AudioStreamPlayer3D
var _gen: AudioStreamGeneratorPlayback
var _pop := 0.0
var _lp := 0.0
var _steam_left := 0.0

static var _dot: Texture2D


func build() -> void:
	seed = randf() * 100.0
	smoke = _smoke(3.0 if big else 1.0)
	add_child(smoke)
	steam = _steam(big)
	add_child(steam)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.14)
	light.omni_range = 9.0 if big else 2.2
	light.omni_attenuation = 1.6
	light.shadow_enabled = big
	light.position = Vector3(0, 1.7 if big else 0.25, 0)
	add_child(light)
	if big:
		_debris_pile()
		flames = _flames()
		add_child(flames)
		sparks = _sparks()
		add_child(sparks)
		_build_crackle()
	else:
		var coal := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.12
		coal_mat = StandardMaterial3D.new()
		coal_mat.albedo_color = Color(0.05, 0.03, 0.02)
		coal_mat.emission_enabled = true
		coal_mat.emission = Color(1.0, 0.3, 0.05)
		coal_mat.emission_energy_multiplier = 1.4
		sm.material = coal_mat
		coal.mesh = sm
		coal.position = Vector3(0, 0.03, 0)
		add_child(coal)


## Water on the fire. `amount` is how much heat this frame's spray takes off.
func douse(amount: float) -> void:
	if out:
		return
	since_water = 0.0
	heat -= amount
	steam.emitting = true
	if heat <= 0.0:
		_go_out()


## For the dev skip: out, no ceremony.
func extinguish_now() -> void:
	if not out:
		heat = 0.0
		_go_out()


func _go_out() -> void:
	out = true
	heat = 0.0
	if flames != null:
		flames.emitting = false
	if sparks != null:
		sparks.emitting = false
	smoke.emitting = false
	if coal_mat != null:
		coal_mat.emission_energy_multiplier = 0.0
	# One last big plume of steam.
	steam.emitting = true
	_steam_left = 3.0 if big else 1.6
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.8)
	tw.tween_callback(func(): light.visible = false)
	extinguished.emit(self)


func _process(delta: float) -> void:
	t += delta
	since_water += delta
	if _steam_left > 0.0:
		_steam_left -= delta
		if _steam_left <= 0.0:
			steam.emitting = false
	elif since_water > 0.25 and not out:
		steam.emitting = false
	if out:
		if _crackle != null and _crackle.playing:
			_crackle.volume_db -= delta * 20.0
			if _crackle.volume_db < -40.0:
				_crackle.stop()
		return
	# A rekindle you only half knock down creeps back.
	if big and since_water > 1.5 and heat < 1.0:
		heat = minf(heat + 0.05 * delta, 1.0)
	var k := t + seed
	var flicker := 0.75 + 0.15 * sin(k * 9.3) + 0.1 * sin(k * 23.0) + randf() * 0.08
	var vis := 0.25 + 0.75 * heat
	if big:
		light.light_energy = 3.2 * flicker * vis
		flames.scale_amount_min = 0.7 * vis
		flames.scale_amount_max = 1.4 * vis
		_fill_crackle()
	else:
		light.light_energy = (0.6 + 0.25 * sin(k * 2.3) + 0.15 * sin(k * 7.1)) * vis


# ---------- visuals ----------

func _soft() -> Texture2D:
	if _dot != null:
		return _dot
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	_dot = tex
	return tex


func _puff_mat(additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft()
	m.roughness = 1.0
	if additive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _quad(size: float, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q


func _smoke(scale: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14 if scale <= 1.0 else 30
	p.lifetime = 7.0 if scale <= 1.0 else 10.0
	p.preprocess = p.lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25 * scale
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.25 * sqrt(scale)
	p.initial_velocity_max = 0.45 * sqrt(scale) * 1.4
	p.gravity = Vector3(0.18, 0.05, 0.06)
	p.angular_velocity_min = -20.0
	p.angular_velocity_max = 20.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 1.6 * scale
	p.scale_amount_max = 2.4 * scale
	p.mesh = _quad(1.0, _puff_mat())
	var g := Gradient.new()
	var dark := 0.2 if scale > 1.0 else 0.32
	g.set_color(0, Color(dark, dark, dark, 0.0))
	g.add_point(0.15, Color(dark, dark * 0.97, dark * 0.95, 0.28 if scale > 1.0 else 0.22))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.39, 0.38, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.6 if scale > 1.0 else 0.3, 0)
	return p


func _steam(large: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40 if large else 18
	p.lifetime = 1.8
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8 if large else 0.2
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0.1, 0.6, 0)
	p.damping_min = 0.8
	p.damping_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 1.0 if large else 0.6
	p.scale_amount_max = 2.0 if large else 1.2
	p.mesh = _quad(1.0, _puff_mat())
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.0))
	g.add_point(0.1, Color(0.85, 0.86, 0.87, 0.45))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.4 if large else 0.15, 0)
	return p


func _flames() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 110
	p.lifetime = 0.8
	p.preprocess = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.15, 0.7)
	p.direction = Vector3(0, 1, 0)
	p.spread = 10.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.15, 1.2, 0)
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var fq := QuadMesh.new()
	fq.size = Vector2(0.45, 0.8)    # tongues, not puffs
	fq.material = _puff_mat(true)
	p.mesh = fq
	var g := Gradient.new()
	g.set_color(0, Color(1.4, 1.0, 0.45, 0.0))
	g.add_point(0.12, Color(1.5, 0.95, 0.35, 0.75))
	g.add_point(0.45, Color(1.3, 0.45, 0.08, 0.55))
	g.add_point(0.8, Color(0.5, 0.1, 0.02, 0.25))
	g.set_color(g.get_point_count() - 1, Color(0.15, 0.02, 0.0, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.35, 0)
	return p


func _sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.8, 0.3, 0.6)
	p.direction = Vector3(0, 1, 0)
	p.spread = 30.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0.3, 0.4, 0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	p.mesh = _quad(0.03, m)
	var g := Gradient.new()
	g.set_color(0, Color(3.0, 1.6, 0.4, 1.0))
	g.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.6, 0)
	return p


## Charred lumber and a couple of roof sheets the rekindle is eating.
func _debris_pile() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.025, 0.02, 0.018)
	wood.roughness = 1.0
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.03, 0.015, 0.01)
	hot.roughness = 1.0
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.25, 0.03)
	hot.emission_energy_multiplier = 0.9
	coal_mat = hot
	for i in 9:
		var m := CylinderMesh.new()
		m.top_radius = randf_range(0.05, 0.11)
		m.bottom_radius = m.top_radius
		m.height = randf_range(1.0, 2.2)
		m.radial_segments = 7
		m.material = hot if i % 3 == 0 else wood
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 0.45), randf_range(-0.5, 0.5))
		mi.rotation = Vector3(randf_range(-1.4, 1.4), randf_range(0, TAU), PI * 0.5 + randf_range(-0.5, 0.5))
		add_child(mi)
	var bed := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.2
	cm.height = 0.12
	cm.material = hot
	bed.mesh = cm
	bed.position.y = 0.04
	add_child(bed)


# ---------- crackle ----------

func _build_crackle() -> void:
	_crackle = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	_crackle.stream = gen
	_crackle.unit_size = 5.0
	_crackle.max_distance = 45.0
	_crackle.volume_db = 2.0
	_crackle.position = Vector3(0, 0.5, 0)
	add_child(_crackle)
	_crackle.play()
	_gen = _crackle.get_stream_playback()


func _fill_crackle() -> void:
	if _gen == null:
		return
	if player != null and player.global_position.distance_to(global_position) > 45.0:
		return
	var vis := 0.3 + 0.7 * heat
	for i in _gen.get_frames_available():
		var white := randf() * 2.0 - 1.0
		_lp += 0.04 * (white - _lp)          # low roar
		if randf() < 0.0009 * vis:
			_pop = randf_range(0.4, 0.9)     # a pop
		_pop *= 0.985
		var s := (_lp * 0.5 + white * _pop) * vis
		_gen.push_frame(Vector2(s, s))
