extends Node3D

const FireScript = preload("res://scripts/fire.gd")
## Air you can see: ash drifting down, embers lifting off, patchy ground mist,
## smoldering stumps, and a lens on your own eyes (grain, vignette, fringing).
## Nothing here needs art files.

var player
var env: Environment

var ash: CPUParticles3D
var embers: CPUParticles3D
var mist: FogVolume
var mist_mat: FogMaterial
var mist_t := 0.0
var lens: ColorRect
var lens_strength := 1.0
var smolders: Array = []


func build(world_size := 300.0) -> void:
	ash = _flakes()
	add_child(ash)
	embers = _embers()
	add_child(embers)
	_build_mist(world_size)


# ---------- falling ash ----------

func _flakes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 700
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16, 5, 16)
	p.direction = Vector3(0.3, -1, 0.1)
	p.spread = 35.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0.12, -0.18, 0.05)   # a slow drift with the wind
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.damping_min = 0.05
	p.damping_max = 0.15
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.022)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5)
	m.roughness = 1.0
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.6, 0.6))
	g.set_color(1, Color(0.35, 0.34, 0.33))
	p.color_initial_ramp = g
	p.position = Vector3(0, 4, 0)
	return p


# ---------- embers lifting off the ground ----------

func _embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(20, 0.3, 20)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.1, 0.12, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.018)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(3.0, 1.0, 0.25, 0.0))
	g.add_point(0.15, Color(3.0, 1.0, 0.25, 1.0))
	g.add_point(0.7, Color(1.6, 0.35, 0.08, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.05, 0.0, 0.0))
	p.color_ramp = g
	p.position = Vector3(0, 0.2, 0)
	return p


# ---------- ground mist (Forward+ only; ignored by the compatibility renderer) ----------

func _build_mist(size: float) -> void:
	mist = FogVolume.new()
	mist.size = Vector3(size, 3.0, size)
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	mist_mat = FogMaterial.new()
	mist_mat.density = 0.05
	mist_mat.height_falloff = 1.2
	mist_mat.edge_fade = 0.4
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 16
	tex.depth = 64
	tex.seamless = true
	tex.noise = n
	mist_mat.density_texture = tex
	mist.material = mist_mat
	mist.position = Vector3(0, 1.0, -20)
	add_child(mist)


## Called with each shift's lighting so the mist and ash match the hour.
func set_light(c: Dictionary) -> void:
	if mist_mat == null:
		return
	var fogc: Color = c["fog"]
	var night: bool = c["sun_energy"] < 0.3
	mist_mat.density = c["fog_density"] * (1.4 if night else 0.8)
	mist_mat.albedo = fogc.lightened(0.5)
	var clean: bool = c["fog_density"] < 0.03   # the flashback day is clean air
	ash.visible = not clean
	embers.visible = not clean
	for f in smolders:
		f.visible = not clean
	if clean:
		mist_mat.density = 0.0
	else:
		var want_embers := 40 if night else 14
		if embers.amount != want_embers:
			embers.amount = want_embers


# ---------- smoldering stumps ----------

func add_smolder(pos: Vector3) -> Node3D:
	return add_fire(pos, false)


## A fire you can put out with the pump. `big` is a rekindle in a debris pile.
func add_fire(pos: Vector3, big: bool) -> Node3D:
	var f = FireScript.new()
	f.big = big
	f.player = player
	add_child(f)
	f.global_position = pos
	f.build()
	smolders.append(f)
	return f


var _dot: Texture2D
func _soft_dot() -> Texture2D:
	if _dot != null:
		return _dot
	var t := GradientTexture2D.new()
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	t.gradient = g
	_dot = t
	return t


# ---------- lens ----------

## The lens lives at the bottom of the HUD layer, under the camcorder overlay
## and all the text.
func attach_lens(hud: CanvasLayer) -> void:
	lens = ColorRect.new()
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lens.gdshader")
	lens.material = mat
	hud.add_child(lens)
	hud.move_child(lens, 0)
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if player == null:
		return
	var p: Vector3 = player.global_position
	ash.global_position = p + Vector3(0, 4, 0)
	embers.global_position = Vector3(p.x, 0.2, p.z)
	# Mist drifts slowly with the wind and comes back.
	mist_t += delta
	mist.position.x = sin(mist_t * 0.01) * 25.0
	# The camcorder has its own look; drop ours while it's up.
	if lens == null:
		return
	var want := 0.0 if player.recording else 1.0
	lens_strength = move_toward(lens_strength, want, delta * 6.0)
	(lens.material as ShaderMaterial).set_shader_parameter("strength", lens_strength)
	lens.visible = lens_strength > 0.01
