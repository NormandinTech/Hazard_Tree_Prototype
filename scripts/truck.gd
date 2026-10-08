extends StaticBody3D
## The crew truck: a white crew-cab utility truck for the county hazard-tree
## program. Front faces -Z. Fictional markings; change them in TownScript.

const TownScript = preload("res://scripts/town.gd")
const VehiclesScript = preload("res://scripts/vehicles.gd")

var bar_lights: Array = []
var bar_omni: OmniLight3D
var t := 0.0
var alarm_t := 0.0   # light bar strobes red while the radio screams
var m_alarm: StandardMaterial3D
var headlights: Array = []

var m_paint: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_tire: StandardMaterial3D
var m_chrome: StandardMaterial3D
var m_glass: StandardMaterial3D
var m_amber: StandardMaterial3D
var m_amber_off: StandardMaterial3D
var m_red: StandardMaterial3D
var m_head: StandardMaterial3D
var m_orange: StandardMaterial3D
var m_white: StandardMaterial3D
var m_green: StandardMaterial3D


func _ready() -> void:
	_materials()

	# Frame, bumpers, wheels.
	_box(Vector3(1.7, 0.3, 6.4), Vector3(0, 0.7, 0), m_dark)
	_box(Vector3(2.15, 0.28, 0.25), Vector3(0, 0.78, -3.35), m_dark)
	_box(Vector3(2.15, 0.2, 0.3), Vector3(0, 0.72, 3.3), m_dark)
	for w in [Vector3(1.0, 0.48, -2.1), Vector3(-1.0, 0.48, -2.1), Vector3(1.0, 0.48, 1.7), Vector3(-1.0, 0.48, 1.7)]:
		var wh := VehiclesScript.wheel(self, w, 0.48, 0.32, m_tire, m_chrome, m_dark)
		wh.rotation_degrees.y = 90.0

	# Hood and crew cab: one shaped body, front toward -Z.
	var prof := VehiclesScript.cab_profile(true)
	var edge := {}
	for e in prof["arch_edges"]:
		edge[e] = 2
	edge[prof["glass"]["windshield"]] = 1
	var cab_mesh := VehiclesScript.body(prof["points"], 1.0, prof["belt"], prof["top"], 0.08,
		[m_paint, m_glass, m_dark], edge, prof["windows"], 1)
	var cab := MeshInstance3D.new()
	cab.mesh = cab_mesh
	cab.rotation_degrees.y = 90.0
	add_child(cab)
	# Grille, headlights, rear cab glass.
	_box(Vector3(1.3, 0.36, 0.04), Vector3(0, 1.2, -3.35), m_dark)
	for gy in [1.08, 1.2, 1.32]:
		_box(Vector3(1.26, 0.025, 0.05), Vector3(0, gy, -3.355), m_chrome)
	for hx in [0.78, -0.78]:
		_box(Vector3(0.36, 0.2, 0.05), Vector3(hx, 1.25, -3.345), m_head)
		_box(Vector3(0.36, 0.06, 0.05), Vector3(hx, 1.08, -3.345), m_amber_off)   # turn signal
	_box(Vector3(1.75, 0.5, 0.04), Vector3(0, 2.0, 0.66), m_glass)
	for sx in [1.0, -1.0]:
		_box(Vector3(0.1, 0.26, 0.2), Vector3(sx * 1.16, 1.95, -1.75), m_dark)   # mirrors
		_beam(Vector3(sx * 0.99, 1.88, -1.82), Vector3(sx * 1.12, 1.92, -1.76), 0.015, m_dark)
		_box(Vector3(0.02, 0.05, 2.05), Vector3(sx * 1.005, 1.15, -0.42), m_green)  # pinstripe
		# Door seams and handles.
		for dz in [-1.88, -0.32, 0.64]:
			_box(Vector3(0.01, 0.95, 0.012), Vector3(sx * 1.003, 1.25, dz), m_dark)
		for hz in [-0.5]:
			_box(Vector3(0.02, 0.04, 0.18), Vector3(sx * 1.01, 1.55, hz), m_chrome)

	# Amber light bar on the roof.
	_box(Vector3(1.7, 0.08, 0.32), Vector3(0, 2.34, -1.1), m_dark)
	for i in 6:
		var seg := _box(Vector3(0.24, 0.12, 0.3), Vector3(-0.7 + i * 0.28, 2.43, -1.1), m_amber_off)
		bar_lights.append(seg)
	bar_omni = OmniLight3D.new()
	bar_omni.position = Vector3(0, 2.6, -1.1)
	bar_omni.light_color = Color(1.0, 0.6, 0.15)
	bar_omni.omni_range = 12.0
	bar_omni.light_energy = 0.0
	add_child(bar_omni)

	# Utility bed: side compartments, open center, ladder rack.
	for bx in [0.78, -0.78]:
		_box(Vector3(0.55, 1.05, 2.7), Vector3(bx, 1.37, 1.95), m_paint)
		for dz in [1.05, 1.95, 2.85]:
			_box(Vector3(0.02, 0.9, 0.04), Vector3(bx * 1.36, 1.37, dz - 0.45), m_dark)
			_box(Vector3(0.03, 0.05, 0.14), Vector3(bx * 1.37, 1.6, dz), m_chrome)
	_box(Vector3(1.0, 0.08, 2.7), Vector3(0, 0.95, 1.95), m_dark)
	for corner in [Vector3(0.95, 0, 0.7), Vector3(-0.95, 0, 0.7), Vector3(0.95, 0, 3.2), Vector3(-0.95, 0, 3.2)]:
		_beam(corner + Vector3(0, 1.9, 0), corner + Vector3(0, 2.55, 0), 0.035, m_dark)
	for rx in [0.95, -0.95]:
		_beam(Vector3(rx, 2.55, 0.7), Vector3(rx, 2.55, 3.2), 0.035, m_dark)
	_beam(Vector3(-0.95, 2.55, 0.7), Vector3(0.95, 2.55, 0.7), 0.035, m_dark)
	_beam(Vector3(-0.95, 2.55, 3.2), Vector3(0.95, 2.55, 3.2), 0.035, m_dark)
	# Pole saw and a ladder on the rack.
	_beam(Vector3(0.6, 2.62, 0.2), Vector3(0.6, 2.62, 3.6), 0.03, m_orange)
	_beam(Vector3(-0.35, 2.62, 0.4), Vector3(-0.35, 2.62, 3.5), 0.025, m_chrome)
	_beam(Vector3(-0.75, 2.62, 0.4), Vector3(-0.75, 2.62, 3.5), 0.025, m_chrome)
	var rung := 0.6
	while rung < 3.4:
		_beam(Vector3(-0.75, 2.62, rung), Vector3(-0.35, 2.62, rung), 0.015, m_chrome)
		rung += 0.35

	# Rear: tail lights and chevron striping.
	for tx in [0.85, -0.85]:
		_box(Vector3(0.22, 0.32, 0.05), Vector3(tx, 1.15, 3.32), m_red)
	for i in 6:
		var m := m_orange if i % 2 == 0 else m_white
		_box(Vector3(0.08, 0.7, 0.03), Vector3(-0.25 + i * 0.1, 1.45, 3.32), m, Vector3(0, 0, 40))

	# Door lettering and emblem, both sides.
	for side in [1.0, -1.0]:
		var face: float = PI * 0.5 * side
		var x: float = 1.012 * side
		# Door lettering sits below the windows: emblem on the front door,
		# program name on the rear door, unit number under it.
		var out := Vector3(0.012 * side, 0, 0)
		_cyl(0.2, 0.2, 0.02, Vector3(x, 1.38, -1.35), m_green, Vector3(0, 0, 90))
		_cyl(0.16, 0.16, 0.022, Vector3(x, 1.38, -1.35), m_white, Vector3(0, 0, 90))
		_label("HT", Vector3(x, 1.38, -1.35) + out * 2.0, face, 0.0012, 112, m_green.albedo_color)
		_label(TownScript.TOWN_NAME, Vector3(x, 1.52, 0.13) + out, face, 0.00076, 96, Color(0.06, 0.2, 0.11))
		_label("HAZARD TREE PROGRAM", Vector3(x, 1.41, 0.13) + out, face, 0.00062, 96, Color(0.06, 0.2, 0.11))
		_label("UNIT HT-7", Vector3(x, 1.3, 0.13) + out, face, 0.00062, 96, Color(0.12, 0.12, 0.12))
		# Compartment door lettering, between the panel seams.
		_label("TREE CREW", Vector3(1.07 * side, 1.2, 1.95), face, 0.001, 96, Color(0.06, 0.2, 0.11))
	_label("SLOW · TREE CREW", Vector3(0, 0.92, 3.47), 0.0, 0.0009, 96, Color(0.08, 0.08, 0.08))

	# Headlights, off until the end.
	for hx in [0.72, -0.72]:
		var h := SpotLight3D.new()
		h.position = Vector3(hx, 1.28, -3.4)
		h.spot_range = 40.0
		h.spot_angle = 28.0
		h.light_energy = 6.0
		h.light_color = Color(1.0, 0.95, 0.85)
		h.visible = false
		add_child(h)
		headlights.append(h)

	# Work lamp, as before.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.4, -3.6)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 0.6
	lamp.omni_range = 8.0
	add_child(lamp)

	# Cones set out around the truck.
	for c in [Vector3(1.6, 0, -3.8), Vector3(-1.7, 0, -3.4), Vector3(1.5, 0, 4.0), Vector3(-1.4, 0, 4.3)]:
		_cone(c)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 2.4, 6.8)
	col.shape = shape
	col.position = Vector3(0, 1.2, 0)
	add_child(col)


func set_headlights(on: bool, pitch_deg := 0.0) -> void:
	for h in headlights:
		h.visible = on
		h.rotation_degrees.x = pitch_deg


func alarm(seconds: float) -> void:
	alarm_t = seconds


func _process(delta: float) -> void:
	t += delta
	if alarm_t > 0.0:
		alarm_t -= delta
		var flash := int(t * 14.0) % 2 == 0
		for seg in bar_lights:
			seg.material_override = m_alarm if flash else null
		bar_omni.light_color = Color(1.0, 0.1, 0.05)
		bar_omni.light_energy = 3.0 if flash else 0.0
		return
	bar_omni.light_color = Color(1.0, 0.6, 0.15)
	# Slow alternating sweep across the light bar.
	var phase := int(t * 3.0) % 2
	for i in bar_lights.size():
		var on := (i < 3) == (phase == 0)
		bar_lights[i].material_override = m_amber if on else null
	bar_omni.light_energy = 0.8 + 0.4 * sin(t * 6.0)


func _cone(pos: Vector3) -> void:
	var body := Node3D.new()
	body.position = pos
	body.rotation.y = randf() * TAU
	add_child(body)
	var base := BoxMesh.new()
	base.size = Vector3(0.38, 0.04, 0.38)
	base.material = m_orange
	var b := MeshInstance3D.new()
	b.mesh = base
	b.position.y = 0.02
	body.add_child(b)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.16
	cone.height = 0.7
	cone.material = m_orange
	var c := MeshInstance3D.new()
	c.mesh = cone
	c.position.y = 0.39
	body.add_child(c)
	var band := CylinderMesh.new()
	band.top_radius = 0.085
	band.bottom_radius = 0.105
	band.height = 0.1
	band.material = m_white
	var bb := MeshInstance3D.new()
	bb.mesh = band
	bb.position.y = 0.48
	body.add_child(bb)


func _label(text: String, pos: Vector3, yaw: float, pixel: float, size: int, color: Color) -> void:
	# High-res glyphs at a small pixel size keep vinyl lettering crisp; opaque
	# prepass keeps fog and the white paint from washing it out.
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.position = pos
	l.rotation.y = yaw
	add_child(l)


func _materials() -> void:
	m_paint = _mat(Color(0.86, 0.86, 0.83), 0.45)
	m_dark = _mat(Color(0.07, 0.07, 0.075), 0.8)
	m_tire = _mat(Color(0.04, 0.04, 0.04), 1.0)
	m_chrome = _mat(Color(0.7, 0.7, 0.7), 0.25)
	m_chrome.metallic = 0.8
	m_glass = _mat(Color(0.05, 0.07, 0.08), 0.1)
	m_amber = _mat(Color(1.0, 0.55, 0.05), 0.4)
	m_amber.emission_enabled = true
	m_amber.emission = Color(1.0, 0.5, 0.05)
	m_amber.emission_energy_multiplier = 3.0
	m_amber_off = _mat(Color(0.45, 0.25, 0.05), 0.4)
	m_alarm = _mat(Color(1.0, 0.05, 0.03), 0.4)
	m_alarm.emission_enabled = true
	m_alarm.emission = Color(1.0, 0.05, 0.02)
	m_alarm.emission_energy_multiplier = 4.0
	m_red = _mat(Color(0.7, 0.05, 0.03), 0.4)
	m_red.emission_enabled = true
	m_red.emission = Color(0.6, 0.02, 0.0)
	m_head = _mat(Color(1.0, 0.97, 0.88), 0.2)
	m_head.emission_enabled = true
	m_head.emission = Color(1.0, 0.95, 0.85)
	m_head.emission_energy_multiplier = 1.5
	m_orange = _mat(Color(1.0, 0.38, 0.05), 0.6)
	m_white = _mat(Color(0.95, 0.95, 0.95), 0.5)
	m_green = _mat(Color(0.1, 0.3, 0.18), 0.6)


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 16
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


func _beam(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	var seg := d.length()
	var y := d / seg
	var x := y.cross(Vector3.UP) if abs(y.dot(Vector3.UP)) < 0.99 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = seg
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	add_child(mi)
