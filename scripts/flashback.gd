extends Node3D
## The town before the fire, for one lot: the house that stood around the
## chimney, a green yard, pines, a car in the driveway, a kid's bike.
## Main shows this (and hides the ruins) only on camcorder capture frames,
## so it lives on the tape and flickers for single frames live.

const TownScript = preload("res://scripts/town.gd")

var chimney_pos := Vector3(0, 0.3, -4.2)   # lot-local, from the ruin
var chimney_h := 6.0
var half := Vector2(6.0, 5.0)              # slab half size
var minimal := false                       # whole-town version: no yard disc, fewer pines


func build() -> void:
	var grass = TownScript._noise_mat(Color(0.20, 0.32, 0.12), Color(0.34, 0.45, 0.18), 0.15, Vector3(20, 20, 1), "grass")
	var siding := _mat(Color(0.55, 0.6, 0.62))
	var trim := _mat(Color(0.95, 0.94, 0.9))
	var roof := TownScript._noise_mat(Color(0.18, 0.17, 0.17), Color(0.28, 0.26, 0.25), 0.4, Vector3(6, 4, 1), "roof")
	var brick := TownScript._noise_mat(Color(0.45, 0.2, 0.14), Color(0.6, 0.3, 0.2), 0.25, Vector3(1, 3, 1), "brick")
	var glass := _mat(Color(0.25, 0.35, 0.4))
	glass.metallic = 0.3
	glass.roughness = 0.1
	var door := _mat(Color(0.45, 0.12, 0.08))
	var concrete := _mat(Color(0.7, 0.68, 0.64))

	if not minimal:
		_disc(Vector3(0, 0.03, 0), 40.0, grass)

	var wall_h := 2.8
	var top := 0.3 + wall_h
	_box(Vector3(half.x * 2.0 - 0.4, wall_h, half.y * 2.0 - 0.4), Vector3(0, 0.3 + wall_h * 0.5, 0), siding)
	_box(Vector3(half.x * 2.0, 0.3, half.y * 2.0), Vector3(0, 0.15, 0), concrete)
	# Attic gable and roof slopes.
	var depth := half.y * 2.0 - 0.4
	var rise := (depth * 0.5) * tan(deg_to_rad(30.0))
	var gable := PrismMesh.new()
	gable.size = Vector3(depth, rise, half.x * 2.0 - 0.4)
	gable.material = siding
	var g := MeshInstance3D.new()
	g.mesh = gable
	g.position = Vector3(0, top + rise * 0.5, 0)
	g.rotation_degrees = Vector3(0, 90, 0)
	add_child(g)
	var slope_len := (depth * 0.5 + 0.4) / cos(deg_to_rad(30.0))
	for s in [1.0, -1.0]:
		_box(Vector3(half.x * 2.0 + 0.6, 0.14, slope_len), Vector3(0, top + rise * 0.5 + 0.12, s * (depth * 0.25 + 0.1)), roof, Vector3(30.0 * s, 0, 0))
	# Chimney, clean brick, up through the roof.
	_box(Vector3(1.4, chimney_h + 0.6, 0.95), chimney_pos + Vector3(0, (chimney_h + 0.6) * 0.5, -0.1), brick)

	# Front: door, windows with warm light, trim.
	var fz := half.y - 0.19
	_box(Vector3(1.0, 2.1, 0.08), Vector3(0, 0.3 + 1.05, fz), door)
	for wx in [-half.x * 0.55, half.x * 0.55]:
		_window(Vector3(wx, 1.75, fz), glass, trim, 0.0)
	for wz in [-half.y * 0.4, half.y * 0.4]:
		_window(Vector3(half.x - 0.19, 1.75, wz), glass, trim, 90.0)
		_window(Vector3(-half.x + 0.19, 1.75, wz), glass, trim, 90.0)
	_box(Vector3(2.0, 0.3, 0.8), Vector3(0, 0.15, half.y + 0.4), concrete)
	_box(Vector3(2.0, 0.15, 0.6), Vector3(0, 0.075, half.y + 1.1), concrete)

	# Driveway, family car, kid's bike, mailbox, fence.
	_box(Vector3(3.4, 0.04, 14.0), Vector3(half.x + 2.6, 0.04, 2.0), concrete)
	_car(Vector3(half.x + 2.6, 0, 0.5))
	_bike(Vector3(2.2, 0, half.y + 1.6))
	var picket := _mat(Color(0.93, 0.93, 0.9))
	var fx := -half.x - 1.5
	while fx < half.x - 0.5:
		_box(Vector3(0.09, 0.9, 0.03), Vector3(fx, 0.45, half.y + 3.2), picket)
		fx += 0.22
	_box(Vector3(half.x * 2.0 - 1.0, 0.07, 0.03), Vector3(-1.0, 0.7, half.y + 3.22), picket)
	_box(Vector3(0.1, 1.1, 0.1), Vector3(half.x + 4.6, 0.55, half.y + 3.2), picket)
	_box(Vector3(0.28, 0.25, 0.5), Vector3(half.x + 4.6, 1.15, half.y + 3.2), _mat(Color(0.15, 0.2, 0.35)))

	# Green pines around the yard and down the street.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1958
	for i in (0 if minimal else 16):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(10.0, 34.0)
		_pine(Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(12.0, 22.0))
	_pine(Vector3(-half.x - 3.0, 0, -half.y - 2.0), 18.0)
	_pine(Vector3(half.x + 5.5, 0, -half.y - 3.0), 20.0)


func _window(pos: Vector3, glass: Material, trim: Material, yaw: float) -> void:
	var w := Node3D.new()
	w.position = pos
	w.rotation_degrees.y = yaw
	add_child(w)
	var warm := _mat(Color(1.0, 0.85, 0.55))
	warm.emission_enabled = true
	warm.emission = Color(1.0, 0.8, 0.5)
	warm.emission_energy_multiplier = 0.6
	_box_in(w, Vector3(1.5, 1.2, 0.1), Vector3.ZERO, trim)
	_box_in(w, Vector3(1.3, 1.0, 0.12), Vector3.ZERO, glass if randf() < 0.5 else warm)
	_box_in(w, Vector3(0.06, 1.0, 0.13), Vector3.ZERO, trim)


func _car(pos: Vector3) -> void:
	var car := Node3D.new()
	car.position = pos
	car.rotation_degrees.y = 90.0
	add_child(car)
	var paint := _mat(Color(0.1, 0.24, 0.45))
	paint.roughness = 0.25
	paint.metallic = 0.35
	var glass := _mat(Color(0.06, 0.08, 0.1))
	glass.roughness = 0.04
	glass.metallic = 0.5
	var chrome := _mat(Color(0.75, 0.75, 0.75))
	chrome.metallic = 0.9
	chrome.roughness = 0.2
	var light := _mat(Color(0.95, 0.95, 0.9))
	light.roughness = 0.1
	var tail := _mat(Color(0.6, 0.04, 0.03))
	tail.roughness = 0.2
	var m := {"paint": paint, "glass": glass, "dark": _mat(Color(0.03, 0.03, 0.03)), "chrome": chrome,
		"tire": _mat(Color(0.04, 0.04, 0.04)), "light": light, "tail": tail}
	car.add_child(TownScript.VehiclesScript.car(m, false, false))


func _bike(pos: Vector3) -> void:
	var bike := Node3D.new()
	bike.position = pos
	bike.rotation_degrees = Vector3(0, 30, 12)
	add_child(bike)
	var red := _mat(Color(0.8, 0.1, 0.1))
	var black := _mat(Color(0.05, 0.05, 0.05))
	for wx in [-0.45, 0.45]:
		var t := TorusMesh.new()
		t.inner_radius = 0.24
		t.outer_radius = 0.3
		t.material = black
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.position = Vector3(wx, 0.3, 0)
		mi.rotation_degrees = Vector3(90, 0, 0)
		bike.add_child(mi)
	_box_in(bike, Vector3(0.9, 0.05, 0.05), Vector3(0, 0.55, 0), red, Vector3(0, 0, -8))
	_box_in(bike, Vector3(0.05, 0.4, 0.05), Vector3(-0.15, 0.42, 0), red, Vector3(0, 0, 20))
	_box_in(bike, Vector3(0.05, 0.05, 0.4), Vector3(0.42, 0.78, 0), black)


func _pine(pos: Vector3, h: float) -> void:
	var bark := _mat(Color(0.3, 0.2, 0.13))
	var needles = TownScript._noise_mat(Color(0.08, 0.18, 0.08), Color(0.16, 0.30, 0.12), 0.4, Vector3(2, 2, 1))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.35
	trunk.height = h
	trunk.material = bark
	var tm := MeshInstance3D.new()
	tm.mesh = trunk
	tm.position = pos + Vector3(0, h * 0.5, 0)
	add_child(tm)
	for i in 4:
		var c := CylinderMesh.new()
		var y := h * (0.35 + i * 0.16)
		var r := (4 - i) * 0.85 + 0.6
		c.top_radius = 0.05
		c.bottom_radius = r
		c.height = h * 0.3
		c.radial_segments = 9
		c.material = needles
		var cm := MeshInstance3D.new()
		cm.mesh = c
		cm.position = pos + Vector3(0, y, 0)
		add_child(cm)


func _disc(pos: Vector3, r: float, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 40
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	add_child(mi)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	_box_in(self, size, pos, mat, rot_deg)


func _box_in(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
