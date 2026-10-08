extends Node3D
## A work-order item that isn't a tree.
##   kind "leak": a broken gas meter riser on a slab, still venting. Flag it with [4].
##   kind "doc":  film something for the record (the standing chimney). No visuals of its own.
##   kind "remains": a tarp over a shape the search teams missed. Mark it for the
##                   coroner with [4]. Implied only; nothing is ever shown under the tarp.
##   kind "fire": a rekindle. Done when the pump puts it out (see fire.gd).
##   kind "marker": the same, already marked by the search team (scenery, not a task).
## Shares the fields the tablet and filing logic read from trees.

var tree_id := ""
var hint := ""
var kind := "leak"
var is_assessed := false
var tag := ""
var player            # set by main, for distance gating
var hiss_stream: AudioStream   # optional recorded hiss (audio group "gas_hiss")
# Utility items ("pole", "xfmr", "origin"): film the thing, then rate it.
var body: Node3D               # what the camcorder has to be pointed at
var target_node: Node3D        # where the rating paint goes
var progress := 0.0
var record_time := 5.0
var fire   # kind "fire": the rekindle this item tracks

var _hiss: AudioStreamPlayer3D
var _gen_playback: AudioStreamGeneratorPlayback
var _lp := 0.0
var _t := 0.0
var _vapor: CPUParticles3D


func _ready() -> void:
	if kind == "leak":
		_build_riser()
		_build_vapor()
		_build_hiss()
	elif kind == "remains" or kind == "marker":
		_build_tarp()
		if kind == "marker":
			_stake("C-%d" % (randi() % 40 + 11))


func _process(delta: float) -> void:
	if _gen_playback == null or not _hiss.playing:
		return
	if player != null and player.global_position.distance_to(global_position) > 30.0:
		return
	# Procedural hiss: filtered noise with a slow sputter.
	_t += delta
	var amp := 0.22 * (0.75 + 0.25 * sin(_t * 2.3) * sin(_t * 0.7))
	for i in _gen_playback.get_frames_available():
		var white := randf() * 2.0 - 1.0
		_lp += 0.3 * (white - _lp)
		var s := (white - _lp) * amp
		_gen_playback.push_frame(Vector2(s, s))


# ---------- shared with trees ----------

func mark_assessed() -> void:
	is_assessed = true


## Pole and transformer ratings, sprayed as a colored band on the pole.
const RATINGS := {
	"pole": {"remove": "replace", "monitor": "repair", "retain": "ok"},
	"xfmr": {"remove": "leaking", "monitor": "damaged", "retain": "ok"},
}
const RATING_COLORS := {
	"replace": Color(0.85, 0.12, 0.08), "leaking": Color(0.85, 0.12, 0.08),
	"repair": Color(0.95, 0.75, 0.1), "damaged": Color(0.95, 0.75, 0.1),
	"ok": Color(0.15, 0.4, 0.9),
}


func rate(key: String) -> void:
	if tag != "" or not RATINGS.has(kind):
		return
	tag = RATINGS[kind][key]
	if target_node != null:
		var band := CylinderMesh.new()
		band.top_radius = 0.2
		band.bottom_radius = 0.21
		band.height = 0.22
		var m := StandardMaterial3D.new()
		m.albedo_color = RATING_COLORS[tag]
		band.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = band
		mi.position.y = 1.5 if kind == "pole" else 2.0
		target_node.add_child(mi)


func apply_tag(_kind: String) -> void:
	if RATINGS.has(kind):
		is_assessed = true
		rate(_kind if RATINGS[kind].has(_kind) else "monitor")
		return
	if kind == "origin":
		is_assessed = true
		tag = "recorded"
		return
	if kind == "fire":
		is_assessed = true
		tag = "out"
		if fire != null:
			fire.extinguish_now()
		return
	if kind == "leak" or kind == "remains":
		flag()
	else:
		is_assessed = true
		tag = "recorded"


func flag() -> void:
	if tag != "":
		return
	is_assessed = true
	if kind == "remains":
		tag = "marked"
		_stake("C-07")
		return
	tag = "gas"
	# Lath stake with yellow flagging, for the utility crew.
	var wood := _mat(Color(0.75, 0.62, 0.42))
	var yellow := _mat(Color(1.0, 0.85, 0.05))
	yellow.emission_enabled = true
	yellow.emission = Color(0.5, 0.42, 0.0)
	_box(Vector3(0.04, 1.3, 0.05), Vector3(0.6, 0.65, 0.3), wood)
	_box(Vector3(0.02, 0.3, 0.22), Vector3(0.6, 1.2, 0.42), yellow, Vector3(0, 0, 8))


func shut_off() -> void:
	if _hiss != null:
		_hiss.stop()
	if _vapor != null:
		_vapor.emitting = false


# ---------- remains ----------

func _build_tarp() -> void:
	# A faded blue tarp over a low, still shape, weighed down with debris.
	var tarp := StandardMaterial3D.new()
	tarp.albedo_color = Color(0.08, 0.13, 0.22)
	tarp.roughness = 0.75
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 0.5
	m.radial_segments = 14
	m.rings = 6
	m.material = tarp
	var mound := MeshInstance3D.new()
	mound.mesh = m
	mound.scale = Vector3(1.9, 0.8, 0.85)
	mound.position = Vector3(0, 0.02, 0)
	add_child(mound)
	# Tarp edges lying flat, and bricks on the corners.
	_box(Vector3(2.2, 0.01, 1.3), Vector3(0, 0.01, 0), tarp, Vector3(0, 6, 0))
	var brick := _mat(Color(0.25, 0.12, 0.08))
	for c in [Vector3(1.0, 0, 0.55), Vector3(-1.0, 0, 0.5), Vector3(0.9, 0, -0.6), Vector3(-1.05, 0, -0.55)]:
		_box(Vector3(0.22, 0.08, 0.11), c + Vector3(0, 0.05, 0), brick, Vector3(0, randf() * 60.0, 0))


func _stake(code: String) -> void:
	# Coroner's marker: a lath stake, pink flagging, a hand-written number.
	var wood := _mat(Color(0.75, 0.62, 0.42))
	var pink := _mat(Color(1.0, 0.3, 0.6))
	pink.emission_enabled = true
	pink.emission = Color(0.5, 0.1, 0.3)
	_box(Vector3(0.04, 1.2, 0.05), Vector3(1.4, 0.6, 0.0), wood)
	_box(Vector3(0.02, 0.35, 0.18), Vector3(1.4, 1.05, 0.12), pink, Vector3(0, 0, 6))
	_box(Vector3(0.02, 0.3, 0.14), Vector3(1.41, 1.0, 0.24), pink, Vector3(0, 0, -10))
	var l := Label3D.new()
	l.text = code
	l.font_size = 64
	l.pixel_size = 0.0022
	l.modulate = Color(0.08, 0.08, 0.08)
	l.outline_size = 0
	l.position = Vector3(1.4, 0.55, 0.03)
	add_child(l)


# ---------- leak visuals ----------

func _build_riser() -> void:
	var steel := _mat(Color(0.32, 0.31, 0.3))
	steel.metallic = 0.5
	var rust := _mat(Color(0.35, 0.16, 0.07))
	_cyl(0.045, 0.045, 0.8, Vector3(0, 0.4, 0), steel)                 # riser
	_cyl(0.045, 0.045, 0.35, Vector3(0.12, 0.8, 0), steel, Vector3(0, 0, 90))
	_box(Vector3(0.3, 0.35, 0.22), Vector3(0.3, 0.85, 0), rust, Vector3(0, 0, -6))   # melted meter
	_box(Vector3(0.1, 0.04, 0.04), Vector3(0.05, 0.62, 0.08), _mat(Color(0.7, 0.1, 0.05)))  # valve handle
	# Snapped house line, where the gas is coming from.
	_cyl(0.035, 0.045, 0.25, Vector3(0.52, 0.86, 0), steel, Vector3(0, 0, 70))


func _build_vapor() -> void:
	_vapor = CPUParticles3D.new()
	_vapor.position = Vector3(0.62, 0.9, 0)
	_vapor.amount = 28
	_vapor.lifetime = 2.2
	_vapor.direction = Vector3(0.4, 1, 0)
	_vapor.spread = 25.0
	_vapor.initial_velocity_min = 0.4
	_vapor.initial_velocity_max = 0.9
	_vapor.gravity = Vector3(0, 0.25, 0)
	_vapor.scale_amount_min = 0.5
	_vapor.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(0.9, 0.92, 0.95, 0.10))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	_vapor.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	# Soft round puff instead of a hard square.
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	quad.material = m
	_vapor.mesh = quad
	add_child(_vapor)


func _build_hiss() -> void:
	_hiss = AudioStreamPlayer3D.new()
	_hiss.position = Vector3(0.6, 0.9, 0)
	_hiss.unit_size = 3.0
	_hiss.max_distance = 28.0
	add_child(_hiss)
	if hiss_stream != null:
		_hiss.stream = hiss_stream
		_hiss.finished.connect(_hiss.play)
		_hiss.play()
	else:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.25
		_hiss.stream = gen
		_hiss.play()
		_gen_playback = _hiss.get_stream_playback()


# ---------- helpers ----------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)


func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 10
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
