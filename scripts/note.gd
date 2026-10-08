extends Node3D
## A page from Unit HT-6's field notes, the assessor who worked Parcel 7B before
## you. A clipboard on the ground with a faint glow so it catches the eye.

var title := ""
var text := ""
var taken := false


func _ready() -> void:
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.35, 0.25, 0.15)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.85, 0.82, 0.72)
	paper.emission_enabled = true
	paper.emission = Color(0.5, 0.48, 0.4)
	paper.emission_energy_multiplier = 0.35
	_box(Vector3(0.24, 0.015, 0.32), Vector3(0, 0.03, 0), board)
	_box(Vector3(0.21, 0.01, 0.28), Vector3(0, 0.045, 0.01), paper)
	_box(Vector3(0.09, 0.02, 0.03), Vector3(0, 0.05, -0.15), StandardMaterial3D.new())
	rotation.y = randf() * TAU
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 0.25, 0)
	glow.light_color = Color(1.0, 0.92, 0.75)
	glow.light_energy = 0.25
	glow.omni_range = 1.4
	add_child(glow)


func take() -> void:
	taken = true
	visible = false


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	add_child(mi)
