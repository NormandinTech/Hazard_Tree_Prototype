extends Node3D
## The thing that hunts you: a burned snag that stands where it wasn't.
## Roots splayed like it climbed out of the ground, two branches reaching
## forward, a hollow knot of a face with embers still burning in the sockets.
##
## It never animates. It only ever moves while nobody is filming it.
## Origin sits 0.975 m above its base (the old figure's convention), so the
## face is at eye height when it is right in front of you.

const TownScript = preload("res://scripts/town.gd")

var layer_mask := 2   # 2 = camcorder only, 4 = tape only

static var _bark: StandardMaterial3D
static var _ember: StandardMaterial3D
static var _void: StandardMaterial3D


func _ready() -> void:
	if _bark == null:
		_bark = TownScript._noise_mat(Color(0.015, 0.015, 0.015), Color(0.09, 0.08, 0.07), 0.4, Vector3(2, 6, 1), "burnt_bark", Color(0.7, 0.7, 0.7), false)
		_ember = StandardMaterial3D.new()
		_ember.albedo_color = Color(1.0, 0.35, 0.05)
		_ember.emission_enabled = true
		_ember.emission = Color(1.0, 0.3, 0.03)
		_ember.emission_energy_multiplier = 4.0
		_void = StandardMaterial3D.new()
		_void.albedo_color = Color(0, 0, 0)
		_void.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var base := Vector3(0, -0.975, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Roots, splayed and gripping.
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		var knee := base + out * 0.55 + Vector3(0, 0.35, 0)
		var toe := base + out * rng.randf_range(1.1, 1.5) + Vector3(0, -0.05, 0)
		_taper(base + Vector3(0, 0.6, 0) + out * 0.15, knee, 0.16, 0.11, _bark)
		_taper(knee, toe, 0.11, 0.02, _bark)

	# Trunk: thick and straight below, leaning back and splitting above.
	_taper(base, Vector3(0, 1.3, 0), 0.42, 0.32, _bark)
	_taper(Vector3(0, 1.3, 0), Vector3(0.05, 2.8, 0.25), 0.32, 0.2, _bark)
	_taper(Vector3(0.05, 2.8, 0.25), Vector3(-0.2, 3.9, 0.45), 0.2, 0.05, _bark)
	_taper(Vector3(0.05, 2.8, 0.25), Vector3(0.35, 3.6, 0.3), 0.12, 0.02, _bark)

	# Arms: branches from the shoulders, reaching toward you.
	for side in [1.0, -1.0]:
		var shoulder := Vector3(0.22 * side, 1.55, -0.05)
		var elbow := Vector3(0.62 * side, 1.15, -0.55)
		var wrist := Vector3(0.48 * side, 0.75, -1.0)
		_taper(shoulder, elbow, 0.11, 0.07, _bark)
		_taper(elbow, wrist, 0.07, 0.045, _bark)
		for f in 3:
			var tip := wrist + Vector3((f - 1) * 0.12 * side + 0.05 * side, -0.32 - f * 0.05, -0.22 + f * 0.04)
			_taper(wrist, tip, 0.03, 0.004, _bark)

	# The face: a charcoal knot only a shade lighter than the bark, two deep
	# slanted sockets with pinpoint embers, and a long dark split for a mouth.
	var ash := TownScript._noise_mat(Color(0.06, 0.055, 0.05), Color(0.2, 0.18, 0.16), 0.9, Vector3(3, 3, 1), "ground_ash", Color.WHITE, false)
	var knot := _mesh(_ellipsoid(0.21, 0.4, 0.11), Vector3(0, 0.6, -0.3), ash)
	knot.rotation.z = 0.06
	for ex in [-1.0, 1.0]:
		var sock := _mesh(_ellipsoid(0.07, 0.035, 0.05), Vector3(ex * 0.09, 0.8, -0.395), _void)
		sock.rotation.z = -0.45 * ex
		_mesh(_ellipsoid(0.02, 0.016, 0.015), Vector3(ex * 0.09, 0.795, -0.425), _ember)
	var mouth := _mesh(_ellipsoid(0.035, 0.2, 0.04), Vector3(0.01, 0.43, -0.395), _void)
	mouth.rotation.z = 0.08
	# Embers still burning in the cracks.
	for i in 5:
		var y := rng.randf_range(-0.6, 2.4)
		var a2 := rng.randf_range(0, TAU)
		var r := lerpf(0.4, 0.22, clampf((y + 0.975) / 3.5, 0.0, 1.0)) + 0.01
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.015, rng.randf_range(0.12, 0.35), 0.015)
		cm.material = _ember
		crack.mesh = cm
		crack.position = Vector3(cos(a2) * r, y, sin(a2) * r)
		crack.rotation.z = rng.randf_range(-0.3, 0.3)
		crack.layers = layer_mask
		add_child(crack)
	# A faint glow from inside. You can catch it on the ash with your own eyes:
	# a warm spot on the ground with nothing standing on it.
	if layer_mask != 2:
		return
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 0.7, -0.6)
	glow.light_color = Color(1.0, 0.35, 0.08)
	glow.light_energy = 0.35
	glow.omni_range = 2.5
	glow.light_cull_mask = layer_mask | 1
	add_child(glow)


func _ellipsoid(rx: float, ry: float, rz: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 12
	m.rings = 6
	var mi_scale := Vector3(rx, ry, rz)
	m.set_meta("scale", mi_scale)
	return m


func _mesh(m: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	if m.has_meta("scale"):
		mi.scale = m.get_meta("scale")
	mi.layers = layer_mask
	add_child(mi)
	return mi


func _taper(a: Vector3, b: Vector3, ra: float, rb: float, mat: Material) -> void:
	var d := b - a
	var seg := d.length()
	if seg < 0.01:
		return
	var y := d / seg
	var x := y.cross(Vector3.UP) if abs(y.dot(Vector3.UP)) < 0.99 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = ra
	mesh.top_radius = rb
	mesh.height = seg
	mesh.radial_segments = 8
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	mi.layers = layer_mask
	add_child(mi)
