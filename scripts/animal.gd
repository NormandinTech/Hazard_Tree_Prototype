extends Node3D
## Animals in the burn. Some are survivors you can help or walk past; some are
## just wildlife getting on with it.
##
## Survivors (rescue styles):
##   befriend - dogs. Hiding, hurt paw held up. Walk up (running spooks them),
##              press E and stay close while you talk. Then they follow you to
##              the truck and you tie them there.
##   carry    - the cat. Give it water [E], pick it up [E], carry it back.
##   water    - fawn, rabbit, skunk. Walk up slowly and offer water [E]; it
##              drinks, then goes off on its own. Startle a skunk (run at it,
##              crowd it, or hose it) and it sprays you.
## Wildlife (no prompt): rabbits nibble and hop off when you get close,
## squirrels dart up the nearest dead tree, the doe watches from a distance.
##
## Bodies are simple shapes animated in code: breathing, trembling, a head
## that tracks you, tails, a limp, legs that walk, rabbits that hop.

const TownScript = preload("res://scripts/town.gd")

signal saved(animal)
signal sprayed(animal)

var kind := "dog"
var pet_name := ""
var wild := false        # wildlife: no rescue, just reacts to you
var player
var main
var state := "hiding"    # hiding, calming, following, carried, drinking, leaving, home, gone, fled, climbing, perched, watching
var calm := 0.0
var t := 0.0
var hide_spots: Array = []
var run_to := Vector3.ZERO
var leave_dir := Vector3.ZERO
var leave_target: Node3D = null   # the fawn walks off to its mother
var watered := false
var climb_tree: Node3D = null
var nibble_t := 0.0

var body: Node3D
var head: Node3D
var tail: Node3D
var legs: Array = []      # [pivot, phase, hurt]
var _base_y := 0.0
var _eye_mat: StandardMaterial3D
var _hop := false

const SPECS := {
	"dog": {"len": 0.78, "r": 0.17, "leg": 0.42, "neck": 0.22, "head": 0.13, "snout": 0.13, "ear": Vector3(0.05, 0.12, 0.08), "tail": 0.32, "tail_r": 0.16, "tail_up": 65.0,
		"c1": Color(0.1, 0.075, 0.06), "c2": Color(0.62, 0.45, 0.27), "freq": 2.2},
	"dog2": {"len": 0.66, "r": 0.15, "leg": 0.34, "neck": 0.18, "head": 0.12, "snout": 0.1, "ear": Vector3(0.06, 0.1, 0.04), "tail": 0.22, "tail_r": 0.2, "tail_up": 40.0,
		"c1": Color(0.05, 0.05, 0.05), "c2": Color(0.32, 0.3, 0.29), "freq": 2.8},
	"cat": {"len": 0.42, "r": 0.09, "leg": 0.2, "neck": 0.08, "head": 0.075, "snout": 0.04, "ear": Vector3(0.035, 0.06, 0.02), "tail": 0.3, "tail_r": 0.16, "tail_up": 65.0,
		"c1": Color(0.08, 0.08, 0.08), "c2": Color(0.45, 0.44, 0.42), "freq": 3.0},
	"fawn": {"len": 0.72, "r": 0.15, "leg": 0.62, "neck": 0.42, "head": 0.1, "snout": 0.14, "ear": Vector3(0.05, 0.14, 0.03), "tail": 0.08, "tail_r": 0.25, "tail_up": 40.0,
		"c1": Color(0.12, 0.08, 0.05), "c2": Color(0.58, 0.38, 0.22), "freq": 1.6},
	"doe": {"len": 1.0, "r": 0.21, "leg": 0.82, "neck": 0.55, "head": 0.12, "snout": 0.18, "ear": Vector3(0.06, 0.17, 0.035), "tail": 0.1, "tail_r": 0.3, "tail_up": 30.0,
		"c1": Color(0.22, 0.15, 0.09), "c2": Color(0.5, 0.36, 0.22), "freq": 1.3},
	"rabbit": {"len": 0.26, "r": 0.09, "leg": 0.07, "neck": 0.04, "head": 0.065, "snout": 0.035, "ear": Vector3(0.022, 0.14, 0.045), "tail": 0.0, "tail_r": 0.0, "tail_up": 0.0,
		"c1": Color(0.2, 0.16, 0.12), "c2": Color(0.5, 0.42, 0.32), "freq": 3.5},
	"squirrel": {"len": 0.2, "r": 0.055, "leg": 0.06, "neck": 0.03, "head": 0.045, "snout": 0.03, "ear": Vector3(0.015, 0.035, 0.012), "tail": 0.24, "tail_r": 0.42, "tail_up": 75.0,
		"c1": Color(0.25, 0.25, 0.26), "c2": Color(0.55, 0.53, 0.5), "freq": 4.0},
	"skunk": {"len": 0.42, "r": 0.11, "leg": 0.08, "neck": 0.05, "head": 0.075, "snout": 0.07, "ear": Vector3(0.025, 0.03, 0.02), "tail": 0.3, "tail_r": 0.42, "tail_up": 80.0,
		"c1": Color(0.02, 0.02, 0.02), "c2": Color(0.08, 0.08, 0.08), "freq": 2.0},
}

const WATER_COST := {"fawn": 15.0, "rabbit": 8.0, "skunk": 10.0, "cat": 10.0}


func style() -> String:
	if wild:
		return "wild"
	match kind:
		"dog", "dog2":
			return "befriend"
		"cat":
			return "carry"
	return "water"


func is_dog() -> bool:
	return kind == "dog" or kind == "dog2"


func build() -> void:
	_rig(SPECS[kind])
	_hop = kind == "rabbit" or kind == "squirrel"
	if kind == "fawn":
		var white := _mat(Color(0.85, 0.82, 0.76))
		for i in 9:
			var sm := SphereMesh.new()
			sm.radius = 0.025
			sm.height = 0.012
			sm.material = white
			_part(body, sm, Vector3(randf_range(-0.28, 0.28), 0.14, randf_range(-0.07, 0.07)))
	if kind == "skunk":
		# The stripe: two white bands from the head down the back and the tail.
		var white := _mat(Color(0.9, 0.9, 0.88))
		for s in [1.0, -1.0]:
			var b := BoxMesh.new()
			b.size = Vector3(0.36, 0.02, 0.03)
			b.material = white
			_part(body, b, Vector3(0, 0.1, s * 0.035), Vector3(s * 12.0, 0, 0))
		var tb := BoxMesh.new()
		tb.size = Vector3(0.04, 0.26, 0.05)
		tb.material = white
		_part(tail, tb, Vector3(-0.05, 0.12, 0), Vector3(0, 0, 10))
	if kind == "rabbit":
		var puff := SphereMesh.new()
		puff.radius = 0.035
		puff.height = 0.07
		puff.material = _mat(Color(0.88, 0.86, 0.82))
		_part(body, puff, Vector3(-0.15, 0.03, 0))
	if kind == "doe" or kind == "fawn":
		var rump := SphereMesh.new()
		rump.radius = 0.06 if kind == "doe" else 0.04
		rump.height = rump.radius * 2.0
		rump.material = _mat(Color(0.85, 0.82, 0.78))
		_part(body, rump, Vector3(-SPECS[kind]["len"] * 0.5, 0.04, 0))
	if is_dog():
		# Collar.
		var tor := TorusMesh.new()
		tor.inner_radius = 0.065
		tor.outer_radius = 0.085
		tor.material = _mat(Color(0.55, 0.08, 0.06) if kind == "dog" else Color(0.1, 0.25, 0.5))
		var c := _part(head, tor, Vector3(0.03, 0.06, 0), Vector3(0, 0, 60))
		c.scale = Vector3(1.0, 1.0, 1.0)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float, mat: Material) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 14
	c.rings = 6
	c.material = mat
	return c


## A four-legged body facing +x. Fur is a patchy mix of its coat and soot.
func _rig(p: Dictionary) -> void:
	var fur = TownScript._noise_mat(p["c1"], p["c2"], p["freq"], Vector3(2, 2, 1))
	fur.roughness = 0.95
	var dark := _mat(Color(0.04, 0.035, 0.03))
	var len: float = p["len"]
	var r: float = p["r"]
	var leg: float = p["leg"]
	_base_y = leg + r * 0.6
	body = Node3D.new()
	body.position.y = _base_y
	add_child(body)
	_part(body, _capsule(r, len, fur), Vector3.ZERO, Vector3(0, 0, 90))
	var chest := SphereMesh.new()
	chest.radius = r * 1.12
	chest.height = r * 2.3
	chest.material = fur
	_part(body, chest, Vector3(len * 0.28, -0.01, 0))
	head = Node3D.new()
	head.position = Vector3(len * 0.42, r * 0.4, 0)
	body.add_child(head)
	var neck: float = p["neck"]
	_part(head, _capsule(r * 0.45, neck + r * 0.6, fur), Vector3(neck * 0.3, neck * 0.5, 0), Vector3(0, 0, -35))
	var hr: float = p["head"]
	var skull := Node3D.new()
	skull.position = Vector3(neck * 0.6, neck, 0)
	head.add_child(skull)
	var hs := SphereMesh.new()
	hs.radius = hr
	hs.height = hr * 1.8
	hs.material = fur
	_part(skull, hs, Vector3.ZERO)
	var sn: float = p["snout"]
	_part(skull, _capsule(hr * 0.5, sn + hr, fur), Vector3(hr * 0.6 + sn * 0.3, -hr * 0.25, 0), Vector3(0, 0, 90))
	var nose := SphereMesh.new()
	nose.radius = hr * 0.18
	nose.height = hr * 0.3
	nose.material = dark
	_part(skull, nose, Vector3(hr * 0.6 + sn * 0.8 + hr * 0.4, -hr * 0.2, 0))
	# Eyes catch the flashlight.
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.02, 0.02, 0.02)
	_eye_mat.roughness = 0.05
	_eye_mat.metallic_specular = 1.0
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.55, 0.75, 0.45)
	_eye_mat.emission_energy_multiplier = 0.25
	var ear_tilt := -25.0 if kind == "rabbit" else -10.0
	for s in [1.0, -1.0]:
		var eye := SphereMesh.new()
		eye.radius = hr * 0.16
		eye.height = hr * 0.32
		eye.material = _eye_mat
		_part(skull, eye, Vector3(hr * 0.75, hr * 0.2, s * hr * 0.45))
		var ear := BoxMesh.new()
		ear.size = p["ear"]
		ear.material = fur
		var ey: float = hr * 0.85 + (p["ear"] as Vector3).y * 0.3
		_part(skull, ear, Vector3(-hr * 0.1, ey, s * hr * 0.45), Vector3(s * 12.0, 0, ear_tilt))
	var phases := [0.0, PI, PI, 0.0]
	var spots := [Vector3(len * 0.32, 0, r * 0.6), Vector3(len * 0.32, 0, -r * 0.6), Vector3(-len * 0.32, 0, r * 0.6), Vector3(-len * 0.32, 0, -r * 0.6)]
	for i in 4:
		var pivot := Node3D.new()
		pivot.position = spots[i] + Vector3(0, -r * 0.3, 0)
		body.add_child(pivot)
		var lm := CylinderMesh.new()
		lm.top_radius = r * 0.28
		lm.bottom_radius = r * 0.18
		lm.height = leg + r * 0.3
		lm.radial_segments = 8
		lm.material = fur
		_part(pivot, lm, Vector3(0, -(leg + r * 0.3) * 0.5, 0))
		var paw := SphereMesh.new()
		paw.radius = r * 0.22
		paw.height = r * 0.3
		paw.material = dark if (i == 0 and not wild) else fur
		_part(pivot, paw, Vector3(r * 0.08, -(leg + r * 0.3), 0))
		legs.append([pivot, phases[i], i == 0 and is_dog()])
	tail = Node3D.new()
	tail.position = Vector3(-len * 0.48, r * 0.3, 0)
	body.add_child(tail)
	var tl: float = p["tail"]
	if tl > 0.0:
		var tr: float = p["tail_r"]
		var tm := _part(tail, _capsule(r * tr, tl, fur), Vector3(-tl * 0.45 * cos(deg_to_rad(p["tail_up"])), tl * 0.5 * sin(deg_to_rad(p["tail_up"])), 0), Vector3(0, 0, p["tail_up"]))
		tm.name = "TailMesh"


# ---------- what the player can do ----------

func _near() -> float:
	return 2.0 if (kind == "cat" or kind == "rabbit" or kind == "skunk") else 2.6


## The prompt to show when the player is close, or "".
func prompt(pos: Vector3) -> String:
	if wild or state in ["gone", "home", "carried", "leaving", "fled"]:
		return ""
	if pos.distance_to(global_position) > _near():
		return ""
	match style():
		"befriend":
			if state == "hiding":
				return "[E] Kneel down and talk to it"
			if state == "calming":
				return "Talking to it... stay close  %d%%" % int(calm / 3.5 * 100.0)
		"carry":
			if state == "hiding" and not watered:
				return "[E] Give it water from the pump" if player.water >= WATER_COST["cat"] else "It needs water. Your bag's empty."
			if state == "hiding" and watered:
				return "[E] Pick it up"
		"water":
			if state == "hiding":
				var need: float = WATER_COST.get(kind, 10.0)
				if player.water < need:
					return "It needs water. Your bag's empty."
				return "[E] Offer it water  (slowly)" if kind == "skunk" else "[E] Offer it water"
			if state == "drinking":
				return "It's drinking."
	return ""


## E pressed nearby. Returns true if it used the key.
func interact(pos: Vector3) -> bool:
	if prompt(pos) == "":
		return false
	match style():
		"befriend":
			if state == "hiding":
				state = "calming"
				calm = 0.0
				return true
		"carry":
			if state == "hiding" and not watered and player.water >= WATER_COST["cat"]:
				player.water -= WATER_COST["cat"]
				watered = true
				main.hud.flash("It laps water out of your cupped hand. Its paws are burned raw.", 3.5)
				return true
			if state == "hiding" and watered:
				state = "carried"
				player.carrying = self
				reparent(player.cam, false)
				position = Vector3(0.05, -0.48, -0.55)
				rotation_degrees = Vector3(0, 100, 0)
				main.hud.flash("You tuck it into your jacket. It doesn't fight you. Get it to the truck.", 3.5)
				return true
		"water":
			var need: float = WATER_COST.get(kind, 10.0)
			if state == "hiding" and player.water >= need:
				player.water -= need
				state = "drinking"
				calm = 0.0
				return true
	return false


## Put the animal at the truck.
func go_home(spot: Node3D, local: Vector3) -> void:
	state = "home"
	if player.carrying == self:
		player.carrying = null
	reparent(spot, false)
	position = local
	rotation_degrees = Vector3(0, 90, 0)
	saved.emit(self)


## Hit by the pump. Most things just flinch; a skunk takes it personally.
func hosed() -> void:
	if kind == "skunk" and state in ["hiding", "drinking"]:
		_spray()
	elif wild and state != "gone":
		_flee_wild()


func _spray() -> void:
	state = "leaving"
	leave_dir = (global_position - player.global_position).normalized() * Vector3(1, 0, 1)
	tail.rotation.z = 0.4
	sprayed.emit(self)


func _process(delta: float) -> void:
	t += delta
	if state == "gone" or player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var running: bool = player.velocity.length() > 3.0
	var scared := state == "hiding" or state == "calming"
	var moving := false
	var speed := 0.0

	if wild:
		moving = _wild_step(delta, dist, running)
	else:
		match state:
			"hiding":
				if kind == "skunk":
					# Crowd it or run at it and it lets you have it.
					if (dist < 7.0 and running) or (dist < 0.9):
						_spray()
				elif kind != "cat" and dist < 9.0 and running:
					_bolt()
			"calming":
				if dist > 3.5 or running:
					state = "hiding"
					main.hud.flash("It shrinks back. Slow down. Stay close.", 2.5)
				else:
					calm += delta
					if calm >= 3.5:
						state = "following"
						main.hud.flash("It limps over and pushes its head into your hand. It'll follow you now. Get it to the truck.", 4.5)
			"following":
				if dist > 2.2:
					global_position += to.normalized() * minf(2.6 * delta * (1.6 if dist > 6.0 else 1.0), dist - 2.0)
					moving = true
			"drinking":
				calm += delta
				if calm > 4.0:
					state = "leaving"
					if leave_target != null and is_instance_valid(leave_target):
						leave_dir = (leave_target.global_position - global_position).normalized() * Vector3(1, 0, 1)
					else:
						leave_dir = -to.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
					main.hud.flash(_drank_line(), 5.0)
					saved.emit(self)
			"leaving":
				speed = 0.9 if kind != "rabbit" else 2.2
				if leave_target != null and is_instance_valid(leave_target):
					var lt: Vector3 = leave_target.global_position - global_position
					lt.y = 0.0
					if lt.length() > 1.2:
						leave_dir = lt.normalized()
					else:
						speed = 0.0
						# Back with its mother; they go together.
						leave_target.state = "leaving"
						leave_target.leave_dir = leave_dir
						leave_target.leave_target = null
						leave_target = null
				if speed > 0.0:
					global_position += leave_dir * speed * delta
					moving = true
				if dist > 45.0:
					state = "gone"
					visible = false
					return
			"fled":
				var r := run_to - global_position
				r.y = 0.0
				if r.length() < 0.3:
					state = "hiding"
				else:
					global_position += r.normalized() * minf(5.5 * delta, r.length())
					moving = true

	_animate(delta, to, dist, scared, moving)


func _drank_line() -> String:
	match kind:
		"fawn":
			return "It drinks until the bag's cap is dry. Then it turns and walks off into the burn, slow, toward the doe at the tree line."
		"rabbit":
			return "It drinks fast, nose going the whole time. Then it's gone, a gray streak into the ash."
		"skunk":
			return "It drinks, takes its time about it, and waddles off like it owns the place. You keep very still until it's gone."
	return "It drinks, then goes."


# ---------- wildlife ----------

func _wild_step(delta: float, dist: float, running: bool) -> bool:
	match state:
		"hiding", "watching":
			nibble_t += delta
			if kind == "doe":
				if dist < (14.0 if not running else 26.0):
					_flee_wild()
				return false
			if dist < (6.0 if not running else 11.0):
				_flee_wild()
			return false
		"fled":
			var r := run_to - global_position
			r.y = 0.0
			if r.length() < 0.3:
				state = "hiding"
				return false
			var sp := 6.5 if kind == "doe" else (4.5 if kind == "rabbit" else 3.5)
			global_position += r.normalized() * minf(sp * delta, r.length())
			if kind == "doe" and dist > 50.0:
				state = "gone"
				visible = false
			return true
		"climbing":
			if climb_tree == null or not is_instance_valid(climb_tree):
				state = "hiding"
				return false
			var base: Vector3 = climb_tree.global_position
			var flat := Vector3(base.x - global_position.x, 0, base.z - global_position.z)
			if flat.length() > (climb_tree.radius + 0.06):
				global_position += flat.normalized() * minf(4.0 * delta, flat.length())
				return true
			# Up the trunk.
			rotation.z = lerp_angle(rotation.z, PI * 0.5, delta * 10.0)
			global_position.y = minf(global_position.y + 2.5 * delta, 3.8)
			if global_position.y >= 3.8:
				state = "perched"
			return true
		"perched":
			if dist > 25.0 and randf() < delta * 0.1:
				# Comes back down once you're well clear.
				global_position.y = 0.0
				rotation.z = 0.0
				state = "hiding"
			return false
		"leaving":
			global_position += leave_dir * 1.4 * delta
			if dist > 50.0:
				state = "gone"
				visible = false
			return true
	return false


func _flee_wild() -> void:
	var away: Vector3 = (global_position - player.global_position) * Vector3(1, 0, 1)
	if kind == "squirrel" and main != null:
		var best = null
		var bd := 12.0
		for s in main.snags:
			if s.has_meta("fallen"):
				continue
			var d: float = (s.global_position as Vector3).distance_to(global_position)
			if d < bd and (s.global_position - player.global_position).dot(away) > 0.0:
				bd = d
				best = s
		if best != null:
			climb_tree = best
			state = "climbing"
			return
	run_to = global_position + away.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5)) * (30.0 if kind == "doe" else randf_range(8.0, 14.0))
	state = "fled"


# ---------- animation ----------

func _animate(delta: float, to: Vector3, dist: float, scared: bool, moving: bool) -> void:
	var face := to
	if state == "leaving":
		face = leave_dir
	elif state == "fled":
		face = run_to - global_position
	elif state == "climbing" and climb_tree != null:
		face = climb_tree.global_position - global_position
	if face.length() > 0.01 and not state in ["carried", "home", "perched"]:
		var yaw := atan2(-face.z, face.x)
		rotation.y = lerp_angle(rotation.y, yaw, delta * (6.0 if moving else 2.0))

	var breath := sin(t * (7.0 if scared else 3.0))
	body.scale = Vector3(1, 1.0 + 0.035 * breath, 1.0 + 0.02 * breath)
	var by := _base_y
	if _hop and moving and state != "climbing":
		by += absf(sin(t * 11.0)) * 0.12
	body.position = Vector3(randf_range(-1, 1) * 0.003 if (scared and not wild) else 0.0, by, 0)

	var head_down := state == "drinking" or (wild and kind in ["rabbit", "doe"] and state == "hiding" and fmod(nibble_t, 6.0) < 2.5)
	if head_down:
		head.rotation.z = lerp_angle(head.rotation.z, -0.9, delta * 3.0)
	else:
		head.rotation.z = lerp_angle(head.rotation.z, 0.0, delta * 3.0)
		if dist < 20.0 and state != "carried":
			var local := to_local(player.global_position)
			var hy := clampf(atan2(-local.z, local.x), -1.0, 1.0)
			head.rotation.y = lerp_angle(head.rotation.y, hy, delta * 4.0)
	if is_dog() and (state == "following" or state == "home"):
		tail.rotation.y = sin(t * 11.0) * 0.6
	elif kind == "squirrel":
		tail.rotation.z = sin(t * 3.0) * 0.15
	elif kind != "skunk":
		tail.rotation.z = lerp(tail.rotation.z, -0.6 if (scared and not wild) else 0.0, delta * 2.0)
	for l in legs:
		var pivot: Node3D = l[0]
		if l[2] and state != "home":
			pivot.rotation.z = 0.9
		elif moving:
			pivot.rotation.z = sin(t * (14.0 if _hop else 9.0) + (0.0 if _hop else l[1])) * 0.55
		else:
			pivot.rotation.z = lerp(pivot.rotation.z, 0.0, delta * 6.0)
	_eye_mat.emission_energy_multiplier = 0.3 if player.flashlight_on else 0.12


func _bolt() -> void:
	if hide_spots.is_empty():
		return
	var best: Vector3 = hide_spots[0]
	var far := -1.0
	for h in hide_spots:
		var d: float = (h as Vector3).distance_to(player.global_position)
		if d > far and (h as Vector3).distance_to(global_position) > 3.0:
			far = d
			best = h
	run_to = best
	state = "fled"
	main.hud.flash("It bolts. You came at it too fast.", 2.5)
