extends Node
## The horror director: the thing that hunts you, the snags that fall, and
## the random events that keep any two runs from playing the same.
##
## The stalker only moves while it is NOT in your camcorder's frame. You can't
## see it with your own eyes, only hear it. Film it long enough and it backs off
## for a while. If it reaches you, you black out and lose work.

var main
var player
var hud
var audio
var figure: Node3D

var cfg := {}
var stalking := false
var speed := 0.0
var cooldown := 30.0
var seen_t := 0.0
var step_t := 0.0
var steps: AudioStreamPlayer3D
var saw: AudioStreamPlayer3D
var groan: AudioStreamPlayer3D

var fall_timer := INF
var falling := false
var shake_t := 0.0

var event_timer := INF
var last_event := ""

const RADIO_LINES := [
	"\"...Unit seven, copy? We show two assessors on Parcel 7B.\"",
	"\"...HT-6, come back. HT-6...\"",
	"\"...negative, no other crews in Kestrel Ridge tonight.\"",
	"\"...keep the camera up, seven. Keep it up.\"",
	"\"...who's breathing on this channel?\"",
	"\"...seven, your GPS puts you in two places.\"",
	"\"...we found HT-6's truck. Not HT-6.\"",
	"\"...Sierra Northern dispatch. Unit seven, stay off Line 7.\"",
	"\"...SNP wants the tapes, seven. All of them.\"",
	"\"...somebody keeps painting REMOVE on the county's trees out there.\"",
]


func _ready() -> void:
	steps = _player3d(4.0, 40.0, 4.0)
	saw = _player3d(10.0, 80.0, 2.0)
	groan = _player3d(14.0, 70.0, 8.0)


func _player3d(unit: float, max_d: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.unit_size = unit
	p.max_distance = max_d
	p.volume_db = db
	add_child(p)
	return p


func configure(c: Dictionary) -> void:
	cfg = c
	speed = c.get("stalk", 0.0)
	stalking = false
	seen_t = 0.0
	cooldown = randf_range(20.0, 35.0)
	var falls: float = c.get("falls", 0.0)
	fall_timer = randf_range(falls * 0.5, falls) if falls > 0.0 else INF
	var ev: float = c.get("events", 0.0)
	event_timer = randf_range(ev * 0.5, ev) if ev > 0.0 else INF
	player.interference = 0.0
	if speed > 0.0:
		figure.visible = false


func active() -> bool:
	return speed > 0.0


## Called by main every frame. Returns how much the camcorder image should tear.
func tick(delta: float) -> float:
	_shake(delta)
	if main.ending or main.shift_done or main.knocked:
		player.interference = 0.0
		return 0.0
	var g := 0.0
	if active():
		g = _stalk(delta)
	_falls(delta)
	_events(delta)
	return g


# ---------- the stalker ----------

func _stalk(delta: float) -> float:
	if not stalking:
		player.interference = 0.0
		cooldown -= delta
		if cooldown <= 0.0:
			_spawn()
		return 0.0
	var cam: Camera3D = player.cam
	var to: Vector3 = player.global_position - figure.global_position
	to.y = 0.0
	var dist := to.length()
	var filmed: bool = player.recording and dist < 45.0 \
		and cam.is_position_in_frustum(figure.global_position + Vector3(0, 0.6, 0))
	var g := 0.0
	if filmed:
		seen_t += delta
		g = clampf(0.25 + seen_t / 2.5, 0.0, 1.0)
		if seen_t > 2.5:
			banish(1.0)
	else:
		seen_t = maxf(seen_t - delta * 0.5, 0.0)
		var pace := speed * (1.8 if dist > 25.0 else 1.0)
		figure.global_position += to.normalized() * minf(pace * delta, dist)
		step_t -= delta
		if step_t <= 0.0 and dist < 30.0:
			step_t = 0.62 / maxf(pace / 1.2, 0.5)
			_step_at(figure.global_position)
		if dist < 1.3:
			main.knockout("You came to by the truck. You don't remember walking back.")
	# Your light doesn't like it close.
	player.interference = clampf(1.0 - dist / 12.0, 0.0, 1.0)
	return g


func _spawn() -> void:
	var back: Vector3 = player.cam.global_transform.basis.z
	back.y = 0.0
	back = back.normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0))
	figure.global_position = player.global_position + back * randf_range(32.0, 42.0) + Vector3(0, 0.975, 0)
	figure.visible = true
	stalking = true
	seen_t = 0.0
	step_t = 0.0
	if main.has_method("on_stalker_spawn"):
		main.on_stalker_spawn()


## Driven off by the camera (or after it gets you). `scale` stretches the wait.
func banish(scale := 1.0) -> void:
	stalking = false
	figure.visible = false
	seen_t = 0.0
	player.interference = 0.0
	cooldown = randf_range(cfg.get("cool_min", 40.0), cfg.get("cool_max", 70.0)) * scale


## Its "footsteps": wood cracking and roots dragging, from a random slice
## of a creak recording, pitched way down.
func _step_at(pos: Vector3) -> void:
	steps.global_position = pos
	var c = audio.get_stream("creak")
	if c != null and c.get_length() > 1.5:
		steps.stream = c
		steps.pitch_scale = randf_range(0.45, 0.6)
		steps.play(randf_range(0.0, c.get_length() - 1.2))
	else:
		var s = audio.get_stream("step")
		if s == null:
			return
		steps.stream = s
		steps.pitch_scale = randf_range(0.6, 0.7)
		steps.play()
	get_tree().create_timer(0.35).timeout.connect(steps.stop)


## You painted REMOVE on one of its family. It heard.
func provoke() -> void:
	if not active() or stalking:
		return
	cooldown = minf(cooldown, randf_range(6.0, 14.0))
	var c = audio.get_stream("creak")
	if c != null:
		var away: Vector3 = player.cam.global_transform.basis.z
		away.y = 0.0
		groan.global_position = player.global_position + away.normalized() * 30.0 + Vector3(0, 6, 0)
		groan.stream = c
		groan.pitch_scale = 0.35
		groan.play()
		get_tree().create_timer(2.0).timeout.connect(groan.stop)


# ---------- falling hazard trees ----------

func _falls(delta: float) -> void:
	if falling or fall_timer == INF:
		return
	fall_timer -= delta
	if fall_timer > 0.0:
		return
	var snag = _pick_snag()
	var falls: float = cfg.get("falls", 0.0)
	if snag == null:
		fall_timer = 8.0
		return
	fall_timer = randf_range(falls * 0.7, falls * 1.3)
	_fall(snag)


func _pick_snag():
	var best = null
	for s in main.snags:
		if s.has_meta("fallen") or s.height < 6.0:
			continue
		var d: float = s.global_position.distance_to(player.global_position)
		if d > 6.0 and d < 15.0:
			best = s
			if randf() < 0.4:
				break
	return best


func _fall(snag) -> void:
	falling = true
	snag.set_meta("fallen", true)
	var base: Vector3 = snag.global_position
	var dir: Vector3 = player.global_position - base
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, randf_range(-0.3, 0.3))
	# The warning: a long groan from the top of the tree.
	var creak = audio.get_stream("creak")
	if creak != null:
		groan.global_position = base + Vector3(0, snag.height * 0.7, 0)
		groan.stream = creak
		groan.pitch_scale = 0.7
		groan.play()
		get_tree().create_timer(1.8).timeout.connect(groan.stop)
	await get_tree().create_timer(1.6).timeout
	var axis := Vector3.UP.cross(dir).normalized()
	var b0: Basis = snag.global_transform.basis
	var tw := create_tween()
	tw.tween_method(_set_fall.bind(snag, axis, b0), 0.0, deg_to_rad(84.0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	# Impact.
	shake_t = 0.5
	audio.glitch(1.0)
	if creak != null:
		groan.global_position = base + dir * snag.height * 0.6
		groan.pitch_scale = 0.45
		groan.play()
		get_tree().create_timer(0.6).timeout.connect(groan.stop)
	var p: Vector3 = player.global_position - base
	p.y = 0.0
	var along := p.dot(dir)
	var lateral := (p - dir * along).length()
	if along > 0.0 and along < snag.height and lateral < 1.3 and not main.knocked and not main.ending:
		main.knockout("A snag came down on you. You came to by the truck.")
	falling = false


func _set_fall(angle: float, snag, axis: Vector3, b0: Basis) -> void:
	var t: Transform3D = snag.global_transform
	t.basis = Basis(axis, angle) * b0
	snag.global_transform = t


func _shake(delta: float) -> void:
	var cam: Camera3D = player.cam
	if shake_t > 0.0:
		shake_t -= delta
		cam.h_offset = randf_range(-0.06, 0.06) * shake_t * 2.0
		cam.v_offset = randf_range(-0.06, 0.06) * shake_t * 2.0
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# ---------- random events ----------

func _events(delta: float) -> void:
	if event_timer == INF:
		return
	event_timer -= delta
	if event_timer > 0.0:
		return
	var ev: float = cfg.get("events", 60.0)
	event_timer = randf_range(ev * 0.7, ev * 1.3)
	var pool := ["steps", "light", "radio", "tablet", "saw"]
	pool.erase(last_event)
	var pick: String = pool.pick_random()
	last_event = pick
	match pick:
		"steps": _ev_steps()
		"light": _ev_light()
		"radio": _ev_radio()
		"tablet": hud.ghost_line(7.0)
		"saw": _ev_saw()


func _ev_steps() -> void:
	# Someone walking up behind you. Four steps, then nothing.
	var back: Vector3 = player.cam.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	for i in 4:
		_step_at(player.global_position + back * (6.0 - i * 1.2))
		await get_tree().create_timer(0.55).timeout


func _ev_light() -> void:
	if not player.flashlight_on:
		_ev_radio()
		return
	player.flashlight_on = false
	audio.click()
	await get_tree().create_timer(randf_range(2.5, 4.0)).timeout
	if player.battery > 0.0 and not main.ending:
		player.flashlight_on = true
		audio.click()


func _ev_radio() -> void:
	audio.glitch(1.0)
	hud.flash("[RADIO]  — static —  " + RADIO_LINES.pick_random(), 5.0, true)


func _ev_saw() -> void:
	var s = audio.get_stream("chainsaw_close")
	if s == null:
		s = audio.get_stream("chainsaw_far")
	if s == null:
		_ev_steps()
		return
	var back: Vector3 = player.cam.global_transform.basis.z
	back.y = 0.0
	saw.global_position = player.global_position + back.normalized() * 7.0 + Vector3(0, 1, 0)
	saw.stream = s
	saw.play()
	await get_tree().create_timer(2.2).timeout
	saw.stop()
