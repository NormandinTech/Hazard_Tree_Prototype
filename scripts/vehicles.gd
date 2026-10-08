extends RefCounted
## Vehicle bodies with real silhouettes instead of stacked boxes.
##
## A body is a side profile (x = along the car, front toward +x; y = up)
## extruded across the width. The greenhouse narrows above the beltline like a
## real car, wheel arches are cut into the bottom edge, and individual edges
## of the outline can use other materials (glass for the windshield, dark for
## the wheel wells). Side windows are laid on as thin glass panels.

const SMOOTH_DEG := 32.0   # edges meeting at less than this shade smooth


## Builds an ArrayMesh from a profile. `edge_mat` maps an edge index (edge i
## runs from point i to point i+1) to a slot in `mats`; other edges use slot 0.
static func body(profile: PackedVector2Array, half_w: float, belt: float, top: float, taper: float,
		mats: Array, edge_mat: Dictionary, windows: Array, window_slot: int) -> ArrayMesh:
	var sts: Array = []
	for m in mats:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
	var hw := func(y: float) -> float:
		return half_w * (1.0 - taper * clampf((y - belt) / maxf(top - belt, 0.01), 0.0, 1.0))

	# The two sides.
	var tris := Geometry2D.triangulate_polygon(profile)
	for side in [1.0, -1.0]:
		var out := Vector3(0, 0, side)
		for i in range(0, tris.size(), 3):
			var p: Array = []
			for k in 3:
				var v: Vector2 = profile[tris[i + k]]
				p.append(Vector3(v.x, v.y, side * hw.call(v.y)))
			_tri(sts[0], p[0], p[1], p[2], out, out, out, out)

	# Around the outline.
	var n := profile.size()
	var edge_n: Array = []
	for i in n:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % n]
		var d := (b - a).normalized()
		edge_n.append(Vector3(d.y, -d.x, 0))   # outward for a counter-clockwise outline
	var cos_s := cos(deg_to_rad(SMOOTH_DEG))
	for i in n:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % n]
		var en: Vector3 = edge_n[i]
		var prev_n: Vector3 = edge_n[(i - 1 + n) % n]
		var next_n: Vector3 = edge_n[(i + 1) % n]
		var na := (en + prev_n).normalized() if en.dot(prev_n) > cos_s else en
		var nb := (en + next_n).normalized() if en.dot(next_n) > cos_s else en
		var st: SurfaceTool = sts[edge_mat.get(i, 0)]
		var a1 := Vector3(a.x, a.y, hw.call(a.y))
		var a2 := Vector3(a.x, a.y, -hw.call(a.y))
		var b1 := Vector3(b.x, b.y, hw.call(b.y))
		var b2 := Vector3(b.x, b.y, -hw.call(b.y))
		_tri(st, a1, b1, b2, en, na, nb, nb)
		_tri(st, a1, b2, a2, en, na, nb, na)

	# Side windows, a hair proud of the body.
	for w in windows:
		var poly: PackedVector2Array = w
		var wt := Geometry2D.triangulate_polygon(poly)
		for side in [1.0, -1.0]:
			var out := Vector3(0, 0, side)
			for i in range(0, wt.size(), 3):
				var p: Array = []
				for k in 3:
					var v: Vector2 = poly[wt[i + k]]
					p.append(Vector3(v.x, v.y, side * (hw.call(v.y) + 0.006)))
				_tri(sts[window_slot], p[0], p[1], p[2], out, out, out, out)

	var mesh := ArrayMesh.new()
	for i in sts.size():
		var arr: Array = (sts[i] as SurfaceTool).commit_to_arrays()
		if arr[Mesh.ARRAY_VERTEX] == null or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[i])
	return mesh


## One triangle, wound so its front faces `out` (Godot draws clockwise as front).
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, out: Vector3, n0: Vector3, n1: Vector3, n2: Vector3) -> void:
	var g := (p1 - p0).cross(p2 - p0)
	if g.dot(out) > 0.0:
		var t := p1; p1 = p2; p2 = t
		var tn := n1; n1 = n2; n2 = tn
	for pv in [[p0, n0], [p1, n1], [p2, n2]]:
		var v: Vector3 = pv[0]
		st.set_normal(pv[1])
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


## Points on a wheel arch, from the back of the arch over the top to the front.
static func _arch(cx: float, base_y: float, r: float, steps := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := PI - PI * float(i) / steps
		pts.append(Vector2(cx + cos(a) * r, base_y + sin(a) * r))
	return pts


# ---------- outlines ----------

## A mid-size sedan, 4.6 m. `wb` is half the wheelbase.
static func sedan_profile(wb := 1.35, arch_r := 0.4, suv := false) -> Dictionary:
	var by := 0.3   # bottom of the body
	var p := PackedVector2Array()
	var dark: Array = []
	p.append(Vector2(-2.3, by + 0.05))
	_add_arch(p, dark, _arch(-wb, by, arch_r))
	_add_arch(p, dark, _arch(wb, by, arch_r))
	var roof := 1.62 if suv else 1.42
	var g: Dictionary = {}
	p.append(Vector2(2.28, by + 0.05))
	p.append(Vector2(2.36, 0.52))      # bumper
	p.append(Vector2(2.34, 0.72))
	p.append(Vector2(2.22, 0.84))      # nose
	p.append(Vector2(1.6, 0.9))        # hood
	p.append(Vector2(0.95, 0.95))      # cowl
	g["windshield"] = p.size() - 1
	p.append(Vector2(0.28, roof - 0.04))
	p.append(Vector2(0.05, roof))
	if suv:
		p.append(Vector2(-1.9, roof - 0.02))
		g["rear_glass"] = p.size() - 1
		p.append(Vector2(-2.22, 1.1))
		p.append(Vector2(-2.3, 0.95))
	else:
		p.append(Vector2(-0.8, roof - 0.02))
		p.append(Vector2(-1.0, roof - 0.06))
		g["rear_glass"] = p.size() - 1
		p.append(Vector2(-1.75, 1.0))     # trunk lid
		p.append(Vector2(-2.22, 0.97))
	p.append(Vector2(-2.34, 0.72))
	p.append(Vector2(-2.36, 0.52))
	var wins: Array = []
	if suv:
		wins.append(PackedVector2Array([Vector2(0.86, 1.0), Vector2(0.27, roof - 0.1), Vector2(-0.35, roof - 0.1), Vector2(-0.35, 1.0)]))
		wins.append(PackedVector2Array([Vector2(-0.45, 1.0), Vector2(-0.45, roof - 0.1), Vector2(-1.2, roof - 0.1), Vector2(-1.2, 1.0)]))
		wins.append(PackedVector2Array([Vector2(-1.3, 1.0), Vector2(-1.3, roof - 0.1), Vector2(-1.88, roof - 0.1), Vector2(-2.12, 1.08), Vector2(-2.15, 1.0)]))
	else:
		wins.append(PackedVector2Array([Vector2(0.86, 1.0), Vector2(0.27, roof - 0.1), Vector2(-0.3, roof - 0.09), Vector2(-0.3, 1.0)]))
		wins.append(PackedVector2Array([Vector2(-0.4, 1.0), Vector2(-0.4, roof - 0.09), Vector2(-0.8, roof - 0.1), Vector2(-1.55, 1.02)]))
	return {"points": p, "windows": wins, "glass": g, "belt": 0.97, "top": roof, "arch_edges": dark}


## A pickup cab, front toward +x. Crew cab is 4 doors.
static func cab_profile(crew := true) -> Dictionary:
	var by := 0.6
	var back := -0.65 if crew else 0.55
	var p := PackedVector2Array()
	var dark: Array = []
	p.append(Vector2(back, by))
	_add_arch(p, dark, _arch(2.1, by - 0.12, 0.6, 10))
	p.append(Vector2(3.3, by))
	p.append(Vector2(3.34, 1.0))       # grille face
	p.append(Vector2(3.32, 1.42))
	p.append(Vector2(3.2, 1.54))       # hood lip
	p.append(Vector2(2.4, 1.6))
	p.append(Vector2(1.95, 1.63))      # cowl
	var g := {"windshield": p.size() - 1}
	p.append(Vector2(1.18, 2.26))
	p.append(Vector2(1.0, 2.32))
	p.append(Vector2(back + 0.12, 2.32))
	p.append(Vector2(back, 2.24))
	var wins: Array = []
	wins.append(PackedVector2Array([Vector2(1.86, 1.68), Vector2(1.17, 2.2), Vector2(0.4 if crew else back + 0.12, 2.2), Vector2(0.4 if crew else back + 0.12, 1.68)]))
	if crew:
		wins.append(PackedVector2Array([Vector2(0.3, 1.68), Vector2(0.3, 2.2), Vector2(back + 0.14, 2.2), Vector2(back + 0.14, 1.68)]))
	return {"points": p, "windows": wins, "glass": g, "belt": 1.64, "top": 2.32, "arch_edges": dark}


## Appends arch points and records the edges inside the arch (plus the
## stretch of underbody just before it) as wheel-well edges.
static func _add_arch(p: PackedVector2Array, dark: Array, arch: PackedVector2Array) -> void:
	dark.append(p.size() - 1)
	var start := p.size()
	p.append_array(arch)
	for k in arch.size() - 1:
		dark.append(start + k)


# ---------- parts ----------

## A wheel with its axle along z. Burned wheels are bare rims.
static func wheel(parent: Node3D, pos: Vector3, r: float, w: float, tire: Material, rim: Material, hub: Material, burned := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	if not burned:
		_cyl_in(root, r, r, w, Vector3.ZERO, tire, Vector3(90, 0, 0), 28)
		# Rounded sidewalls.
		for s in [1.0, -1.0]:
			var tor := TorusMesh.new()
			tor.inner_radius = r * 0.62
			tor.outer_radius = r * 0.98
			tor.rings = 28
			tor.ring_segments = 8
			tor.material = tire
			var tm := MeshInstance3D.new()
			tm.mesh = tor
			tm.rotation_degrees = Vector3(90, 0, 0)
			tm.position = Vector3(0, 0, s * w * 0.32)
			tm.scale = Vector3(1, 0.35, 1)
			root.add_child(tm)
	var rr := r * (0.62 if not burned else 0.72)
	_cyl_in(root, rr, rr, w + 0.02, Vector3.ZERO, rim, Vector3(90, 0, 0), 24)
	_cyl_in(root, rr * 0.35, rr * 0.35, w + 0.05, Vector3.ZERO, hub, Vector3(90, 0, 0), 12)
	# Lug nuts.
	for s in [1.0, -1.0]:
		for i in 5:
			var a := TAU * i / 5.0
			_cyl_in(root, 0.018, 0.018, w + 0.07, Vector3(cos(a), sin(a), 0) * rr * 0.55, hub, Vector3(90, 0, 0), 6)
	return root


static func _cyl_in(parent: Node3D, top_r: float, bottom_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3, seg := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = seg
	mesh.rings = 1
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box_in(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func mesh_in(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## Materials for a car: {paint, glass, dark, chrome, tire, light, tail}.
## A whole car in its own node, front toward +x, sitting on y = 0.
static func car(m: Dictionary, burned := false, suv := false) -> Node3D:
	var root := Node3D.new()
	var prof := sedan_profile(1.35, 0.4, suv)
	var edge := {}
	for e in prof["arch_edges"]:
		edge[e] = 2
	edge[prof["glass"]["windshield"]] = 1
	edge[prof["glass"]["rear_glass"]] = 1
	var mats := [m["paint"], m["glass"], m["dark"]]
	var mesh := body(prof["points"], 0.9, prof["belt"], prof["top"], 0.16, mats, edge, prof["windows"], 1)
	var drop := 0.12 if burned else 0.0   # tires gone, it sits on its rims
	var b := mesh_in(root, mesh, Vector3(0, -drop, 0))
	b.name = "Body"
	for wx in [-1.35, 1.35]:
		for wz in [-0.78, 0.78]:
			wheel(root, Vector3(wx, 0.32 - drop * 1.6, wz), 0.32, 0.2, m["tire"], m["chrome"] if not burned else m["paint"], m["dark"], burned)
	# Bumpers, lights, mirrors, handles.
	box_in(root, Vector3(0.12, 0.16, 1.7), Vector3(2.33, 0.45 - drop, 0), m["chrome"] if not burned else m["dark"])
	box_in(root, Vector3(0.12, 0.16, 1.7), Vector3(-2.33, 0.45 - drop, 0), m["chrome"] if not burned else m["dark"])
	for s in [1.0, -1.0]:
		box_in(root, Vector3(0.06, 0.1, 0.36), Vector3(2.3, 0.74 - drop, s * 0.58), m["light"])
		box_in(root, Vector3(0.06, 0.12, 0.3), Vector3(-2.3, 0.8 - drop, s * 0.62), m["tail"])
		box_in(root, Vector3(0.14, 0.08, 0.1), Vector3(0.82, 1.02 - drop, s * 0.95), m["dark"])      # mirror
		for hx in [0.25, -0.6]:
			box_in(root, Vector3(0.16, 0.025, 0.02), Vector3(hx, 0.9 - drop, s * 0.9), m["chrome"] if not burned else m["dark"])
		# Door seams.
		for sx in [0.88, -0.35, -1.45]:
			box_in(root, Vector3(0.012, 0.55, 0.01), Vector3(sx, 0.72 - drop, s * 0.902), m["dark"])
	return root
