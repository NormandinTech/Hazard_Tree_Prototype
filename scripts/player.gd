extends CharacterBody3D
## The assessor: walk, flashlight, camcorder (shows render layer 2), tagging.
## Every camcorder session is saved as a tape by the recorder.

const HazardTreeScript = preload("res://scripts/hazard_tree.gd")
const RecorderScript = preload("res://scripts/recorder.gd")

const WALK_SPEED := 2.0
const SPRINT_SPEED := 3.6
const GRAVITY := 9.8
const MOUSE_SENS := 0.0022
const ASSESS_TIME := 5.0
const ASSESS_RANGE := 14.0
const TAG_RANGE := 3.0
const BATTERY_DRAIN := 0.55   # percent per second, about 3 minutes of light
const NORMAL_FOV := 70.0
const CAMCORDER_FOV := 55.0

var main
var hud
var recorder
var audio
var last_step := 0
var head: Node3D
var cam: Camera3D
var flashlight: SpotLight3D
var ray: RayCast3D

var battery := 100.0
var flashlight_on := false
var recording := false
var tablet_open := false
var rec_time := 0.0
var bob_t := 0.0
var told_about_tapes := false
var interference := 0.0   # set by the director when the thing is near

# Backpack pump (a bladder bag): hold 5 to spray. Refills at the truck.
const WATER_USE := 7.0     # percent per second, about 14 s of spray
const SPRAY_RANGE := 7.0
var water := 100.0
var spraying := false
var nozzle: CPUParticles3D
var _spray_player: AudioStreamPlayer
var _spray_gen: AudioStreamGeneratorPlayback
var _spray_lp := 0.0
var _spray_vol := 0.0
var carrying: Node3D = null   # an animal in your arms


func _ready() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	cam = Camera3D.new()
	cam.fov = NORMAL_FOV
	cam.far = 120.0
	cam.cull_mask = 1   # layer 1 only; the camcorder adds layer 2
	cam.current = true
	head.add_child(cam)

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = 4.0
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 2.5   # a visible beam through the haze
	# A real flashlight isn't an even cone: a hot center, a ring from the
	# reflector, and dim spill. Soft shadows that sharpen near contact.
	flashlight.light_projector = _beam_pattern()
	flashlight.light_size = 0.04
	flashlight.shadow_blur = 1.2
	flashlight.spot_attenuation = 1.2
	flashlight.spot_angle_attenuation = 0.6
	flashlight.light_specular = 0.6
	flashlight.visible = false
	cam.add_child(flashlight)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -ASSESS_RANGE)
	ray.add_exception(self)
	cam.add_child(ray)

	_build_pump()

	recorder = RecorderScript.new()
	recorder.cam = cam
	add_child(recorder)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_pump() -> void:
	# Water from the wand, low and to the right, arcing out in front of you.
	nozzle = CPUParticles3D.new()
	nozzle.amount = 160
	nozzle.lifetime = 0.75
	nozzle.emitting = false
	nozzle.local_coords = false
	nozzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	nozzle.emission_sphere_radius = 0.02
	nozzle.direction = Vector3(-0.05, 0.12, -1)
	nozzle.spread = 4.0
	nozzle.initial_velocity_min = 8.5
	nozzle.initial_velocity_max = 10.0
	nozzle.gravity = Vector3(0, -9.8, 0)
	nozzle.scale_amount_min = 0.6
	nozzle.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.78, 0.84, 0.9, 0.45)
	m.roughness = 0.1
	m.metallic_specular = 1.0
	var drop := GradientTexture2D.new()
	drop.width = 32
	drop.height = 32
	drop.fill = GradientTexture2D.FILL_RADIAL
	drop.fill_from = Vector2(0.5, 0.5)
	drop.fill_to = Vector2(0.5, 0.0)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	drop.gradient = dg
	m.albedo_texture = drop
	q.material = m
	nozzle.mesh = q
	nozzle.position = Vector3(0.22, -0.32, -0.45)
	cam.add_child(nozzle)
	# Wand tip, visible at the bottom right of the screen while spraying.
	var wand := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.012
	wm.bottom_radius = 0.016
	wm.height = 0.45
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.55, 0.55, 0.52)
	wmat.metallic = 0.7
	wmat.roughness = 0.35
	wm.material = wmat
	wand.mesh = wm
	wand.rotation_degrees = Vector3(-80, 0, 0)
	wand.position = Vector3(0.22, -0.34, -0.25)
	wand.name = "Wand"
	wand.visible = false
	cam.add_child(wand)
	# Spray hiss, made on the fly.
	_spray_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	_spray_player.stream = gen
	_spray_player.volume_db = -6.0
	add_child(_spray_player)
	_spray_player.play()
	_spray_gen = _spray_player.get_stream_playback()


func _update_pump(delta: float) -> void:
	var want := Input.is_action_pressed("spray") and not tablet_open and water > 0.0 and carrying == null
	if want and not spraying and water <= 0.0:
		want = false
	spraying = want
	if spraying:
		water = maxf(water - WATER_USE * delta, 0.0)
		if water <= 0.0:
			spraying = false
			hud.flash("Bag's empty. Refill at the truck.", 2.5)
	elif Input.is_action_just_pressed("spray") and water <= 0.0:
		hud.flash("Bag's empty. Refill at the truck.", 2.5)
	nozzle.emitting = spraying
	cam.get_node("Wand").visible = spraying
	hud.set_water(water)
	# Hiss: bright noise while the trigger's held, a sputter as the bag runs low.
	var target := 0.0
	if spraying:
		target = 0.35 if water > 10.0 else 0.35 * (0.4 + 0.6 * randf())
	if _spray_gen != null:
		for i in _spray_gen.get_frames_available():
			_spray_vol = move_toward(_spray_vol, target, 0.0004)
			var white := randf() * 2.0 - 1.0
			_spray_lp += 0.5 * (white - _spray_lp)
			var smp := _spray_lp * _spray_vol
			_spray_gen.push_frame(Vector2(smp, smp))


func _beam_pattern() -> Texture2D:
	var t := GradientTexture2D.new()
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.3, 0.36, 0.42, 0.7, 0.95, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.97, 0.9), Color(0.95, 0.92, 0.85),   # hot spot
		Color(0.55, 0.53, 0.5), Color(0.75, 0.72, 0.66),  # reflector ring
		Color(0.4, 0.38, 0.36), Color(0.22, 0.21, 0.2),   # spill
		Color(0.06, 0.06, 0.06), Color(0, 0, 0),
	])
	t.gradient = g
	return t


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if tablet_open:
		input = Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var speed := WALK_SPEED
	if recording:
		speed = WALK_SPEED * 0.6
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	# Handheld bob.
	if dir.length() > 0.1 and is_on_floor():
		bob_t += delta * speed * 2.2
		cam.position.y = sin(bob_t) * 0.04
		var step_idx := int(bob_t / PI)
		if step_idx != last_step:
			last_step = step_idx
			if audio != null:
				audio.step()
		cam.position.x = cos(bob_t * 0.5) * 0.02
	else:
		cam.position = cam.position.lerp(Vector3.ZERO, delta * 6.0)


func _process(delta: float) -> void:
	if hud == null or main == null:
		return

	if Input.is_action_just_pressed("tablet"):
		tablet_open = not tablet_open
		hud.show_tablet(tablet_open)

	_update_flashlight(delta)
	_update_camcorder(delta)
	_update_pump(delta)

	var target = null
	if ray.is_colliding():
		var hit = ray.get_collider()
		if hit is HazardTreeScript:
			target = hit
	_handle_target(target, delta)

	recorder.tick(delta)

	if Input.is_action_just_pressed("interact"):
		main.try_file_order(global_position)
	if Input.is_action_just_pressed("tag_leak"):
		main.try_flag_leak(global_position)


func _update_flashlight(delta: float) -> void:
	if Input.is_action_just_pressed("flashlight") and battery > 0.0:
		flashlight_on = not flashlight_on
		if audio != null:
			audio.click()
	if flashlight_on:
		battery = max(battery - delta * BATTERY_DRAIN, 0.0)
		if battery <= 0.0:
			flashlight_on = false
		elif battery < 15.0:
			flashlight.light_energy = 4.0 * (0.35 + 0.65 * randf())   # dying flicker
		else:
			flashlight.light_energy = 4.0
		# Something close by makes the light stutter.
		if interference > 0.0:
			flashlight.light_energy *= 1.0 - interference * randf() * 0.9
	flashlight.visible = flashlight_on
	hud.set_battery(battery)


func _update_camcorder(delta: float) -> void:
	var want := Input.is_action_pressed("camcorder") and not tablet_open
	if want != recording:
		recording = want
		if recording:
			recorder.start_clip()
		else:
			var kept: bool = recorder.stop_clip()
			if kept and not told_about_tapes:
				told_about_tapes = true
				hud.flash("Tape saved. Review your tapes on the tablet: TAB, then Q.", 4.0)
		cam.cull_mask = 3 if recording else 1   # 3 = layers 1 and 2
		if audio != null:
			audio.camcorder(recording)
		cam.fov = CAMCORDER_FOV if recording else NORMAL_FOV
		hud.show_camcorder(recording)
	if recording:
		rec_time += delta
		hud.set_rec_time(rec_time)


func _handle_target(t, delta: float) -> void:
	if t == null:
		hud.set_prompt(main.truck_prompt(global_position))
		main.try_rate_input(global_position)
		return
	if not t.is_work_order:
		hud.set_prompt("Not on the work order" if recording else "")
		return

	if recording:
		recorder.note_tree(t.tree_id)

	if not t.is_assessed:
		if recording:
			main.on_recording_tree(t, global_position)
			t.assess_progress += delta
			var pct := int(min(t.assess_progress / ASSESS_TIME, 1.0) * 100.0)
			hud.set_prompt("Recording %s ... %d%%" % [t.tree_id, pct])
			if t.assess_progress >= ASSESS_TIME:
				t.mark_assessed()
				main.on_tree_updated()
		else:
			hud.set_prompt("%s — hold Right Mouse to record" % t.tree_id)
		return

	if t.tag == "":
		var dist := global_position.distance_to(t.global_position)
		if dist <= TAG_RANGE:
			hud.set_prompt("%s recorded — tag it:  [1] Remove   [2] Monitor   [3] Retain" % t.tree_id)
			if Input.is_action_just_pressed("tag_remove"):
				t.apply_tag("remove")
			elif Input.is_action_just_pressed("tag_monitor"):
				t.apply_tag("monitor")
			elif Input.is_action_just_pressed("tag_retain"):
				t.apply_tag("retain")
			if t.tag != "":
				main.on_tree_updated()
				if audio != null:
					audio.spray()
		else:
			hud.set_prompt("%s recorded — walk up to tag it" % t.tree_id)
		return

	hud.set_prompt("%s — tagged %s" % [t.tree_id, t.tag.to_upper()])
