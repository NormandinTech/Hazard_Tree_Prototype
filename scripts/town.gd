extends Node3D

const SurfacesScript = preload("res://scripts/surfaces.gd")
const VehiclesScript = preload("res://scripts/vehicles.gd")
## The burned-out foothill neighborhood, built in code: roads, house ruins
## (standing chimneys, slabs, mobile-home frames, burned cars), utility poles,
## mailboxes, street signs and ground debris.
##
## The town is fictional. Change TOWN_NAME and the street names here.

const TOWN_NAME := "KESTREL RIDGE"
const STREET_MAIN := "RIDGELINE RD"
const STREET_WEST := "OLD MILL RD"
const STREET_EAST := "CLEARVIEW DR"

const MAIN_ROAD_Z := 16.0
const SIDE_ROADS_X := [-46.0, 46.0]
const SIDE_ROAD_END_Z := -110.0
const ROAD_W := 8.0
const UTILITY := "SIERRA NORTHERN POWER"
const ORIGIN_POS := Vector3(-16, 0, -96)   # Line 7, Tower 7/22: where it started
const SNP_TRUCK_POS := Vector3(-46, 0, -40)

# Hand-placed ruins inside the work parcel, in gaps checked against every
# shift's trees, figure spots, phantoms and the stump hole. [position, kind, yaw]
const PARCEL_LOTS := [
	[Vector3(-26, 0, -2), "house", 0.0],
	[Vector3(30, 0, -2), "mobile", 90.0],
	[Vector3(35, 0, -47), "house", 90.0],
	[Vector3(28, 0, -80), "slab", 0.0],
	[Vector3(-34, 0, -74), "house", 180.0],
]

var keep_clear: Array = []   # [Vector3, radius] spots the game needs open
var footprints: Array = []   # [Vector3, radius] ruins that trees must avoid
var house_lots: Array = []   # {lot, chimney, chimney_pos, chimney_h, half, kind}
var mobile_lots: Array = []  # {lot, length}
var poles: Array = []        # {node, body, h, snapped, xfmr, top}
var origin_body: StaticBody3D
var ruins: Node3D            # everything burned (hidden during flashback frames)
var rng := RandomNumberGenerator.new()

var m_asphalt: StandardMaterial3D
var m_line: StandardMaterial3D
var m_concrete: StandardMaterial3D
var m_brick: StandardMaterial3D
var m_char: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_ash: StandardMaterial3D
var m_rock: StandardMaterial3D
var m_black: StandardMaterial3D
var m_burned_car: StandardMaterial3D
var car_nodes: Array = []   # burned cars, for places an animal might hide
var m_flue: StandardMaterial3D
var m_sheet_metal: StandardMaterial3D
var m_sheet_rust: StandardMaterial3D
var m_appliance: StandardMaterial3D
var m_sign: StandardMaterial3D


func build(clear: Array) -> void:
	keep_clear = clear
	rng.seed = 7741
	_materials()
	# Reserve the tower and the SNP truck before the lots go in.
	footprints.append([ORIGIN_POS, 6.0])
	footprints.append([SNP_TRUCK_POS, 4.5])
	_roads()
	var road_count := get_child_count()
	_lots()
	_mailboxes()
	_poles()
	_origin_tower()
	_snp_truck()
	_street_signs()
	_debris()
	_scatter()
	# Group everything but the roads so a flashback can hide it in one switch.
	ruins = Node3D.new()
	ruins.name = "Ruins"
	var burned: Array = []
	for i in range(road_count, get_child_count()):
		burned.append(get_child(i))
	add_child(ruins)
	for n in burned:
		n.reparent(ruins)


## True if a tree at `p` with radius `r` would sit on a road or inside a ruin.
func blocked(p: Vector3, r: float) -> bool:
	if _on_road(p, r):
		return true
	for f in footprints:
		if p.distance_to(f[0]) < f[1] + r:
			return true
	return false


# ---------- layout helpers ----------

func _on_road(p: Vector3, margin: float) -> bool:
	if abs(p.z - MAIN_ROAD_Z) < ROAD_W * 0.5 + margin:
		return true
	for x in SIDE_ROADS_X:
		if abs(p.x - x) < ROAD_W * 0.5 + margin and p.z < MAIN_ROAD_Z and p.z > SIDE_ROAD_END_Z:
			return true
	return false


func _free(p: Vector3, r: float) -> bool:
	if _on_road(p, r * 0.5):
		return false
	for k in keep_clear:
		if p.distance_to(k[0]) < k[1] + r:
			return false
	for f in footprints:
		if p.distance_to(f[0]) < f[1] + r:
			return false
	return true


# ---------- roads ----------

func _roads() -> void:
	_box(self, Vector3(260, 0.04, ROAD_W), Vector3(0, 0.02, MAIN_ROAD_Z), m_asphalt)
	var x := -128.0
	while x < 128.0:
		_box(self, Vector3(3.0, 0.01, 0.15), Vector3(x, 0.045, MAIN_ROAD_Z), m_line)
		x += 7.0
	var length := MAIN_ROAD_Z - SIDE_ROAD_END_Z
	for sx in SIDE_ROADS_X:
		_box(self, Vector3(ROAD_W, 0.04, length), Vector3(sx, 0.021, (MAIN_ROAD_Z + SIDE_ROAD_END_Z) * 0.5), m_asphalt)
		var z := MAIN_ROAD_Z - ROAD_W
		while z > SIDE_ROAD_END_Z + 2.0:
			_box(self, Vector3(0.15, 0.01, 3.0), Vector3(sx, 0.045, z), m_line)
			z -= 7.0


# ---------- lots and ruins ----------

func _lots() -> void:
	for entry in PARCEL_LOTS:
		var r := 10.0 if entry[1] == "mobile" else 7.0
		footprints.append([entry[0], r - 1.0])
		var plot := Node3D.new()
		plot.position = entry[0]
		plot.rotation_degrees.y = entry[2]
		add_child(plot)
		match entry[1]:
			"house": _house(plot)
			"mobile": _mobile(plot)
			_: _slab_only(plot)
	var gx := -104
	while gx <= 104:
		var gz := -104
		while gz <= 40:
			var p := Vector3(gx + rng.randf_range(-3.0, 3.0), 0.0, gz + rng.randf_range(-3.0, 3.0))
			gz += 24
			var roll := rng.randf()
			var kind := "house"
			var r := 8.0
			if roll < 0.25:
				kind = "mobile"
				r = 10.0
			elif roll < 0.40:
				kind = "garage"
				r = 6.0
			elif roll < 0.55:
				kind = "slab"
				r = 7.0
			if not _free(p, r):
				continue
			footprints.append([p, r - 1.0])
			var lot := Node3D.new()
			lot.position = p
			lot.rotation.y = rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.08, 0.08)
			add_child(lot)
			match kind:
				"house": _house(lot)
				"mobile": _mobile(lot)
				"garage": _garage(lot)
				_: _slab_only(lot)
		gx += 24


func _house(lot: Node3D) -> void:
	_box(lot, Vector3(12, 0.3, 10), Vector3(0, 0.15, 0), m_concrete)
	_box(lot, Vector3(11.4, 0.06, 9.4), Vector3(0, 0.33, 0), m_ash)
	var cpos := Vector3(rng.randf_range(-4.5, 4.5), 0.3, -4.2)
	var ch := rng.randf_range(5.0, 7.0)
	var body := _chimney(lot, cpos, ch)
	house_lots.append({"lot": lot, "chimney": body, "chimney_pos": cpos, "chimney_h": ch, "half": Vector2(6, 5), "kind": "house"})
	_rubble(lot, 14, Vector2(5.0, 4.0))
	_roofing(lot, 6, Vector2(5.0, 4.0))
	_water_heater(lot, Vector3(4.6, 0.3, 3.6))
	if rng.randf() < 0.6:
		_appliance(lot, Vector3(-4.2, 0.3, 3.2))
	# Front steps survive; the house they led to didn't.
	_box(lot, Vector3(2.0, 0.3, 0.8), Vector3(0, 0.15, 5.4), m_concrete)
	_box(lot, Vector3(2.0, 0.15, 0.6), Vector3(0, 0.075, 6.1), m_concrete)
	for i in rng.randi_range(2, 5):
		var h := rng.randf_range(0.8, 2.4)
		_box(lot, Vector3(0.1, h, 0.15), Vector3(rng.randf_range(-5.6, 5.6), 0.3 + h * 0.5, (-4.8 if rng.randf() < 0.5 else 4.8)), m_char,
			Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
	if rng.randf() < 0.45:
		_car(lot, Vector3(8.6, 0, rng.randf_range(-2.0, 2.0)), rng.randf_range(-0.2, 0.2) + PI * 0.5)


func _mobile(lot: Node3D) -> void:
	# Steel chassis on block piers, all that's left of a manufactured home.
	var length := rng.randf_range(15.0, 19.0)
	mobile_lots.append({"lot": lot, "length": length})
	for side in [-1.4, 1.4]:
		_box(lot, Vector3(length, 0.28, 0.12), Vector3(0, 0.75, side), m_rust)
	var x := -length * 0.5 + 0.6
	while x < length * 0.5:
		_box(lot, Vector3(0.1, 0.12, 3.0), Vector3(x, 0.8, 0), m_rust)
		_box(lot, Vector3(0.4, 0.6, 0.4), Vector3(x, 0.3, -1.4), m_concrete)
		_box(lot, Vector3(0.4, 0.6, 0.4), Vector3(x, 0.3, 1.4), m_concrete)
		x += 2.4
	# Hitch tongue.
	var tip := Vector3(-length * 0.5 - 1.8, 0.75, 0)
	_beam(Vector3(-length * 0.5, 0.75, -1.4), tip, 0.06, m_rust, lot)
	_beam(Vector3(-length * 0.5, 0.75, 1.4), tip, 0.06, m_rust, lot)
	# Axle and bare hubs.
	for ax in [length * 0.12, length * 0.12 + 1.0]:
		_cyl(lot, 0.05, 0.05, 3.2, Vector3(ax, 0.45, 0), m_rust, Vector3(90, 0, 0))
		for hz in [-1.65, 1.65]:
			_cyl(lot, 0.28, 0.28, 0.18, Vector3(ax, 0.45, hz), m_metal, Vector3(90, 0, 0))
	_roofing(lot, 9, Vector2(length * 0.5, 2.6))
	_rubble(lot, 8, Vector2(length * 0.45, 2.0))
	_water_heater(lot, Vector3(length * 0.3, 0.0, 2.6))
	_box(lot, Vector3(1.2, 0.5, 1.0), Vector3(-length * 0.2, 0.25, 2.3), m_char)


func _garage(lot: Node3D) -> void:
	_box(lot, Vector3(7, 0.25, 6.5), Vector3(0, 0.125, 0), m_concrete)
	_box(lot, Vector3(6.6, 0.05, 6.1), Vector3(0, 0.27, 0), m_ash)
	_car(lot, Vector3(0, 0.25, 0.3), rng.randf_range(-0.15, 0.15))
	_roofing(lot, 5, Vector2(3.2, 3.0))
	_box(lot, Vector3(0.6, 1.1, 1.4), Vector3(-3.0, 0.8, -2.2), m_rust)  # tool chest


func _slab_only(lot: Node3D) -> void:
	_box(lot, Vector3(10, 0.3, 8), Vector3(0, 0.15, 0), m_concrete)
	_box(lot, Vector3(9.4, 0.06, 7.4), Vector3(0, 0.33, 0), m_ash)
	var cpos := Vector3(rng.randf_range(-3.5, 3.5), 0.3, 3.4)
	var ch := rng.randf_range(1.5, 3.0)
	var body := _chimney(lot, cpos, ch)
	house_lots.append({"lot": lot, "chimney": body, "chimney_pos": cpos, "chimney_h": ch, "half": Vector2(5, 4), "kind": "slab"})
	_rubble(lot, 10, Vector2(4.2, 3.2))
	_roofing(lot, 3, Vector2(4.0, 3.0))


func _chimney(lot: Node3D, base: Vector3, h: float) -> StaticBody3D:
	# The signature ruin: a brick chimney standing alone over the slab.
	# Firebox at the bottom, sloped shoulders, a narrower stack, a corbel band,
	# and a top that's lost bricks. Front (the fireplace) faces +Z.
	var body := StaticBody3D.new()
	body.position = base
	body.rotation_degrees = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-4, 4), rng.randf_range(-1.5, 1.5))
	lot.add_child(body)
	var bw := 1.8
	var bd := 1.15
	_box(body, Vector3(2.2, 0.22, 1.7), Vector3(0, 0.11, 0.25), m_concrete)      # hearth slab
	var fb := minf(1.5, h)
	_box(body, Vector3(bw, fb, bd), Vector3(0, fb * 0.5, 0), m_brick)            # firebox
	if fb > 0.9:
		_box(body, Vector3(0.9, 0.75, 0.5), Vector3(0, 0.6, bd * 0.5 - 0.22), m_black)   # opening
		_box(body, Vector3(1.1, 0.08, 0.12), Vector3(0, 1.0, bd * 0.5 + 0.02), m_rust)  # lintel
	var top := fb
	if h > 2.8:
		# Shoulders: slope from the firebox in to the stack, exactly matching both.
		var sh := 0.7
		var fm := MeshInstance3D.new()
		fm.mesh = _frustum(Vector2(bw, bd), Vector2(1.05, 0.78), sh, -0.05, m_brick)
		fm.position = Vector3(0, fb, 0)
		body.add_child(fm)
		top = fb + sh
		var stack_h := h - top
		_box(body, Vector3(1.05, stack_h, 0.78), Vector3(0, top + stack_h * 0.5, -0.05), m_brick)
		_box(body, Vector3(1.17, 0.16, 0.9), Vector3(0, h - 0.45, -0.05), m_brick)      # corbel band
		top = h
	elif h > fb:
		_box(body, Vector3(bw * 0.8, h - fb, bd * 0.85), Vector3(0, fb + (h - fb) * 0.5, -0.03), m_brick)
		top = h
	# Broken top: chunks of brick courses at uneven heights, some missing.
	var tw := 1.05 if h > 2.8 else bw * 0.8
	var x := -tw * 0.5 + 0.13
	while x < tw * 0.5:
		var courses := rng.randi_range(0, 4)
		if courses > 0:
			var ch := courses * 0.075
			_box(body, Vector3(0.24, ch, 0.7), Vector3(x, top + ch * 0.5, -0.05), m_brick, Vector3(0, 0, rng.randf_range(-3, 3)))
		x += 0.26
	if h > 2.8 and rng.randf() < 0.75:
		# Terracotta flue liner sticking out of the top.
		var fl := CylinderMesh.new()
		fl.radial_segments = 4
		fl.rings = 1
		fl.top_radius = 0.24
		fl.bottom_radius = 0.24
		fl.height = 0.6
		fl.material = m_flue
		var fm2 := MeshInstance3D.new()
		fm2.mesh = fl
		fm2.rotation_degrees = Vector3(rng.randf_range(-4, 4), 45, rng.randf_range(-4, 4))
		fm2.position = Vector3(rng.randf_range(-0.1, 0.1), top + 0.3, -0.05)
		body.add_child(fm2)
		_box(body, Vector3(0.24, 0.02, 0.24), Vector3(fm2.position.x, top + 0.59, -0.05), m_black, Vector3(0, 45, 0))
	# Bricks that came off it, lying around the base.
	for i in rng.randi_range(6, 14):
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(1.0, 2.6)
		_box(body, Vector3(0.21, 0.065, 0.1), Vector3(cos(a) * d, 0.04 + rng.randf() * 0.04, sin(a) * d), m_brick,
			Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, h, 1.3)
	col.shape = shape
	col.position.y = h * 0.5
	body.add_child(col)
	return body


func _car(lot: Node3D, pos: Vector3, yaw: float) -> void:
	var car := StaticBody3D.new()
	car.position = pos
	car.rotation = Vector3(rng.randf_range(-0.04, 0.04), yaw, rng.randf_range(-0.05, 0.05))
	lot.add_child(car)
	car_nodes.append(car)
	# Burned to bare metal: paint gone, glass gone, tires gone, sitting on its rims.
	if m_burned_car == null:
		# Burned paint goes ash-gray and flaky, with rust coming through.
		m_burned_car = _noise_mat(Color(0.17, 0.1, 0.065), Color(0.4, 0.38, 0.35), 0.45, Vector3(3, 3, 1), "rust", Color(0.75, 0.7, 0.66))
	var m := {"paint": m_burned_car, "glass": m_black, "dark": m_black, "chrome": m_metal,
		"tire": m_black, "light": m_black, "tail": m_black}
	car.add_child(VehiclesScript.car(m, true, rng.randf() < 0.35))
	# A little ash heap where the seats were, showing through the windows.
	_box(car, Vector3(1.8, 0.25, 1.4), Vector3(-0.3, 0.55, 0), m_ash)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.3, 1.5, 1.8)
	col.shape = shape
	col.position.y = 0.75
	car.add_child(col)


func _water_heater(lot: Node3D, pos: Vector3) -> void:
	var tilt := rng.randf_range(-8.0, 8.0)
	_cyl(lot, 0.28, 0.28, 1.4, pos + Vector3(0, 0.7, 0), m_appliance, Vector3(tilt, 0, rng.randf_range(-6.0, 6.0)))


func _appliance(lot: Node3D, pos: Vector3) -> void:
	_box(lot, Vector3(0.75, 0.9, 0.7), pos + Vector3(0, 0.45, 0), m_appliance, Vector3(0, rng.randf_range(-20, 20), rng.randf_range(-6, 6)))
	if rng.randf() < 0.5:
		_box(lot, Vector3(0.75, 0.9, 0.7), pos + Vector3(0.85, 0.45, 0), m_rust, Vector3(0, rng.randf_range(-20, 20), 0))


func _rubble(lot: Node3D, n: int, half: Vector2) -> void:
	for i in n:
		var s := Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.1, 0.35), rng.randf_range(0.2, 0.8))
		var p := Vector3(rng.randf_range(-half.x, half.x), 0.3 + s.y * 0.4, rng.randf_range(-half.y, half.y))
		var mat := m_char if rng.randf() < 0.6 else (m_brick if rng.randf() < 0.5 else m_concrete)
		_box(lot, s, p, mat, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25)))


func _roofing(lot: Node3D, n: int, half: Vector2) -> void:
	# Twisted corrugated roofing, the most common debris after the fire.
	if _sheets.is_empty():
		for k in 6:
			_sheets.append(_corrugated(rng.randf_range(1.8, 3.2), rng.randf_range(0.7, 1.1), rng.randf_range(-0.35, 0.5), rng.randf_range(-0.25, 0.25)))
	for i in n:
		var p := Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(0.32, 0.6), rng.randf_range(-half.y, half.y))
		var mi := MeshInstance3D.new()
		mi.mesh = _sheets[rng.randi() % _sheets.size()]
		mi.material_override = m_sheet_metal if rng.randf() < 0.4 else m_sheet_rust
		mi.position = p
		mi.rotation_degrees = Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 360), rng.randf_range(-22, 22))
		lot.add_child(mi)


var _sheets: Array = []


## A box that narrows toward the top: base `b` (x, z) at y=0, top `tp` at y=h,
## top shifted along z by `dz`. Flat-shaded sides, open bottom.
func _frustum(b: Vector2, tp: Vector2, h: float, dz: float, mat: Material) -> ArrayMesh:
	var lo := [Vector3(-b.x, 0, -b.y) * 0.5, Vector3(b.x, 0, -b.y) * 0.5, Vector3(b.x, 0, b.y) * 0.5, Vector3(-b.x, 0, b.y) * 0.5]
	var hi: Array = []
	for v in [Vector3(-tp.x, 0, -tp.y), Vector3(tp.x, 0, -tp.y), Vector3(tp.x, 0, tp.y), Vector3(-tp.x, 0, tp.y)]:
		hi.append(v * 0.5 + Vector3(0, h, dz))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, h * 0.5, dz * 0.5)
	var quads := [[lo[0], lo[1], hi[1], hi[0]], [lo[1], lo[2], hi[2], hi[1]], [lo[2], lo[3], hi[3], hi[2]], [lo[3], lo[0], hi[0], hi[3]], [hi[0], hi[1], hi[2], hi[3]]]
	for q in quads:
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var a: Vector3 = tri[0]
			var bb: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var out := ((a + bb + c) / 3.0 - center)
			var g := (bb - a).cross(c - a)
			if g.dot(out) > 0.0:
				var tmp := bb; bb = c; c = tmp
			var n := -(bb - a).cross(c - a).normalized()
			for v in [a, bb, c]:
				st.set_normal(n)
				st.set_uv(Vector2(v.x + v.z, v.y))
				st.add_vertex(v)
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A corrugated sheet, length along x, ribs along x, with a curl and a twist.
func _corrugated(length: float, width: float, curl: float, twist: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 20
	var nz := int(width / 0.019)
	for ix in nx + 1:
		var u := float(ix) / nx
		var x := (u - 0.5) * length
		for iz in nz + 1:
			var w := float(iz) / nz
			var z := (w - 0.5) * width
			var y := 0.018 * sin(z * TAU / 0.076) + curl * u * u * length * 0.3 + twist * x * z
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, y, z))
	for ix in nx:
		for iz in nz:
			var a := ix * (nz + 1) + iz
			var b := a + 1
			var c := a + nz + 1
			var d := c + 1
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(d)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# ---------- street furniture ----------

func _mailboxes() -> void:
	var x := -100.0
	while x <= 100.0:
		var p := Vector3(x + rng.randf_range(-2.0, 2.0), 0, MAIN_ROAD_Z - ROAD_W * 0.5 - 1.2)
		x += 24.0
		if not _free(p, 1.0):
			continue
		var lean := Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-14, 14))
		var post := Node3D.new()
		post.position = p
		post.rotation_degrees = lean
		add_child(post)
		_box(post, Vector3(0.1, 1.1, 0.1), Vector3(0, 0.55, 0), m_char)
		_box(post, Vector3(0.28, 0.25, 0.5), Vector3(0, 1.15, 0), m_rust, Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-20, 20)))


func _poles() -> void:
	var lines: Array = []
	var row: Array = []
	var x := -112.0
	while x <= 112.0:
		row.append(Vector3(x, 0, MAIN_ROAD_Z - ROAD_W * 0.5 - 2.5))
		x += 32.0
	lines.append(row)
	for sx in SIDE_ROADS_X:
		row = []
		var z := MAIN_ROAD_Z - ROAD_W
		while z > SIDE_ROAD_END_Z:
			row.append(Vector3(sx + ROAD_W * 0.5 + 2.5, 0, z))
			z -= 32.0
		lines.append(row)

	for line in lines:
		var prev_top = null
		for base in line:
			if not _free(base, 0.5):
				prev_top = null
				continue
			var snapped := rng.randf() < 0.2
			var h := rng.randf_range(2.5, 4.0) if snapped else 9.0
			var lean := Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
			var pole := StaticBody3D.new()
			pole.position = base
			pole.rotation_degrees = lean
			add_child(pole)
			_cyl(pole, 0.13, 0.17, h, Vector3(0, h * 0.5, 0), m_char)
			var pcol := CollisionShape3D.new()
			var pshape := CylinderShape3D.new()
			pshape.radius = 0.4
			pshape.height = h
			pcol.shape = pshape
			pcol.position.y = h * 0.5
			pole.add_child(pcol)
			var info := {"node": pole, "body": pole, "h": h, "snapped": snapped, "xfmr": null}
			poles.append(info)
			if snapped:
				prev_top = null
				continue
			_box(pole, Vector3(2.4, 0.12, 0.12), Vector3(0, h - 0.5, 0), m_char)
			if rng.randf() < 0.3:
				add_transformer(info)
			var top: Vector3 = pole.transform * Vector3(0, h - 0.45, 0)
			if prev_top != null:
				for off in [-1.0, 1.0]:
					var a: Vector3 = prev_top + _side_offset(prev_top, top, off)
					var b: Vector3 = top + _side_offset(prev_top, top, off)
					var mid := (a + b) * 0.5 - Vector3(0, rng.randf_range(0.6, 1.4), 0)
					_beam(a, mid, 0.012, m_black)
					_beam(mid, b, 0.012, m_black)
			prev_top = top


## A transformer can on a pole, solid so it can be filmed on its own.
func add_transformer(info: Dictionary) -> StaticBody3D:
	if info["xfmr"] != null:
		return info["xfmr"]
	var pole: Node3D = info["node"]
	var h: float = info["h"]
	var can := StaticBody3D.new()
	can.position = Vector3(0.5, h - 1.4, 0.25)
	pole.add_child(can)
	_cyl(can, 0.25, 0.25, 0.8, Vector3.ZERO, m_metal)
	_cyl(can, 0.27, 0.27, 0.06, Vector3(0, 0.42, 0), m_rust)
	_box(can, Vector3(0.08, 0.2, 0.08), Vector3(0.12, 0.5, 0), m_appliance)   # bushing
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 1.0, 0.7)
	col.shape = shape
	can.add_child(col)
	info["xfmr"] = can
	return can


## Oil weeping down the pole from a cracked transformer, pooling at the base.
func add_oil_leak(info: Dictionary) -> void:
	var pole: Node3D = info["node"]
	var h: float = info["h"]
	var oil := StandardMaterial3D.new()
	oil.albedo_color = Color(0.03, 0.025, 0.015)
	oil.roughness = 0.1
	oil.metallic = 0.3
	_box(pole, Vector3(0.05, h - 1.8, 0.05), Vector3(0.18, (h - 1.8) * 0.5, 0.17), oil)
	var pool := _cyl(pole, 1.1, 1.1, 0.01, Vector3(0.4, 0.015, 0.3), oil)
	(pool.mesh as CylinderMesh).radial_segments = 18


## Line 7, Tower 7/22: a steel lattice tower. One insulator string hangs empty,
## its hook worn through. The conductor it held lies in the ash, pointing at the hole.
func _origin_tower() -> void:
	var t := StaticBody3D.new()
	t.position = ORIGIN_POS
	t.rotation_degrees.y = 25.0
	add_child(t)
	origin_body = t
	var steel := _noise_mat(Color(0.22, 0.22, 0.22), Color(0.36, 0.33, 0.30), 0.3, Vector3(1, 6, 1), "rust", Color(0.6, 0.55, 0.5))
	steel.metallic = 0.6
	var top_h := 22.0
	var legs := [Vector3(2.4, 0, 2.4), Vector3(-2.4, 0, 2.4), Vector3(-2.4, 0, -2.4), Vector3(2.4, 0, -2.4)]
	var tops: Array = []
	for l in legs:
		var tp: Vector3 = l * 0.25 + Vector3(0, top_h, 0)
		tops.append(tp)
		_beam(l, tp, 0.09, steel, t)
		_box(t, Vector3(0.6, 0.4, 0.6), l + Vector3(0, 0.2, 0), m_concrete)   # footing
	# Cross bracing up each face.
	for i in 4:
		var a: Vector3 = legs[i]
		var b: Vector3 = legs[(i + 1) % 4]
		var at: Vector3 = tops[i]
		var bt: Vector3 = tops[(i + 1) % 4]
		for k in 5:
			var f0 := k / 5.0
			var f1 := (k + 1) / 5.0
			var p0 := a.lerp(at, f0)
			var q0 := b.lerp(bt, f0)
			var p1 := a.lerp(at, f1)
			var q1 := b.lerp(bt, f1)
			_beam(p0, q1, 0.035, steel, t)
			_beam(q0, p1, 0.035, steel, t)
			_beam(p1, q1, 0.035, steel, t)
	# Cross arms with insulator strings. The right-hand one is empty.
	for arm_y in [top_h - 1.0, top_h - 4.5]:
		_box(t, Vector3(9.0, 0.25, 0.4), Vector3(0, arm_y, 0), steel)
		for ax in [-4.0, 4.0]:
			var broken: bool = ax > 0.0 and arm_y < top_h - 2.0
			var hook := Vector3(ax, arm_y - 0.15, 0)
			_cyl(t, 0.05, 0.05, 0.2, hook, m_rust)   # the hook
			if broken:
				# The worn hook, and the string that fell from it.
				_box(t, Vector3(0.04, 0.1, 0.12), hook + Vector3(0.05, -0.1, 0), m_rust, Vector3(0, 0, 35))
				continue
			for k in 6:
				_cyl(t, 0.12, 0.12, 0.08, hook + Vector3(0, -0.25 - k * 0.22, 0), m_appliance)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.5, top_h, 5.5)
	col.shape = shape
	col.position.y = top_h * 0.5
	t.add_child(col)
	# Danger plate.
	_box(t, Vector3(1.2, 0.8, 0.03), Vector3(0, 3.0, 2.0), m_sign)
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "%s\nLINE 7 · TOWER 7/22\nDANGER · HIGH VOLTAGE" % UTILITY
		l.font_size = 64
		l.pixel_size = 0.0035
		l.modulate = Color(0.85, 0.82, 0.7)
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.position = Vector3(0, 3.0, 2.0 + 0.02 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		t.add_child(l)
	# The fallen conductor, from the tower to where the great pine stood.
	var hole := Vector3(-4, 0, -80)
	var start: Vector3 = t.transform * Vector3(4.0, top_h - 5.0, 0)
	var mid := start.lerp(hole, 0.25) + Vector3(0, 0.0, 0)
	mid.y = 0.05
	_beam(start, mid, 0.025, m_black)
	_beam(mid, hole.lerp(start, 0.15) + Vector3(0, 0.04, 0), 0.025, m_black)


## A Sierra Northern Power bucket truck, burned where it was parked the day after.
func _snp_truck() -> void:
	var tr := StaticBody3D.new()
	tr.position = SNP_TRUCK_POS
	tr.rotation_degrees.y = 4.0
	add_child(tr)
	# Burned cab: same shape as a pickup, paint and glass gone, front toward -Z.
	var prof := VehiclesScript.cab_profile(false)
	var edge := {}
	for e in prof["arch_edges"]:
		edge[e] = 2
	edge[prof["glass"]["windshield"]] = 1
	var cab := MeshInstance3D.new()
	cab.mesh = VehiclesScript.body(prof["points"], 1.0, prof["belt"], prof["top"], 0.08,
		[m_char, m_black, m_black], edge, prof["windows"], 1)
	cab.rotation_degrees.y = 90.0
	cab.position = Vector3(0, -0.14, -0.25)
	tr.add_child(cab)
	_box(tr, Vector3(1.6, 0.32, 0.05), Vector3(0, 1.05, -3.61), m_black)     # grille, burned out
	# Frame and utility body behind the cab.
	_box(tr, Vector3(1.3, 0.25, 6.6), Vector3(0, 0.45, 0.2), m_black)
	_box(tr, Vector3(2.2, 1.0, 4.3), Vector3(0, 0.95, 1.45), m_rust)
	_box(tr, Vector3(2.0, 0.6, 4.1), Vector3(0, 1.75, 1.45), m_metal)
	for sx in [1.0, -1.0]:
		for dz in [0.0, 1.4, 2.8]:
			_box(tr, Vector3(0.01, 0.85, 0.02), Vector3(sx * 1.103, 0.95, dz - 0.25), m_black)
	# The tires burned off; it sits on bare steel rims.
	for wz in [-2.35, 1.0, 2.6]:
		for wx in [-1.0, 1.0]:
			var wh := VehiclesScript.wheel(tr, Vector3(wx, 0.34, wz), 0.42, 0.24, m_black, m_rust, m_black, true)
			wh.rotation_degrees.y = 90.0
	# Boom and bucket, frozen halfway up.
	var pivot := Vector3(0, 2.1, 2.5)
	var elbow := Vector3(0.2, 5.2, 0.6)
	var tip := Vector3(0.4, 6.4, -2.2)
	_beam(pivot, elbow, 0.12, m_rust, tr)
	_beam(elbow, tip, 0.1, m_rust, tr)
	_box(tr, Vector3(0.9, 1.0, 0.9), tip + Vector3(0, -0.4, 0), m_char)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.3, 2.6, 7.3)
	col.shape = shape
	col.position.y = 1.3
	tr.add_child(col)
	# The door lettering, scorched but still readable.
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "SIERRA NORTHERN POWER\nUNIT 7-114"
		l.font_size = 40
		l.pixel_size = 0.0026
		l.line_spacing = 6.0
		l.modulate = Color(0.42, 0.38, 0.31)
		l.outline_size = 0
		l.double_sided = false
		l.shaded = true
		l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		l.width = 600.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector3(1.012 * side, 1.18, -1.5)
		l.rotation.y = PI * 0.5 * side
		tr.add_child(l)


func _side_offset(a: Vector3, b: Vector3, amount: float) -> Vector3:
	var d := (b - a)
	d.y = 0.0
	return d.normalized().cross(Vector3.UP) * amount


func _street_signs() -> void:
	for sx in SIDE_ROADS_X:
		var p := Vector3(sx + ROAD_W * 0.5 + 1.0, 0, MAIN_ROAD_Z - ROAD_W * 0.5 - 1.0)
		var post := Node3D.new()
		post.position = p
		post.rotation_degrees = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		add_child(post)
		_cyl(post, 0.04, 0.04, 2.8, Vector3(0, 1.4, 0), m_metal)
		_sign_blade(post, STREET_MAIN, Vector3(0, 2.65, 0), 0.0)
		_sign_blade(post, STREET_WEST if sx < 0 else STREET_EAST, Vector3(0, 2.4, 0), PI * 0.5)


func _sign_blade(parent: Node3D, text: String, pos: Vector3, yaw: float) -> void:
	var blade := Node3D.new()
	blade.position = pos
	blade.rotation.y = yaw
	parent.add_child(blade)
	_box(blade, Vector3(1.5, 0.22, 0.03), Vector3.ZERO, m_sign, Vector3(0, 0, rng.randf_range(-6, 6)))
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 40
		l.pixel_size = 0.0035
		l.modulate = Color(0.85, 0.85, 0.8)
		l.outline_size = 0
		l.position = Vector3(0, 0, 0.02 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		blade.add_child(l)


# ---------- ground debris ----------

func _debris() -> void:
	for i in 220:
		var p := Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-110, 60))
		if _on_road(p, 0.0):
			continue
		var s := rng.randf_range(0.15, 0.7)
		var m := SphereMesh.new()
		m.radius = s
		m.height = s * rng.randf_range(0.7, 1.2)
		m.radial_segments = 6
		m.rings = 3
		m.material = m_rock
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = p + Vector3(0, s * 0.15, 0)
		mi.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		add_child(mi)
	for i in 90:
		var p := Vector3(rng.randf_range(-110, 110), 0.012, rng.randf_range(-110, 60))
		if _on_road(p, 0.0):
			continue
		var r := rng.randf_range(0.7, 2.2)
		var patch_mi := _cyl(self, r, r, 0.01, p, m_ash)
		(patch_mi.mesh as CylinderMesh).radial_segments = 20
	var logs := 0
	var tries := 0
	while logs < 45 and tries < 500:
		tries += 1
		var p := Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-105, 55))
		if not _free(p, 3.0):
			continue
		var length := rng.randf_range(3.0, 9.0)
		var r := rng.randf_range(0.15, 0.4)
		_cyl(self, r * 0.7, r, length, p + Vector3(0, r * 0.8, 0), m_char,
			Vector3(90, rng.randf_range(0, 360), rng.randf_range(-4, 4)))
		logs += 1
	var stumps := 0
	tries = 0
	while stumps < 50 and tries < 500:
		tries += 1
		var p := Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-105, 55))
		if not _free(p, 1.0):
			continue
		var r := rng.randf_range(0.25, 0.6)
		var h := rng.randf_range(0.25, 0.9)
		_cyl(self, r * 0.9, r * 1.2, h, p + Vector3(0, h * 0.5, 0), m_char)
		stumps += 1


## Thousands of small things on the ground, drawn in a few batches:
## pebbles, charred twigs, and green shoots already coming back through the ash.
func _scatter() -> void:
	var pebble := SphereMesh.new()
	pebble.radius = 0.06
	pebble.height = 0.08
	pebble.radial_segments = 5
	pebble.rings = 2
	pebble.material = m_rock
	_multi(pebble, 6000, 0.6, 1.8, false)
	var twig := BoxMesh.new()
	twig.size = Vector3(0.03, 0.03, 0.5)
	twig.material = m_char
	_multi(twig, 3500, 0.5, 2.2, true)
	var shoot := CylinderMesh.new()
	shoot.top_radius = 0.0
	shoot.bottom_radius = 0.07
	shoot.height = 0.22
	shoot.radial_segments = 5
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.22, 0.42, 0.12)
	green.roughness = 0.8
	shoot.material = green
	_multi(shoot, 900, 0.7, 1.4, false, true)


func _multi(mesh: Mesh, count: int, smin: float, smax: float, lie_flat: bool, clumped := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var center := Vector3.ZERO
	for i in count:
		var p: Vector3
		if clumped and i % 6 != 0:
			p = center + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		else:
			p = Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-105, 55))
			center = p
		if _on_road(p, -0.5):
			p.y = -5.0   # tuck it under the ground rather than on the asphalt
		var sc := rng.randf_range(smin, smax)
		var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(sc, sc, sc))
		if lie_flat:
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		p.y += 0.02 * sc if p.y > -1.0 else 0.0
		mm.set_instance_transform(i, Transform3D(b, p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)


# ---------- materials ----------

func _materials() -> void:
	m_asphalt = _noise_mat(Color(0.10, 0.10, 0.10), Color(0.17, 0.16, 0.15), 0.08, Vector3(40, 1.2, 1), "asphalt", Color(0.8, 0.8, 0.8))
	m_line = _flat(Color(0.55, 0.48, 0.25))
	m_concrete = _noise_mat(Color(0.19, 0.18, 0.17), Color(0.38, 0.365, 0.345), 0.12, Vector3(2, 2, 1), "concrete", Color(0.72, 0.7, 0.66))
	m_brick = _noise_mat(Color(0.12, 0.08, 0.07), Color(0.30, 0.17, 0.13), 0.25, Vector3(1, 3, 1), "brick", Color(0.5, 0.42, 0.4))
	m_char = _noise_mat(Color(0.03, 0.03, 0.03), Color(0.12, 0.11, 0.10), 0.2, Vector3(1, 3, 1), "charred_wood")
	m_rust = _noise_mat(Color(0.12, 0.06, 0.035), Color(0.36, 0.19, 0.09), 0.18, Vector3(2, 2, 1), "rust")
	m_metal = _noise_mat(Color(0.35, 0.34, 0.33), Color(0.55, 0.52, 0.48), 0.15, Vector3(2, 2, 1), "metal", Color(0.7, 0.68, 0.66))
	m_metal.metallic = 0.4
	m_ash = _flat(Color(0.075, 0.072, 0.07))
	SurfacesScript.apply(m_ash, "ground_ash", Color(0.55, 0.55, 0.55))
	m_rock = _noise_mat(Color(0.22, 0.21, 0.20), Color(0.36, 0.34, 0.32), 0.3, Vector3(1, 1, 1), "rock")
	m_black = _flat(Color(0.01, 0.01, 0.01))
	m_appliance = _noise_mat(Color(0.2, 0.11, 0.06), Color(0.4, 0.38, 0.35), 0.6, Vector3(1, 1, 1), "rust", Color(0.7, 0.66, 0.62))
	m_sign = _flat(Color(0.12, 0.25, 0.15))
	m_flue = _noise_mat(Color(0.32, 0.14, 0.08), Color(0.5, 0.26, 0.15), 0.4, Vector3(1, 1, 1), "brick", Color(0.9, 0.6, 0.45))
	# Thin sheets are seen from both sides.
	m_sheet_metal = m_metal.duplicate()
	m_sheet_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_sheet_metal.metallic = 0.5
	m_sheet_metal.roughness = 0.75
	m_sheet_rust = m_rust.duplicate()
	m_sheet_rust.cull_mode = BaseMaterial3D.CULL_DISABLED


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


## A material with a procedural noise texture blending two colors.
## `surface` names a real texture set in res://textures/ (see surfaces.gd);
## when that set is installed it replaces the procedural look, multiplied by `tint`.
static func _noise_mat(c1: Color, c2: Color, freq: float, uv: Vector3, surface := "", tint := Color.WHITE, world := true) -> StandardMaterial3D:
	if surface != "":
		var real := StandardMaterial3D.new()
		if SurfacesScript.apply(real, surface, tint, world):
			return real
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, c1)
	grad.set_color(1, c2)
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = uv
	if surface != "" and world:
		# Project from three sides at true scale so long boxes don't stretch
		# the pattern into streaks.
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(SurfacesScript.TILE.get(surface, 2.0))
	m.roughness = 1.0
	# Surface relief from the same noise, so ash, bark and brick catch the light.
	var bump := NoiseTexture2D.new()
	bump.width = 256
	bump.height = 256
	bump.seamless = true
	bump.noise = noise
	bump.as_normal_map = true
	bump.bump_strength = 6.0
	m.normal_enabled = true
	m.normal_texture = bump
	m.normal_scale = 0.8
	return m


# ---------- mesh helpers ----------

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, top_r: float, bottom_r: float, h: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 24   # round, not octagons
	mesh.rings = 1
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## A thin cylinder from a to b (in the parent's space).
func _beam(a: Vector3, b: Vector3, r: float, mat: Material, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	var d := b - a
	var seg := d.length()
	if seg < 0.01:
		return
	var y := d / seg
	var x := y.cross(Vector3.UP) if abs(y.dot(Vector3.UP)) < 0.99 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = seg
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(mi)
