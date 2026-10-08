extends Node
## Loads optional sounds from res://audio/ (ogg, wav or mp3) and plays them.
## A missing file is skipped silently, so any sound can be left out.

# Sound groups. Any file named like the group, optionally followed by a number
# (spray, spray_1, spray_2, wind_loop2 ...) counts as a variant of that group.
const GROUPS := [
	"wind_loop", "creak", "step", "camcorder_on", "camcorder_loop",
	"chainsaw_far", "chainsaw_close", "flashlight_click", "spray", "glitch", "gas_hiss", "sting",
	"dog_growl", "dog_whimper",
]
const AUDIO_DIR := "res://audio"
const PLAYABLE := ["ogg", "wav", "mp3"]

var player   # set by main
var sounds := {}
var wind: AudioStreamPlayer
var cam_loop: AudioStreamPlayer
var click_p: AudioStreamPlayer
var cam_on_p: AudioStreamPlayer
var glitch_p: AudioStreamPlayer
var steps_p: AudioStreamPlayer
var spray_p: AudioStreamPlayer
var creak_p: AudioStreamPlayer3D
var saw_p: AudioStreamPlayer3D
var creak_timer := 6.0
var saw_timer := 25.0
var saw_distance := 50.0
var saw_group := "chainsaw_far"
var creak_min := 7.0
# Long source recordings get cut short with a fade: player -> [max seconds, base dB, age].
var caps := {}
var creak_max := 18.0
var glitch_cooldown := 0.0


func _ready() -> void:
	_scan()
	var parts := PackedStringArray()
	var missing := PackedStringArray()
	for g in GROUPS:
		if sounds.has(g):
			parts.append("%s x%d" % [g, sounds[g].size()])
		else:
			missing.append(g)
	print("Audio: %s. Missing: %s" % [", ".join(parts), "none" if missing.is_empty() else ", ".join(missing)])

	wind = _player(-8.0)
	if sounds.has("wind_loop"):
		wind.finished.connect(_next_wind)
		_next_wind()

	cam_loop = _player(-18.0)
	if sounds.has("camcorder_loop"):
		cam_loop.stream = _pick("camcorder_loop")
		cam_loop.finished.connect(cam_loop.play)

	click_p = _player(-6.0)
	cam_on_p = _player(-8.0)
	glitch_p = _player(-6.0)
	steps_p = _player(-12.0)
	spray_p = _player(-6.0)

	creak_p = AudioStreamPlayer3D.new()
	creak_p.unit_size = 12.0
	creak_p.max_distance = 60.0
	add_child(creak_p)

	saw_p = AudioStreamPlayer3D.new()
	saw_p.unit_size = 40.0
	saw_p.max_distance = 150.0
	saw_p.volume_db = -4.0
	add_child(saw_p)

	caps[steps_p] = [0.45, steps_p.volume_db, 0.0]
	caps[spray_p] = [1.2, spray_p.volume_db, 0.0]
	caps[glitch_p] = [1.5, glitch_p.volume_db, 0.0]
	caps[cam_on_p] = [1.5, cam_on_p.volume_db, 0.0]
	caps[click_p] = [0.5, click_p.volume_db, 0.0]
	caps[creak_p] = [4.0, creak_p.volume_db, 0.0]


func _process(delta: float) -> void:
	if player == null:
		return
	glitch_cooldown -= delta
	_apply_caps(delta)

	# Trees creaking somewhere nearby.
	creak_timer -= delta
	if creak_timer <= 0.0:
		creak_timer = randf_range(creak_min, creak_max)
		if sounds.has("creak"):
			var a := randf() * TAU
			var r := randf_range(6.0, 20.0)
			creak_p.global_position = player.global_position + Vector3(cos(a) * r, 6.0, sin(a) * r)
			creak_p.stream = _pick("creak")
			creak_p.pitch_scale = randf_range(0.85, 1.1)
			_restart(creak_p)

	# A chainsaw behind you that stops the moment you look toward it.
	var cam: Camera3D = player.cam
	if saw_p.playing:
		var to_saw := (saw_p.global_position - cam.global_position).normalized()
		var fwd := -cam.global_transform.basis.z
		if to_saw.dot(fwd) > 0.8:
			saw_p.stop()
	elif sounds.has(saw_group):
		saw_timer -= delta
		if saw_timer <= 0.0:
			saw_timer = randf_range(30.0, 60.0)
			var back := cam.global_transform.basis.z
			back.y = 0.0
			back = back.normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0))
			saw_p.global_position = player.global_position + back * saw_distance + Vector3(0, 2.0, 0)
			saw_p.stream = _pick(saw_group)
			saw_p.play()


# ---------- called by player / main ----------

## Shift settings: how close the chainsaw gets and how often trees creak.
func configure(cfg: Dictionary) -> void:
	saw_distance = cfg.get("saw_distance", 50.0)
	saw_group = cfg.get("saw_group", "chainsaw_far")
	if not sounds.has(saw_group):
		saw_group = "chainsaw_far"
	creak_min = cfg.get("creak_min", 7.0)
	creak_max = cfg.get("creak_max", 18.0)
	saw_timer = randf_range(15.0, 30.0)
	saw_p.stop()


## Cuts each one-shot off after its max length, fading the last 30%.
func _apply_caps(delta: float) -> void:
	for p in caps:
		var c: Array = caps[p]
		if not p.playing:
			continue
		c[2] += delta
		var max_len: float = c[0]
		var fade_from := max_len * 0.7
		if c[2] >= max_len:
			p.stop()
			p.volume_db = c[1]
		elif c[2] > fade_from:
			var k: float = (c[2] - fade_from) / (max_len - fade_from)
			p.volume_db = c[1] - 40.0 * k


func _restart(p) -> void:
	if caps.has(p):
		caps[p][2] = 0.0
		p.volume_db = caps[p][1]
	p.play()


## Jump-scare hit. Falls back to a loud glitch if no sting is loaded.
func sting() -> void:
	if sounds.has("sting"):
		var p := AudioStreamPlayer.new()
		p.volume_db = 0.0
		p.stream = _pick("sting")
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	elif sounds.has("glitch"):
		glitch_cooldown = 0.0
		_one(glitch_p, "glitch")


func step() -> void:
	if not sounds.has("step"):
		return
	steps_p.stream = _pick("step")
	steps_p.pitch_scale = randf_range(0.9, 1.1)
	_restart(steps_p)


func click() -> void:
	_one(click_p, "flashlight_click")


func camcorder(on: bool) -> void:
	if on:
		_one(cam_on_p, "camcorder_on")
		if cam_loop.stream != null:
			cam_loop.play()
	else:
		cam_loop.stop()


func spray() -> void:
	_one(spray_p, "spray")


func glitch(amount: float) -> void:
	if amount > 0.5 and glitch_cooldown <= 0.0 and sounds.has("glitch"):
		glitch_cooldown = 4.0
		_one(glitch_p, "glitch")


# ---------- helpers ----------

func _one(p: AudioStreamPlayer, n: String) -> void:
	if not sounds.has(n):
		return
	p.stream = _pick(n)
	_restart(p)


func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


func _next_wind() -> void:
	wind.stream = _pick("wind_loop")
	wind.play()


## One-shot at a point in the world; the player frees itself when done.
func play_at(stream: AudioStream, pos: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 6.0
	p.max_distance = 80.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## A random variant of a group, or null if none was loaded.
func get_stream(group: String) -> AudioStream:
	return _pick(group) if sounds.has(group) else null


func _pick(group: String) -> AudioStream:
	return sounds[group].pick_random()


## Finds every playable file in res://audio and sorts it into a group.
func _scan() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return
	var seen := {}
	for f in dir.get_files():
		# Exported builds list "name.wav.import" instead of "name.wav".
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if seen.has(file) or not PLAYABLE.has(file.get_extension().to_lower()):
			continue
		seen[file] = true
		var group := _group_of(file.get_basename().to_lower())
		if group == "":
			continue
		var path := "%s/%s" % [AUDIO_DIR, file]
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		if not sounds.has(group):
			sounds[group] = []
		sounds[group].append(stream)


func _group_of(base: String) -> String:
	for g in GROUPS:
		if base == g:
			return g
		if base.begins_with(g):
			var rest := base.substr(g.length()).trim_prefix("_")
			if rest.is_valid_int():
				return g
	return ""
