class_name HazardTree
extends StaticBody3D
## A burned tree. Work-order trees carry a painted ID and flagging tape,
## and can be recorded (assessed) and spray-tagged.

const TAG_COLORS := {
	"remove": Color(0.85, 0.12, 0.08),
	"monitor": Color(0.95, 0.75, 0.10),
	"retain": Color(0.15, 0.40, 0.90),
}

const TownScript = preload("res://scripts/town.gd")

static var _bark: StandardMaterial3D     # fully charred
static var _scorch: StandardMaterial3D   # scorched bark above the char line

var tree_id := ""
var hint := ""
var is_work_order := false
var height := 9.0
var radius := 0.3
var assess_progress := 0.0
var is_assessed := false
var tag := ""
var tag_ring: MeshInstance3D
var rng := RandomNumberGenerator.new()
var low_h := 3.0             # straight charred lower trunk (where tape and tags go)
var lean := Vector3.ZERO     # how far the top drifts sideways
var top_h := 9.0             # actual top height (lower if the top snapped off)


func _ready() -> void:
	if _bark == null:
		_bark = TownScript._noise_mat(Color(0.02, 0.02, 0.02), Color(0.11, 0.10, 0.09), 0.35, Vector3(2, 6, 1), "burnt_bark", Color.WHITE, false)
		_scorch = TownScript._noise_mat(Color(0.14, 0.11, 0.09), Color(0.30, 0.24, 0.19), 0.3, Vector3(2, 8, 1), "bark", Color(0.55, 0.48, 0.42), false)
	rng.seed = hash(position)
	_build_trunk()
	_build_branches()
	if is_work_order:
		_build_markings()


func mark_assessed() -> void:
	is_assessed = true


func apply_tag(kind: String) -> void:
	if tag != "" or not TAG_COLORS.has(kind):
		return
	tag = kind
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TAG_COLORS[kind]
	mat.roughness = 0.6
	tag_ring = _ring(1.0, 0.25, mat)


## Shift 2: the crew reports this tag is missing. Paint gone, needs a fresh assessment.
func reset_for_recheck(new_hint: String) -> void:
	if tag_ring != null:
		tag_ring.queue_free()
		tag_ring = null
	tag = ""
	is_assessed = false
	assess_progress = 0.0
	hint = new_hint


func _radius_at(y: float) -> float:
	return lerp(radius, radius * 0.35, clamp(y / height, 0.0, 1.0))


func _build_trunk() -> void:
	low_h = minf(3.2, height * 0.4)
	var broken := not is_work_order and rng.randf() < 0.35
	top_h = height * (rng.randf_range(0.55, 0.8) if broken else 1.0)
	var drift := rng.randf_range(0.1, 0.06 * height)
	var dir := rng.randf_range(0.0, TAU)
	lean = Vector3(cos(dir) * drift, 0.0, sin(dir) * drift)
	_wob = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0.08, 0.22))

	# One continuous trunk: flared roots, a straight charred lower trunk (where
	# the tape and paint go), then a wandering upper trunk. Vertical bark ridges
	# are pushed into the surface so the flashlight rakes across them.
	var upper_mat := _bark if rng.randf() < 0.45 else _scorch
	var st_low := _st(_bark)
	var lower_pts: Array = []
	var lower_r: Array = []
	var y := -0.15
	while y < low_h:
		lower_pts.append(_axis_at(y))
		lower_r.append(_trunk_r(y))
		y += 0.3
	lower_pts.append(_axis_at(low_h))
	lower_r.append(_trunk_r(low_h))
	_tube(st_low, lower_pts, lower_r, 14, 0.1, false)

	var st_up := _st(upper_mat)
	var r_top := _radius_at(top_h) if broken else radius * 0.05
	var up_pts: Array = []
	var up_r: Array = []
	var n := maxi(4, int((top_h - low_h) / 0.45))
	for k in n + 1:
		var yy := lerpf(low_h, top_h, float(k) / n)
		up_pts.append(_axis_at(yy))
		var t := float(k) / n
		up_r.append(lerpf(_trunk_r(low_h), r_top, pow(t, 0.85)))
	_tube(st_up, up_pts, up_r, 12, 0.06, broken)
	if broken:
		# Jagged snapped top: splinters standing up from the break.
		var tip: Vector3 = up_pts[up_pts.size() - 1]
		for i in rng.randi_range(3, 5):
			var a := rng.randf_range(0, TAU)
			var off := Vector3(cos(a), 0, sin(a)) * r_top * 0.6
			var h := rng.randf_range(0.25, 1.0)
			_tube(_st(_bark), [tip + off, tip + off * 1.3 + Vector3(0, h * 0.6, 0), tip + off * 1.5 + Vector3(0, h, 0)],
				[r_top * 0.35, r_top * 0.2, 0.004], 5, 0.0, false)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = height * 0.5
	add_child(col)


var _wob := Vector3.ZERO     # phase x, phase y, amount: how much the trunk wanders
var _sts := {}               # material -> SurfaceTool for this tree
var _counts := {}            # material -> vertices added so far


## Point on the trunk axis at height y (straight lower trunk, then lean and wander).
func _axis_at(y: float) -> Vector3:
	if y <= low_h:
		return Vector3(0, y, 0)
	var t := (y - low_h) / maxf(top_h - low_h, 0.01)
	var wander := Vector3(sin(y * 0.9 + _wob.x), 0, cos(y * 0.7 + _wob.y)) * _wob.z * t * height * 0.1
	return Vector3(0, y, 0) + lean * t + wander


## Trunk radius with the root flare at the base.
func _trunk_r(y: float) -> float:
	return _radius_at(maxf(y, 0.0)) * (1.0 + 0.75 * exp(-maxf(y, 0.0) / 0.3))


func _build_branches() -> void:
	var count := rng.randi_range(3, 9)
	for i in count:
		var y := rng.randf_range(height * 0.3, top_h * 0.95)
		var base := _axis_at(y)
		var length := rng.randf_range(0.5, 2.8)
		var yaw := rng.randf_range(0.0, TAU)
		var out := Vector3(cos(yaw), 0, sin(yaw))
		# Burned branches stick out, then droop.
		var droop := rng.randf_range(-0.7, 0.3)
		var rise := rng.randf_range(0.05, 0.3)
		var p1 := base + out * length * 0.35 + Vector3(0, length * rise, 0)
		var p2 := base + out * length * 0.7 + Vector3(0, length * rise * 0.8 + droop * 0.4, 0) + out.cross(Vector3.UP) * rng.randf_range(-0.2, 0.2)
		var tip := base + out * length + Vector3(0, droop, 0)
		var r := _radius_at(y) * rng.randf_range(0.18, 0.32)
		_tube(_st(_bark), [base - out * r, p1, p2, tip], [r, r * 0.7, r * 0.4, 0.004], 6, 0.0, false)
		# A twig or two off the branch.
		for k in rng.randi_range(0, 2):
			var from: Vector3 = p1.lerp(p2, rng.randf())
			var tw := out.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
			var tl := rng.randf_range(0.25, 0.7)
			_tube(_st(_bark), [from, from + tw * tl * 0.5 + Vector3(0, tl * 0.25, 0), from + tw * tl + Vector3(0, rng.randf_range(-0.2, 0.3), 0)],
				[r * 0.35, r * 0.2, 0.003], 4, 0.0, false)
	_commit()


func _st(mat: Material) -> SurfaceTool:
	if not _sts.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts[mat] = st
		_counts[mat] = 0
	return _sts[mat]


func _commit() -> void:
	var mesh := ArrayMesh.new()
	for mat in _sts.keys():
		var st: SurfaceTool = _sts[mat]
		st.generate_normals()
		st.generate_tangents()
		var arr := st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_sts.clear()
	_counts.clear()


## A tube along a spine of points. `ridge` pushes vertical bark ridges into
## the surface; `cap` closes the top (a snapped trunk).
func _tube(st: SurfaceTool, pts: Array, radii: Array, segs: int, ridge: float, cap: bool) -> void:
	var mat: Material = null
	for m in _sts.keys():
		if _sts[m] == st:
			mat = m
	var start: int = _counts[mat]
	var rings := pts.size()
	var seed := rng.randf_range(0, 50)
	var v := 0.0
	var prev_n := Vector3.ZERO
	for i in rings:
		var p: Vector3 = pts[i]
		var t: Vector3
		if i == 0:
			t = (pts[1] as Vector3) - p
		elif i == rings - 1:
			t = p - (pts[i - 1] as Vector3)
		else:
			t = (pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)
		t = t.normalized()
		if i > 0:
			v += p.distance_to(pts[i - 1])
		# Carry the ring's orientation along the spine so it doesn't twist.
		var nrm: Vector3
		if prev_n == Vector3.ZERO:
			var ref := Vector3.RIGHT if absf(t.dot(Vector3.UP)) > 0.9 else Vector3.UP
			nrm = ref.cross(t).normalized()
		else:
			nrm = (prev_n - t * prev_n.dot(t)).normalized()
		prev_n = nrm
		var bin := t.cross(nrm).normalized()
		var r: float = radii[i]
		for j in segs + 1:
			var a := TAU * float(j) / segs
			var d := nrm * cos(a) + bin * sin(a)
			var bump := 0.0
			if ridge > 0.0:
				bump = ridge * (0.6 * sin(a * 9.0 + seed + p.y * 0.25) + 0.4 * sin(a * 17.0 + seed * 1.7 + p.y * 0.9))
			st.set_uv(Vector2(float(j) / segs * maxf(r * 6.0, 0.5), v * 0.8))
			st.add_vertex(p + d * r * (1.0 + bump))
	# Which way to wind: test one quad against the outward direction.
	var flip := false
	if rings > 1:
		var p0: Vector3 = pts[0]
		var t0: Vector3 = ((pts[1] as Vector3) - p0).normalized()
		var ref0 := Vector3.RIGHT if absf(t0.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var n0 := ref0.cross(t0).normalized()
		var b0 := t0.cross(n0).normalized()
		var a1 := p0 + n0 * 1.0
		var a2 := p0 + (n0 * cos(TAU / segs) + b0 * sin(TAU / segs))
		var a3 := (pts[1] as Vector3) + n0
		var g := (a2 - a1).cross(a3 - a1)
		flip = g.dot(n0) > 0.0
	for i in rings - 1:
		for j in segs:
			var i0 := start + i * (segs + 1) + j
			var i1 := i0 + 1
			var i2 := i0 + segs + 1
			var i3 := i2 + 1
			if flip:
				st.add_index(i0); st.add_index(i2); st.add_index(i1)
				st.add_index(i1); st.add_index(i2); st.add_index(i3)
			else:
				st.add_index(i0); st.add_index(i1); st.add_index(i2)
				st.add_index(i1); st.add_index(i3); st.add_index(i2)
	var count := rings * (segs + 1)
	if cap and rings > 1:
		var c: Vector3 = pts[rings - 1]
		st.set_uv(Vector2(0, v))
		st.add_vertex(c - ((c - (pts[rings - 2] as Vector3)).normalized()) * (radii[rings - 1] as float) * 0.6)   # charred hollow
		var ci := start + count
		var last := start + (rings - 1) * (segs + 1)
		for j in segs:
			if flip:
				st.add_index(last + j); st.add_index(last + j + 1); st.add_index(ci)
			else:
				st.add_index(last + j); st.add_index(ci); st.add_index(last + j + 1)
		count += 1
	_counts[mat] = start + count


func _mesh(m: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## A tapered cylinder from a (radius ra) to b (radius rb), in local space.
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
	mesh.radial_segments = 7
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	add_child(mi)


func _build_markings() -> void:
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(1.0, 0.45, 0.05)
	tape.emission_enabled = true
	tape.emission = Color(0.6, 0.25, 0.0)
	tape.emission_energy_multiplier = 0.9
	_ring(2.2, 0.12, tape)

	# Painted ID on two sides of the trunk.
	for side in [0.0, PI]:
		var label := Label3D.new()
		label.text = tree_id
		label.font_size = 48
		label.pixel_size = 0.0032
		label.modulate = Color(0.92, 0.92, 0.88)
		label.outline_size = 0
		# Spray paint: only seen from its own side, and only when light hits it.
		label.double_sided = false
		label.shaded = true
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		var r := _trunk_r(1.6) * 1.12 + 0.01
		label.position = Vector3(sin(side) * r, 1.6, cos(side) * r)
		label.rotation.y = side
		add_child(label)


func _ring(y: float, band: float, mat: Material) -> MeshInstance3D:
	var r := _trunk_r(y) * 1.12 + 0.02
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = band
	mesh.radial_segments = 10
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = y
	add_child(mi)
	return mi
