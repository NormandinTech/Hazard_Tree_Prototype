extends Node3D
## Builds the gray-box parcel and runs the shifts: work orders, camcorder-only
## anomalies, carry-over between shifts, and filing at the truck.

const HazardTreeScript = preload("res://scripts/hazard_tree.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")
const TownScript = preload("res://scripts/town.gd")
const TruckScript = preload("res://scripts/truck.gd")
const TaskItemScript = preload("res://scripts/task_item.gd")
const FlashbackScript = preload("res://scripts/flashback.gd")
const DirectorScript = preload("res://scripts/director.gd")
const NoteScript = preload("res://scripts/note.gd")
const StalkerTreeScript = preload("res://scripts/stalker_tree.gd")
const AtmosphereScript = preload("res://scripts/atmosphere.gd")
const AnimalScript = preload("res://scripts/animal.gd")
const PauseScript = preload("res://scripts/pause_menu.gd")

# The opening, before Shift 1.
const INTRO := [
	"KESTREL RIDGE, CALIFORNIA\n\nPopulation 11,300",
	"On the morning of October 3rd, a worn steel hook on a Sierra Northern Power transmission tower gave way.\n\nA live line fell into the oldest tree on the ridge.",
	"The wind did the rest.\n\nIn four hours, the fire crossed the town.",
	"Not everyone got out.",
	"Sierra Northern Power has not accepted responsibility.\n\nIts contractors are clearing what is left.",
	"Hazard-tree assessors walk the burn scar ahead of the cutting crews.\nThey film every damaged tree and mark the ones that could fall.\n\nThe ones marked REMOVE are cut down.",
	"Nineteen days ago, Unit HT-6 stopped answering the radio.\n\nTheir truck was found on Parcel 7B with the engine running.",
	"You are Unit HT-7.\n\nParcel 7B is yours now.",
]

# Unit HT-6's field notes. Drafts: rewrite these in your own voice.
# Each sits a couple of meters from the item named in "near".
const NOTES := [
	[{"near": "HT-103", "title": "Day 1", "text": "HT-6 log, day 1. Parcel 7B, Kestrel Ridge.\n\nThe county signs the checks, but every work order comes stamped SIERRA NORTHERN POWER. Their fire. Their cleanup. Their paperwork.\n\n31 trees on the order. Most of them are already dead and don't know it yet.\n\nThe camera keeps catching a smudge at the treeline. Cleaned the lens twice. Still there."}],
	[{"near": "HT-202", "title": "Day 3", "text": "Day 3.\n\nMy tags moved. Not fell. Moved. I sprayed HT-114 red yesterday and this morning the red is on a snag forty feet away that I never touched.\n\nCalled it in. Dispatch says I'm the only unit on 7B."},
	 {"near": "HT-205", "title": "Day 4", "text": "Day 4.\n\nThere's a tree behind every tree I film. The same one. Only on the tape.\n\nI went back to the spot with a tape measure. Nothing there but ash and a ring of root holes, like something stood up and walked off."}],
	[{"near": "HT-301", "title": "Day 5", "text": "Day 5.\n\nSierra Northern says they shut the gas off at every lot on the 9th. I can hear three of them hissing from the truck.\n\nSNP had a crew up here the morning after the fire, before the bodies were out. Not to help. A man in a white truck climbed one of their towers, took something off it, and drove away. The neighbors saw. Nobody wrote it down."},
	 {"near": "HT-304", "title": "Day 6", "text": "Day 6.\n\nFilmed the chimney for the owners. Played it back in the cab with the doors locked.\n\nThe house was there. Lights on. I could hear a sprinkler going.\n\nI watched it nine times."}],
	[{"near": "HT-401", "title": "Day 8", "text": "Day 8.\n\nIt's a tree. I know how that sounds.\n\nIt's never where it was. It only holds still when I'm filming it, and the second I drop the camera to paint, I hear the roots drag.\n\nIt comes faster when I paint REMOVE. I think it knows what the red means. I think they were its family."},
	 {"near": "ORIGIN", "title": "Day 9", "text": "Day 9.\n\nFound it. Line 7, Tower 7/22. One insulator string is just gone, and the hook that held it is worn through like a bitten coin. The other hook from this tower is the thing SNP's man took.\n\nThe line came down on the big pine first. Oldest tree on the ridge. It burned standing for a day, and the stump kept burning underground for a month after.\n\nThat's where the hole is."},
	 {"near": "HT-405", "title": "Day 9, night", "text": "Day 9, night.\n\nSearch team came through and marked the lots. They missed one.\n\nThey always miss one. I think it's for us."}],
	[{"near": "HOLE", "title": "Day 10", "text": "Day 10.\n\nThere was a tree here. A big one. Before. I've seen it on the tape, and I've seen it with my own eyes for a second at a time.\n\nI think the hole is where it went. I think that's where all of it went. The houses. The people.\n\nI'm going down to look. Leaving the camera running.\n\nIf you're reading this, you're the next unit. Don't paint the trees. Don't."}],
]

const TRUCK_POS := Vector3(0, 0, 7)
const START_POS := Vector3(0, 0, 3)
const FILE_RANGE := 4.5
const STUMP_HOLE_POS := Vector3(-4, 0, -80)

# Each shift: lighting, work order, where the anomalies sit, and sound pressure.
# "recheck" lists earlier trees whose tags have "gone missing" and reappeared
# on a nearby tree the player never touched.
const SHIFTS := [
	{
		"title": "SHIFT 1 — MORNING",
		"order": "WORK ORDER 0417 — PARCEL 7B",
		"sub": "Shift 1 · Morning · Hazard-tree assessment",
		"bg": Color(0.34, 0.33, 0.31), "ambient": Color(0.45, 0.43, 0.40), "ambient_energy": 0.45,
		"fog": Color(0.36, 0.35, 0.33), "fog_density": 0.06,
		"sun": Color(1.0, 0.92, 0.82), "sun_energy": 0.5, "sun_rot": Vector3(-50, 30, 0),
		"trees": [
			{"id": "HT-101", "pos": Vector3(6, 0, -8), "hint": "About 15 m ahead, right of the truck"},
			{"id": "HT-102", "pos": Vector3(-11, 0, -17), "hint": "About 25 m out, left side"},
			{"id": "HT-103", "pos": Vector3(16, 0, -24), "hint": "About 35 m out, right side"},
			{"id": "HT-104", "pos": Vector3(-5, 0, -36), "hint": "Straight ahead, about 45 m"},
			{"id": "HT-105", "pos": Vector3(22, 0, -44), "hint": "Far right, about 55 m"},
			{"id": "HT-106", "pos": Vector3(-19, 0, -52), "hint": "Far left, about 60 m"},
		],
		"recheck": [],
		"events": 150.0,
		"figure_spots": [Vector3(10, 0, -50), Vector3(-24, 0, -30), Vector3(28, 0, -20), Vector3(-8, 0, -62)],
		"phantom": Vector3(4, 0, -22),
		"replay_trees": ["HT-103", "HT-106"],
		"open_figure": false,
		"audio": {"saw_distance": 50.0, "saw_group": "chainsaw_far", "creak_min": 7.0, "creak_max": 18.0},
	},
	{
		"title": "SHIFT 2 — AFTERNOON",
		"order": "WORK ORDER 0418 — PARCEL 7B",
		"sub": "Shift 2 · Afternoon · Assessment + re-checks",
		"bg": Color(0.36, 0.31, 0.25), "ambient": Color(0.48, 0.40, 0.32), "ambient_energy": 0.38,
		"fog": Color(0.38, 0.32, 0.26), "fog_density": 0.07,
		"sun": Color(1.0, 0.72, 0.48), "sun_energy": 0.55, "sun_rot": Vector3(-18, 70, 0),
		"trees": [
			{"id": "HT-201", "pos": Vector3(20, 0, -58), "hint": "Right side, past HT-105, about 65 m"},
			{"id": "HT-202", "pos": Vector3(-28, 0, -44), "hint": "Left edge, west of HT-106"},
			{"id": "HT-203", "pos": Vector3(8, 0, -66), "hint": "Deep, about 70 m straight out"},
			{"id": "HT-204", "pos": Vector3(-14, 0, -68), "hint": "Deep left, near the burned-out center"},
			{"id": "HT-205", "pos": Vector3(30, 0, -34), "hint": "Right edge, about 45 m"},
			{"id": "HT-206", "pos": Vector3(2, 0, -74), "hint": "Closest to the stump hole. Do not enter the hole."},
			{"id": "HT-207", "pos": Vector3(-36, 0, -8), "hint": "Left, near Old Mill Rd"},
			{"id": "HT-208", "pos": Vector3(12, 0, -48), "hint": "Middle of the parcel"},
		],
		"stalk": 0.9, "cool_min": 50.0, "cool_max": 80.0, "falls": 140.0, "events": 75.0,
		"poles": [Vector3(16, 0, 9.5), Vector3(-16, 0, 9.5)], "xfmr": Vector3(-48, 0, 9.5),
		"recheck": ["HT-102", "HT-104"],
		"figure_spots": [Vector3(12, 0, -30), Vector3(-16, 0, -12), Vector3(20, 0, -10), Vector3(-6, 0, -26)],
		"phantom": Vector3(-8, 0, -50),
		"replay_trees": ["HT-203", "HT-206"],
		"open_figure": true,
		"audio": {"saw_distance": 25.0, "saw_group": "chainsaw_close", "creak_min": 4.0, "creak_max": 10.0},
	},
	{
		"title": "SHIFT 3 — DUSK",
		"order": "WORK ORDER 0419 — PARCEL 7B + ADJACENT LOTS",
		"sub": "Shift 3 · Dusk · Trees, gas leaks, owner request",
		"bg": Color(0.21, 0.18, 0.18), "ambient": Color(0.34, 0.30, 0.30), "ambient_energy": 0.26,
		"fog": Color(0.24, 0.20, 0.19), "fog_density": 0.08,
		"sun": Color(0.95, 0.62, 0.45), "sun_energy": 0.22, "sun_rot": Vector3(-6, 100, 0),
		"trees": [
			{"id": "HT-301", "pos": Vector3(-34, 0, -60), "hint": "Far left, toward Old Mill Rd"},
			{"id": "HT-302", "pos": Vector3(34, 0, -62), "hint": "Far right, toward Clearview Dr"},
			{"id": "HT-303", "pos": Vector3(-20, 0, -86), "hint": "Past the stump hole, left side"},
			{"id": "HT-304", "pos": Vector3(14, 0, -88), "hint": "Past the stump hole, right side"},
			{"id": "HT-305", "pos": Vector3(-36, 0, -20), "hint": "Left, along the old fence line"},
			{"id": "HT-306", "pos": Vector3(0, 0, -52), "hint": "Dead center of the parcel"},
			{"id": "HT-307", "pos": Vector3(24, 0, -90), "hint": "Deep right, past the bare slab"},
		],
		"stalk": 1.2, "cool_min": 40.0, "cool_max": 65.0, "falls": 110.0, "events": 60.0,
		"poles": [Vector3(-39.5, 0, 8), Vector3(-39.5, 0, -56)], "xfmr": Vector3(48, 0, 9.5),
		"recheck": ["HT-201"],
		"leaks": 3,
		"doc": true,
		"figure_spots": [Vector3(6, 0, -14), Vector3(-10, 0, -6), Vector3(14, 0, -2), Vector3(-4, 0, -20)],
		"phantom": Vector3(10, 0, -40),
		"replay_trees": ["HT-302", "HT-304"],
		"open_figure": true,
		"audio": {"saw_distance": 15.0, "saw_group": "chainsaw_close", "creak_min": 3.0, "creak_max": 8.0},
	},
	{
		"title": "SHIFT 4 — NIGHT",
		"order": "WORK ORDER 0420 — PARCEL 7B (NIGHT, EMERGENCY)",
		"sub": "Shift 4 · Night · Search teams came through. Work around their markers.",
		"bg": Color(0.03, 0.035, 0.05), "ambient": Color(0.28, 0.33, 0.46), "ambient_energy": 0.24,
		"fog": Color(0.03, 0.035, 0.05), "fog_density": 0.065,
		"sun": Color(0.6, 0.7, 0.95), "sun_energy": 0.07, "sun_rot": Vector3(-40, -60, 0),
		"trees": [
			{"id": "HT-401", "pos": Vector3(-16, 0, -40), "hint": "Left of center, between HT-104 and HT-202"},
			{"id": "HT-402", "pos": Vector3(18, 0, -72), "hint": "Right side, deep, near the bare slab"},
			{"id": "HT-403", "pos": Vector3(-24, 0, -62), "hint": "Left, beside the search team's markers"},
			{"id": "HT-404", "pos": Vector3(38, 0, -22), "hint": "Far right, by Clearview Dr"},
			{"id": "HT-405", "pos": Vector3(-6, 0, -92), "hint": "Behind the stump hole"},
			{"id": "HT-406", "pos": Vector3(-40, 0, -88), "hint": "Far left corner of the parcel"},
			{"id": "HT-407", "pos": Vector3(8, 0, -28), "hint": "Close to the truck, right of center"},
		],
		"stalk": 1.5, "cool_min": 28.0, "cool_max": 48.0, "falls": 80.0, "events": 45.0,
		"poles": [Vector3(52.5, 0, -24)], "origin": true,
		"recheck": ["HT-302"],
		"remains": true,
		"markers": 2,
		"scares": true,
		"figure_spots": [Vector3(4, 0, -10), Vector3(-8, 0, -4), Vector3(10, 0, 0), Vector3(-2, 0, -14)],
		"phantom": Vector3(-12, 0, -30),
		"replay_trees": ["HT-401", "HT-403", "HT-405"],
		"open_figure": true,
		"audio": {"saw_distance": 12.0, "saw_group": "chainsaw_close", "creak_min": 2.5, "creak_max": 7.0},
	},
	{
		"title": "SHIFT 5 — BEFORE DAWN",
		"order": "WORK ORDER 0421 — PARCEL 7B (FINAL)",
		"sub": "Shift 5 · Before dawn · One item.",
		"bg": Color(0.07, 0.08, 0.11), "ambient": Color(0.3, 0.33, 0.42), "ambient_energy": 0.2,
		"fog": Color(0.08, 0.09, 0.12), "fog_density": 0.06,
		"sun": Color(0.55, 0.6, 0.8), "sun_energy": 0.1, "sun_rot": Vector3(-12, 160, 0),
		"trees": [],
		"recheck": [],
		"hole": true,
		"flicker": true,
		"stalk": 1.0, "cool_min": 25.0, "cool_max": 40.0, "events": 40.0,
		"figure_spots": [Vector3(-4, 0, -66), Vector3(6, 0, -72), Vector3(-12, 0, -76), Vector3(2, 0, -60)],
		"phantom": Vector3(4, 0, -64),
		"replay_trees": [],
		"open_figure": false,
		"audio": {"saw_distance": 30.0, "saw_group": "chainsaw_far", "creak_min": 6.0, "creak_max": 14.0},
	},
]

# Daylight, for flashback frames.
const DAY := {
	"bg": Color(0.55, 0.70, 0.86), "ambient": Color(0.72, 0.74, 0.78), "ambient_energy": 0.9,
	"fog": Color(0.76, 0.83, 0.9), "fog_density": 0.012,
	"sun": Color(1.0, 0.97, 0.9), "sun_energy": 1.2, "sun_rot": Vector3(-55, 40, 0),
}
const DOC_TIME := 5.0
const FLASHBACK_FROM := 1.5   # seconds into filming the chimney

var player
var hud
var audio
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var truck: StaticBody3D
var town
var all_trees := {}        # id -> work-order tree, across every shift
var work_trees: Array = [] # this shift's order
var snags: Array = []
var figure: Node3D
var phantom_tree: MeshInstance3D
var replay_figure: Node3D
var open_figure: Node3D
var replay_placed := {}
var figure_spots: Array = []
var figure_spot := 0
var figure_seen := 0.0
var shift := 0
var cfg: Dictionary
var shift_done := false
var open_figure_used := false
var rec_streak := 0.0
var snags_root: Node3D
var items: Array = []          # leaks and other non-tree tasks, across shifts
var doc_item = null
var doc_chimney: StaticBody3D
var doc_progress := 0.0
var past: Node3D               # the flashback scene, hidden except on capture frames
var flashback_on := false
var smelled := {}
var remains_item = null
var was_recording := false
var scare_cam_done := false
var scare_radio_done := false
var scare_timer := 0.0
const RECHARGE_RANGE := 6.0
var hole_root: Node3D
var hole_cover: Array = []     # discs over the hole, hidden when you climb in
var past_world: Node3D         # the whole town before the fire (Shift 5)
var flicker_on := false
var flicker_left := 0.0
var flicker_timer := 4.0
var hole_item = null
var ending := false
var director
var knocked := false
var tag_order: Array = []     # items in the order they were finished, for losing work
var notes_here: Array = []
const HOLE_RANGE := 5.0


var atmosphere

# Fires and survivors.
var animals: Array = []
var dog = null
var dog_spot := Vector3.ZERO
var dog_saved := false
var cat_saved := false
var fawn_helped := false
var dog2_saved := false
var watered_count := 0       # wild survivors given water
var homed_dogs := 0
var fires_out := 0
var blaze = null
var blaze_item = null
var too_hot_t := 0.0
var lure: Node3D = null
var lure_t := 0.0
var lure_called := false
var lure_sprung := false
const PUMP_REFILL := 30.0


## A few stumps still smoldering days later: a coal, a glow, a thread of smoke.
func _place_smolders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7022
	var placed := 0
	var tries := 0
	while placed < 9 and tries < 200:
		tries += 1
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-110, 12))
		if p.distance_to(TRUCK_POS) < 12.0 or p.distance_to(STUMP_HOLE_POS) < 8.0:
			continue
		if town.blocked(p, 1.5):
			continue
		atmosphere.add_smolder(p)
		placed += 1


func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_ground()
	_build_town()
	_build_forest()
	_build_truck()
	_build_stump_hole()
	_build_anomalies()
	TownScript.SurfacesScript.report()

	atmosphere = AtmosphereScript.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.build()
	_place_smolders()

	hud = HudScript.new()
	add_child(hud)
	atmosphere.attach_lens(hud)
	var pause = PauseScript.new()
	pause.main = self
	add_child(pause)

	player = PlayerScript.new()
	player.position = START_POS
	player.main = self
	player.hud = hud
	add_child(player)
	hud.recorder = player.recorder
	hud.player = player
	player.recorder.capture_hook = _on_capture
	atmosphere.player = player

	audio = AudioScript.new()
	audio.player = player
	add_child(audio)
	player.audio = audio

	director = DirectorScript.new()
	director.main = self
	director.player = player
	director.hud = hud
	director.audio = audio
	director.figure = figure
	add_child(director)

	_start_shift(0)
	_set_player_active(false)
	hud.play_intro(INTRO, _intro_done)


func _intro_done() -> void:
	_set_player_active(true)
	hud.flash("%s\nPress TAB to read the work order." % cfg["title"], 6.0)


## Graphics quality: 0 Low, 1 Medium, 2 High. F10 cycles it in game.
var quality := 1   # starts on Medium; High adds full global illumination (SDFGI)
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH"]


func _apply_quality(q: int) -> void:
	quality = q
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 1
	env.sdfgi_enabled = q >= 2
	env.volumetric_fog_enabled = q >= 1
	env.glow_enabled = true
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X if q >= 2 else (Viewport.MSAA_2X if q == 1 else Viewport.MSAA_DISABLED)
	vp.scaling_3d_scale = 1.0 if q >= 1 else 0.77
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if q >= 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if q >= 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_apply_quality((quality + 1) % 3)   # Medium -> High -> Low -> Medium
		hud.flash("Graphics: %s" % QUALITY_NAMES[quality], 2.0, true)
		return
	# Dev shortcut while testing: F9 skips to the next shift.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		if shift + 1 < SHIFTS.size() and not shift_done:
			for t in work_trees:
				if not t.is_assessed:
					t.mark_assessed()
				if t.tag == "":
					t.apply_tag("monitor")
			try_file_order(TRUCK_POS)


func _process(delta: float) -> void:
	if player == null or shift_done or ending:
		return
	var glitch := 0.0
	var cam: Camera3D = player.cam

	if director.active():
		glitch = director.tick(delta)
	elif player.recording and figure.visible:
		var dist := cam.global_position.distance_to(figure.global_position)
		if cam.is_position_in_frustum(figure.global_position) and dist < 35.0:
			figure_seen += delta
			glitch = clamp(figure_seen / 1.5, 0.0, 1.0)
			if figure_seen > 1.5:
				figure.visible = false
				figure_seen = 0.0

	if not director.active():
		director.tick(delta)   # falls and events still run in calm shifts
	# Once the camera comes down, the figure is somewhere else.
	if not director.active() and not player.recording and not figure.visible:
		figure_spot = (figure_spot + 1) % figure_spots.size()
		figure.position = figure_spots[figure_spot] + Vector3(0, 0.975, 0)
		figure.visible = true

	if player.recording:
		var top := phantom_tree.global_position + Vector3(0, 4, 0)
		if cam.is_position_in_frustum(top) and cam.global_position.distance_to(top) < 22.0:
			glitch = max(glitch, 0.25)

	_update_open_figure(delta)
	_update_flicker(delta)
	# It always turns to face you.
	if figure.visible:
		var p := cam.global_position
		p.y = figure.global_position.y
		if p.distance_to(figure.global_position) > 0.1:
			figure.look_at(p, Vector3.UP)
	glitch = max(glitch, _update_tasks(delta))

	hud.set_glitch(glitch)
	audio.glitch(glitch)


# Once per shift (from Shift 2): something stands in the open, in frame, on tape
# only. Placed a few meters ahead while the player films on the move.
func _update_open_figure(delta: float) -> void:
	if not cfg["open_figure"] or open_figure_used:
		return
	if player.recording and player.velocity.length() > 0.5:
		rec_streak += delta
	else:
		rec_streak = 0.0
	if rec_streak < 2.5:
		return
	open_figure_used = true
	var fwd: Vector3 = -player.cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	open_figure.position = player.global_position + fwd * 7.0 + side * 1.2 + Vector3(0, 0.975, 0)
	open_figure.visible = true
	# Gone again after a few seconds; it only ever existed on the tape.
	get_tree().create_timer(4.0).timeout.connect(_hide_open_figure)


# ---------- shift logic ----------

func _start_shift(n: int) -> void:
	shift = n
	cfg = SHIFTS[n]
	shift_done = false
	open_figure_used = false
	rec_streak = 0.0
	replay_placed.clear()
	replay_figure.visible = false
	open_figure.visible = false

	_apply_light(cfg)

	# This shift's trees come into existence; earlier trees stay as they were left.
	work_trees.clear()
	for entry in cfg["trees"]:
		work_trees.append(_spawn_work_tree(entry))

	# Tags the crew reports missing: the paint has moved to a tree nobody touched.
	for id in cfg["recheck"]:
		if not all_trees.has(id):
			continue
		var t = all_trees[id]
		var old_tag: String = t.tag
		var why := "RE-CHECK: crew reports your tag is missing"
		if old_tag != "":
			why = "RE-CHECK: crew reports your %s tag is missing" % old_tag.to_upper()
		t.reset_for_recheck(why)
		if old_tag != "":
			var snag = _snag_near(t.global_position, 5.0, 12.0)
			if snag != null:
				snag.apply_tag(old_tag)
		work_trees.append(t)

	# Leaks flagged on an earlier shift have been shut off by the utility crew.
	for it in items:
		if it.kind == "leak":
			it.shut_off()
	if cfg.get("leaks", 0) > 0 or cfg.get("doc", false):
		_spawn_tasks()
	if cfg.get("remains", false):
		_spawn_remains()
	_spawn_utility()
	_spawn_survivors()
	if cfg.get("hole", false):
		hole_item = TaskItemScript.new()
		hole_item.kind = "hole"
		hole_item.tree_id = "HT-500"
		hole_item.hint = "Assess the stump hole. Go down if you have to."
		add_child(hole_item)
		hole_item.global_position = STUMP_HOLE_POS
		items.append(hole_item)
		work_trees.append(hole_item)
		_build_past_world()

	figure_spots = cfg["figure_spots"]
	figure_spot = 0
	figure_seen = 0.0
	figure.position = figure_spots[0] + Vector3(0, 0.975, 0)
	figure.visible = true
	phantom_tree.position = cfg["phantom"] + Vector3(0, 5.0, 0)

	audio.configure(cfg["audio"])
	director.configure(cfg)
	_spawn_notes()
	hud.order_title = cfg["order"]
	hud.order_sub = cfg["sub"]
	hud.update_tablet(work_trees)


# ---------- Sierra Northern Power: poles, transformers, the origin tower ----------

const POLE_PREFIX := ["", "PL-2", "PL-3", "PL-4", ""]

func _nearest_pole(p: Vector3, want_standing: bool):
	var best = null
	var best_d := INF
	for info in town.poles:
		if want_standing and info["snapped"]:
			continue
		var d: float = info["node"].global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = info
	return best


func _spawn_utility() -> void:
	var n := 1
	for p in cfg.get("poles", []):
		var info = _nearest_pole(p, false)
		if info == null:
			continue
		var it = TaskItemScript.new()
		it.kind = "pole"
		it.tree_id = "PL-%d%02d" % [shift + 1, n]
		it.hint = "SNP pole condition: char, lean, cracked crossarm. Film it, then rate [1/2/3]."
		it.body = info["body"]
		it.target_node = info["node"]
		add_child(it)
		it.global_position = info["node"].global_position
		items.append(it)
		work_trees.append(it)
		n += 1
	if cfg.has("xfmr"):
		var info = _nearest_pole(cfg["xfmr"], true)
		if info != null:
			var can: StaticBody3D = town.add_transformer(info)
			if shift % 2 == 1:
				town.add_oil_leak(info)
			var it = TaskItemScript.new()
			it.kind = "xfmr"
			it.tree_id = "XF-%d01" % (shift + 1)
			it.hint = "Transformer up the pole: check the can for oil. Film it, then rate [1/2/3]."
			it.body = can
			it.target_node = info["node"]
			add_child(it)
			it.global_position = info["node"].global_position
			items.append(it)
			work_trees.append(it)
	if cfg.get("origin", false):
		var it = TaskItemScript.new()
		it.kind = "origin"
		it.tree_id = "TW-722"
		it.hint = "Investigators want footage of Tower 7/22's hook. SNP says it's off-limits. Film it (8 s)."
		it.body = town.origin_body
		it.record_time = 8.0
		add_child(it)
		it.global_position = town.ORIGIN_POS
		items.append(it)
		work_trees.append(it)


func _utility_item_near(pos: Vector3):
	for it in items:
		if (it.kind == "pole" or it.kind == "xfmr") and it.tag == "":
			var b: Vector3 = it.global_position
			if Vector2(pos.x - b.x, pos.z - b.z).length() < 7.0:
				return it
	return null


## Rating keys when you're standing at a recorded pole or transformer.
func try_rate_input(pos: Vector3) -> void:
	var keys := {"tag_remove": "remove", "tag_monitor": "monitor", "tag_retain": "retain"}
	for action in keys:
		if Input.is_action_just_pressed(action):
			var it = _utility_item_near(pos)
			if it != null and it.is_assessed:
				it.rate(keys[action])
				audio.spray()
				on_tree_updated()
			return


func _update_utility(delta: float) -> void:
	if not player.recording or not player.ray.is_colliding():
		return
	var hit = player.ray.get_collider()
	for it in items:
		if it.body == null or it.is_assessed or it.body != hit:
			continue
		it.progress += delta
		if it.progress >= it.record_time:
			it.is_assessed = true
			if it.kind == "origin":
				it.tag = "recorded"
				hud.flash("Tower 7/22 recorded. The hook is worn through like a bitten coin.", 5.0, true)
				get_tree().create_timer(6.0).timeout.connect(_snp_radio)
			on_tree_updated()
		return


func _snp_radio() -> void:
	audio.glitch(1.0)
	hud.flash("[RADIO]  — Sierra Northern dispatch —  \"Unit seven, who authorized footage of 7/22?\"", 6.0, true)


func _utility_prompt(pos: Vector3) -> String:
	if player.recording and player.ray.is_colliding():
		var hit = player.ray.get_collider()
		for it in items:
			if it.body != null and it.body == hit and not it.is_assessed:
				return "Recording %s ... %d%%" % [it.tree_id, int(minf(it.progress / it.record_time, 1.0) * 100.0)]
	var it = _utility_item_near(pos)
	if it == null:
		return ""
	if not it.is_assessed:
		return "%s — hold Right Mouse on the %s to record" % [it.tree_id, "transformer" if it.kind == "xfmr" else "pole"]
	if it.kind == "xfmr":
		return "%s recorded — rate it:  [1] Leaking   [2] Damaged   [3] OK" % it.tree_id
	return "%s recorded — rate it:  [1] Replace   [2] Repair   [3] OK" % it.tree_id


func _spawn_notes() -> void:
	for n in notes_here:
		if is_instance_valid(n) and not n.taken:
			n.queue_free()
	notes_here.clear()
	if shift >= NOTES.size():
		return
	for entry in NOTES[shift]:
		var at: Vector3
		if entry["near"] == "HOLE":
			at = STUMP_HOLE_POS + Vector3(1.5, 0, 6.0)
		elif entry["near"] == "ORIGIN":
			at = town.ORIGIN_POS + Vector3(4.5, 0, 5.0)
		elif all_trees.has(entry["near"]):
			at = all_trees[entry["near"]].global_position + Vector3(2.0, 0, 1.6)
		else:
			continue
		var n = NoteScript.new()
		n.title = entry["title"]
		n.text = entry["text"]
		add_child(n)
		n.global_position = at
		notes_here.append(n)


func _note_near(pos: Vector3):
	for n in notes_here:
		if is_instance_valid(n) and not n.taken and pos.distance_to(n.global_position) < 2.2:
			return n
	return null


## The thing reached you, or a snag came down on you. You lose time and work.
func knockout(msg: String) -> void:
	if knocked or ending:
		return
	knocked = true
	_set_player_active(false)
	# One look at it first.
	var cam: Camera3D = player.cam
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Your light dies. Only its eyes.
	player.flashlight_on = false
	player.flashlight.visible = false
	figure.global_position = cam.global_position + fwd * 1.25 + Vector3(0, -0.8, 0)
	figure.visible = true
	figure.look_at(Vector3(cam.global_position.x, figure.global_position.y, cam.global_position.z), Vector3.UP)
	cam.cull_mask = 3
	audio.sting()
	hud.set_glitch(1.0)
	await get_tree().create_timer(0.5).timeout
	hud.show_card("", 1.5, false, _wake_at_truck.bind(msg))
	await get_tree().create_timer(4.4).timeout
	knocked = false
	_set_player_active(true)


func _wake_at_truck(msg: String) -> void:
	player.cam.cull_mask = 1
	hud.set_glitch(0.0)
	director.banish(1.5)
	_reset_player()
	player.battery = 35.0
	# Your last paint is gone.
	var lost := ""
	for i in range(tag_order.size() - 1, -1, -1):
		var t = tag_order[i]
		if t.get("kind") == null and work_trees.has(t) and t.tag != "":
			t.reset_for_recheck("RE-ASSESS: your paint is gone")
			tag_order.remove_at(i)
			lost = t.tree_id
			break
	on_tree_updated()
	if lost != "":
		msg += "\n%s's paint is gone." % lost
	hud.flash(msg, 6.0, true)


func _apply_light(c: Dictionary) -> void:
	var bg: Color = c["bg"]
	var fogc: Color = c["fog"]
	sky_mat.sky_top_color = bg.darkened(0.35)
	sky_mat.sky_horizon_color = fogc.lerp(bg, 0.3)
	sky_mat.ground_horizon_color = fogc
	sky_mat.ground_bottom_color = fogc.darkened(0.5)
	sky_mat.sun_angle_max = 20.0
	env.background_color = bg
	env.ambient_light_color = c["ambient"]
	env.ambient_light_energy = c["ambient_energy"]
	# Depth fog for distance, volumetric haze for light shafts.
	env.fog_light_color = fogc
	env.fog_density = c["fog_density"] * 0.6
	env.volumetric_fog_density = c["fog_density"] * 0.2
	if atmosphere != null:
		atmosphere.set_light(c)
	env.volumetric_fog_albedo = fogc.lightened(0.4)
	sun.light_color = c["sun"]
	sun.light_energy = c["sun_energy"]
	sun.rotation_degrees = c["sun_rot"]


# ---------- gas leaks, the chimney, and the flashback ----------

func _spawn_tasks() -> void:
	# Use the house lots nearest the parcel: leaks on the closest, the
	# owner's chimney on the next house that has a tall one.
	# Prefer lots inside the parcel, between the two side streets.
	var lots: Array = []
	for info in town.house_lots:
		var p: Vector3 = info["lot"].global_position
		if abs(p.x) < 42.0 and p.z < 6.0 and p.z > -100.0:
			lots.append(info)
	if lots.size() < 4:
		lots = town.house_lots.duplicate()
	var center := Vector3(0, 0, -40)
	lots.sort_custom(func(a, b): return a["lot"].global_position.distance_to(center) < b["lot"].global_position.distance_to(center))
	# The chimney gets first pick of the houses; leaks take the rest.
	var doc_info = null
	if cfg.get("doc", false):
		for info in lots:
			if info["kind"] == "house":
				doc_info = info
				info["used"] = true
				break
	var hiss = audio.get_stream("gas_hiss")
	var n_leaks: int = cfg.get("leaks", 0)
	var used := 0
	for info in lots:
		if used >= n_leaks:
			break
		if info.get("used", false):
			continue
		var lot: Node3D = info["lot"]
		var half: Vector2 = info["half"]
		var leak = TaskItemScript.new()
		leak.kind = "leak"
		leak.tree_id = "GAS-%d" % (used + 1)
		leak.player = player
		leak.hiss_stream = hiss
		add_child(leak)
		leak.global_transform = lot.global_transform * Transform3D(Basis(), Vector3(half.x + 0.3, 0, -half.y * 0.4))
		leak.hint = "Gas meter venting on a burned slab. Flag it [4]."
		items.append(leak)
		work_trees.append(leak)
		info["used"] = true
		used += 1
	if doc_info != null:
		var info = doc_info
		doc_chimney = info["chimney"]
		doc_item = TaskItemScript.new()
		doc_item.kind = "doc"
		doc_item.tree_id = "DOC-1"
		add_child(doc_item)
		doc_item.global_position = doc_chimney.global_position
		doc_item.hint = "Owner's request: film the standing chimney (5 s)."
		items.append(doc_item)
		work_trees.append(doc_item)
		past = FlashbackScript.new()
		past.chimney_pos = info["chimney_pos"]
		past.chimney_h = info["chimney_h"]
		past.half = info["half"]
		add_child(past)
		past.global_transform = info["lot"].global_transform
		past.build()
		past.visible = false


## Shift 4: the search team came through overnight. Their "X" marks are on the
## chimneys, their coroner's markers sit on two lots, and one place they missed.
func _spawn_remains() -> void:
	var lots: Array = []
	for info in town.house_lots:
		var p: Vector3 = info["lot"].global_position
		if abs(p.x) < 42.0 and p.z < 6.0 and p.z > -100.0:
			lots.append(info)
	var center := Vector3(0, 0, -40)
	lots.sort_custom(func(a, b): return a["lot"].global_position.distance_to(center) < b["lot"].global_position.distance_to(center))
	for info in lots:
		_search_mark(info)
	var placed := 0
	for info in lots:
		if info["chimney"] == doc_chimney:
			continue   # leave the family's chimney lot alone
		var lot: Node3D = info["lot"]
		var half: Vector2 = info["half"]
		var it = TaskItemScript.new()
		var is_task: bool = placed == cfg.get("markers", 2)   # the farthest lot is the one they missed
		it.kind = "remains" if is_task else "marker"
		add_child(it)
		# Just off the front of the slab, by the steps.
		it.global_transform = lot.global_transform * Transform3D(Basis(Vector3.UP, 0.3 * placed), Vector3(-half.x * 0.5, 0, half.y + 1.6))
		if is_task:
			it.tree_id = "RPT-1"
			it.hint = "Radio: possible remains the search team missed. Locate and mark for the coroner [4]."
			remains_item = it
			items.append(it)
			work_trees.append(it)
		placed += 1
		if placed > cfg.get("markers", 2):
			break


func _search_mark(info: Dictionary) -> void:
	# Spray-painted search mark on the chimney: an orange X with team and date.
	var body: Node3D = info["chimney"]
	for side in [1.0, -1.0]:
		var x := Label3D.new()
		x.text = "X"
		x.font_size = 160
		x.pixel_size = 0.006
		x.modulate = Color(1.0, 0.35, 0.05)
		x.outline_size = 0
		x.double_sided = false
		x.shaded = true   # only shows when your light is on it
		x.position = Vector3(0, 1.7, -0.1 + 0.49 * side)
		x.rotation.y = 0.0 if side > 0 else PI
		body.add_child(x)
		var code := Label3D.new()
		code.text = "KR-2\n10/14\n0"
		code.font_size = 48
		code.pixel_size = 0.004
		code.modulate = Color(1.0, 0.35, 0.05)
		code.outline_size = 0
		code.double_sided = false
		code.shaded = true
		code.position = Vector3(0.0, 2.65, -0.1 + 0.49 * side)
		code.rotation.y = x.rotation.y
		body.add_child(code)


# ---------- Shift 5: the town flickers back, and the hole ----------

func _build_past_world() -> void:
	past_world = Node3D.new()
	past_world.name = "PastWorld"
	add_child(past_world)
	var grass = TownScript._noise_mat(Color(0.20, 0.32, 0.12), Color(0.34, 0.45, 0.18), 0.12, Vector3(80, 80, 1), "grass")
	var g := CylinderMesh.new()
	g.top_radius = 150.0
	g.bottom_radius = 150.0
	g.height = 0.02
	g.radial_segments = 48
	g.material = grass
	var gm := MeshInstance3D.new()
	gm.mesh = g
	gm.position = Vector3(0, 0.03, -20)
	past_world.add_child(gm)
	for info in town.house_lots:
		if info["chimney"] == doc_chimney:
			continue   # that lot already has its own past
		var h = FlashbackScript.new()
		h.minimal = true
		h.chimney_pos = info["chimney_pos"]
		h.chimney_h = maxf(info["chimney_h"], 4.0)
		h.half = info["half"]
		past_world.add_child(h)
		h.global_transform = info["lot"].global_transform
		h.build()
	for info in town.mobile_lots:
		var lot: Node3D = info["lot"]
		var home := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(info["length"], 3.0, 4.2)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.82, 0.8, 0.72)
		bm.material = paint
		home.mesh = bm
		past_world.add_child(home)
		home.global_transform = lot.global_transform * Transform3D(Basis(), Vector3(0, 2.1, 0))
	# The great pine that stood where the hole is now.
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.32, 0.22, 0.14)
	TownScript.SurfacesScript.apply(bark, "bark", Color(0.9, 0.8, 0.7), false)
	var needles = TownScript._noise_mat(Color(0.07, 0.17, 0.07), Color(0.14, 0.28, 0.11), 0.4, Vector3(3, 3, 1))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.4
	trunk.bottom_radius = 1.3
	trunk.height = 34.0
	trunk.material = bark
	var tm := MeshInstance3D.new()
	tm.mesh = trunk
	tm.position = STUMP_HOLE_POS + Vector3(0, 17.0, 0)
	past_world.add_child(tm)
	for i in 6:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.1
		cone.bottom_radius = 7.0 - i * 1.0
		cone.height = 8.0
		cone.material = needles
		var cm := MeshInstance3D.new()
		cm.mesh = cone
		cm.position = STUMP_HOLE_POS + Vector3(0, 12.0 + i * 3.6, 0)
		past_world.add_child(cm)
	past_world.visible = false


## Flickers of the town before the fire: longer and more often near the hole.
func _update_flicker(delta: float) -> void:
	if not cfg.get("flicker", false) or ending or past_world == null:
		return
	var d: float = player.global_position.distance_to(STUMP_HOLE_POS)
	var near := clampf(1.0 - d / 90.0, 0.0, 1.0)
	if flicker_on:
		flicker_left -= delta
		if flicker_left <= 0.0:
			_set_past(false)
			flicker_timer = lerpf(7.0, 1.5, near) * randf_range(0.6, 1.4)
		return
	flicker_timer -= delta
	if flicker_timer <= 0.0:
		flicker_left = lerpf(0.08, 0.9, near * near) * randf_range(0.7, 1.3)
		_set_past(true)


func _set_past(on: bool) -> void:
	flicker_on = on
	town.ruins.visible = not on
	snags_root.visible = not on
	hole_root.visible = not on
	for id in all_trees:
		all_trees[id].visible = not on
	for it in items:
		if it.kind == "leak" or it.kind == "remains" or it.kind == "marker":
			it.visible = not on
	past_world.visible = on
	if past != null:
		past.visible = on
	_apply_light(DAY if on else cfg)
	# The past is silent.
	AudioServer.set_bus_mute(0, on)


## The ending: climb down, look up. Your truck is parked at the rim, and
## someone is standing over the hole, filming you.
func _run_ending() -> void:
	ending = true
	if flicker_on:
		_set_past(false)
	_set_player_active(false)
	hud.show_tablet(false)
	hud.set_prompt("")
	player.cam.cull_mask = 3
	player.cam.fov = PlayerScript.CAMCORDER_FOV
	hud.show_camcorder(true)
	audio.camcorder(true)
	# Camcorder's own little light instead of the flashlight.
	player.flashlight_on = false
	player.flashlight.visible = false
	var cam_light := OmniLight3D.new()
	cam_light.light_color = Color(1.0, 0.9, 0.75)
	cam_light.light_energy = 0.5
	cam_light.omni_range = 5.0
	player.cam.add_child(cam_light)

	var c := STUMP_HOLE_POS
	var toward: Vector3 = player.global_position - c
	toward.y = 0.0
	if toward.length() < 0.5:
		toward = Vector3(0, 0, 1)
	toward = toward.normalized()

	# Your truck, parked at the rim with its lights on the hole.
	truck.global_position = c + toward * 8.0
	truck.look_at(Vector3(c.x, truck.global_position.y, c.z), Vector3.UP)
	truck.set_headlights(true, -14.0)
	# Whoever is standing over the hole.
	var watcher := _build_watcher()
	var side := toward.cross(Vector3.UP).normalized()
	watcher.global_position = c + toward * 3.0 + side * 1.3
	watcher.look_at(Vector3(c.x, 0, c.z), Vector3.UP)

	# Step to the rim, facing the hole, truck at your back.
	player.global_position = c + toward * 3.4
	player.look_at(player.global_position - toward, Vector3.UP)
	player.rotation.x = 0.0
	var tw := create_tween()
	tw.tween_property(player.head, "rotation:x", deg_to_rad(-55.0), 1.5)
	await tw.finished
	# The covering stays until the camera is below the rim.
	get_tree().create_timer(2.6).timeout.connect(_open_hole)
	tw = create_tween()
	tw.set_parallel(true)
	# Down to the far wall, so the opening frames the rim on the truck side.
	tw.tween_property(player, "global_position", c + Vector3(0, -2.6, 0) - toward * 2.0, 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "rotation:y", player.rotation.y + PI, 5.0)
	await tw.finished
	audio.camcorder(false)
	AudioServer.set_bus_mute(0, true)
	hud.set_glitch(0.6)
	await get_tree().create_timer(1.5).timeout
	hud.set_glitch(0.15)
	AudioServer.set_bus_mute(0, false)
	audio.camcorder(true)
	tw = create_tween()
	tw.tween_property(player.head, "rotation:x", deg_to_rad(34.0), 3.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	# Hold on them. Their REC light blinks; so does yours.
	var t := 0.0
	while t < 3.0:
		t += get_process_delta_time()
		hud.set_glitch(lerpf(0.15, 0.4, t / 3.0))
		await get_tree().process_frame
	await _tree_takes_hole(c, toward, side)
	audio.sting()
	hud.set_glitch(1.0)
	await get_tree().create_timer(0.35).timeout
	audio.camcorder(false)
	hud.cut_to_card("TAPE RECOVERED FROM UNIT HT-7\nPARCEL 7B, %s\n\nOperator not located.\n\nA second camcorder was logged at the scene.\nIts tape has never been found.%s\n\n\nHAZARD TREE" % [TownScript.TOWN_NAME, _survivor_line()])


## The tree rises over the rim beside HT-6, looks down at you, and its roots
## grow across the opening until there is no opening. It takes its place again.
func _tree_takes_hole(c: Vector3, toward: Vector3, side: Vector3) -> void:
	var cam: Camera3D = player.cam
	figure.scale = Vector3(1.7, 1.7, 1.7)
	figure.global_position = c + toward * 3.3 - side * 1.1 + Vector3(0, 1.4, 0)
	figure.visible = true
	figure.look_at(cam.global_position, Vector3.UP)
	# A dim ember light on its face, and your eyes are drawn up to it.
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(1.0, 0.4, 0.1)
	face_light.light_energy = 3.0
	face_light.omni_range = 4.0
	add_child(face_light)
	var face_pos: Vector3 = figure.global_transform * Vector3(0, 0.75, -0.9)
	face_light.global_position = face_pos
	var to_face := face_pos - cam.global_position
	var flat := Vector2(to_face.x, to_face.z)
	var yaw: float = player.rotation.y + wrapf(atan2(-to_face.x, -to_face.z) - player.rotation.y, -PI, PI)
	var pitch := atan2(to_face.y, flat.length())
	var look := create_tween().set_parallel(true)
	look.tween_property(player, "rotation:y", yaw, 1.2).set_trans(Tween.TRANS_SINE)
	look.tween_property(player.head, "rotation:x", pitch, 1.2).set_trans(Tween.TRANS_SINE)
	audio.glitch(1.0)
	hud.set_glitch(0.6)
	var c_stream = audio.get_stream("creak")
	var groan := AudioStreamPlayer3D.new()
	groan.unit_size = 20.0
	groan.volume_db = 10.0
	add_child(groan)
	groan.global_position = c + Vector3(0, 1.0, 0)
	if c_stream != null:
		groan.stream = c_stream
		groan.pitch_scale = 0.3
		groan.play()
	await get_tree().create_timer(1.6).timeout
	# Roots from every side of the rim, growing across.
	var bark = TownScript._noise_mat(Color(0.015, 0.015, 0.015), Color(0.09, 0.08, 0.07), 0.4, Vector3(1, 6, 1), "burnt_bark", Color(0.7, 0.7, 0.7))
	var roots: Array = []
	for i in 14:
		var a := TAU * i / 14.0 + randf_range(-0.15, 0.15)
		var from := c + Vector3(cos(a), 0, sin(a)) * 3.0 + Vector3(0, randf_range(-0.1, 0.25), 0)
		var to := c + Vector3(cos(a + PI + randf_range(-0.7, 0.7)), 0, sin(a + PI + randf_range(-0.7, 0.7))) * 3.0
		to.y = randf_range(-0.6, 0.0)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.global_position = from
		var local_to := to - from
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = randf_range(0.14, 0.3)
		mesh.top_radius = 0.03
		mesh.height = local_to.length()
		mesh.radial_segments = 7
		mesh.material = bark
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var y := local_to.normalized()
		var x := y.cross(Vector3.UP).normalized()
		var z := x.cross(y).normalized()
		mi.transform = Transform3D(Basis(x, y, z), local_to * 0.5)
		pivot.add_child(mi)
		pivot.scale = Vector3(0.01, 0.01, 0.01)
		roots.append(pivot)
	for i in roots.size():
		var tw := create_tween()
		tw.tween_interval(i * 0.18)
		tw.tween_property(roots[i], "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	director.shake_t = 3.5
	# You sink a little as it closes.
	var sink := create_tween()
	sink.tween_property(player, "global_position", player.global_position + Vector3(0, -0.7, 0), 4.2)
	_close_glitch(4.2)
	await get_tree().create_timer(4.2).timeout
	# Last thing on the tape: its eyes, through the gaps.
	player.cam.cull_mask = 3
	await get_tree().create_timer(0.8).timeout
	groan.stop()


func _close_glitch(duration: float) -> void:
	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		hud.set_glitch(lerpf(0.3, 0.9, t / duration))
		await get_tree().process_frame


func _open_hole() -> void:
	for d in hole_cover:
		d.visible = false


func _build_watcher() -> Node3D:
	var w := Node3D.new()
	add_child(w)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05)
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.8
	cap.material = dark
	var body := MeshInstance3D.new()
	body.mesh = cap
	body.position = Vector3(0, 0.9, 0)
	w.add_child(body)
	# Hi-vis vest, like yours.
	var vest := StandardMaterial3D.new()
	vest.albedo_color = Color(0.9, 0.55, 0.05)
	var vm := CylinderMesh.new()
	vm.top_radius = 0.32
	vm.bottom_radius = 0.33
	vm.height = 0.55
	vm.material = vest
	var v := MeshInstance3D.new()
	v.mesh = vm
	v.position = Vector3(0, 1.15, 0)
	w.add_child(v)
	# The camcorder, pointed down at you, REC light on.
	var cam_body := BoxMesh.new()
	cam_body.size = Vector3(0.12, 0.12, 0.25)
	cam_body.material = dark
	var cb := MeshInstance3D.new()
	cb.mesh = cam_body
	cb.position = Vector3(0.15, 1.5, -0.32)
	cb.rotation_degrees = Vector3(-55, 0, 0)
	w.add_child(cb)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.05, 0.05)
	red.emission_enabled = true
	red.emission = Color(1, 0.05, 0.05)
	red.emission_energy_multiplier = 6.0
	var rec := SphereMesh.new()
	rec.radius = 0.025
	rec.height = 0.05
	rec.material = red
	var r := MeshInstance3D.new()
	r.mesh = rec
	r.position = Vector3(0.0, 0.07, 0.0)
	cb.add_child(r)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.1, 0.1)
	lamp.light_energy = 0.6
	lamp.omni_range = 1.5
	r.add_child(lamp)
	var blink := Timer.new()
	blink.wait_time = 0.5
	blink.autostart = true
	w.add_child(blink)
	blink.timeout.connect(func(): r.visible = not r.visible)
	return w


func _direction_hint(pos: Vector3) -> String:
	var rel := pos - TRUCK_POS
	var dist := snappedf(Vector2(rel.x, rel.z).length(), 5.0)
	var side := "straight ahead"
	if rel.z > 0.0:
		side = "behind the truck"
	elif rel.x < -8.0:
		side = "to the left"
	elif rel.x > 8.0:
		side = "to the right"
	return "about %d m %s" % [int(dist), side]


## Per-frame task logic. Returns a glitch amount for the camcorder.
func _update_tasks(delta: float) -> float:
	var glitch := 0.0
	# The truck charges your flashlight while you stand by it.
	if player.global_position.distance_to(TRUCK_POS) < RECHARGE_RANGE and player.battery < 100.0:
		player.battery = minf(player.battery + 25.0 * delta, 100.0)
	if player.global_position.distance_to(TRUCK_POS) < RECHARGE_RANGE and player.water < 100.0:
		player.water = minf(player.water + PUMP_REFILL * delta, 100.0)
	glitch = maxf(glitch, _update_scares(delta))
	_update_utility(delta)
	_update_rescue(delta)
	for it in items:
		if it.kind == "leak" and it.tag == "" and not smelled.has(it):
			if player.global_position.distance_to(it.global_position) < 9.0:
				smelled[it] = true
				hud.flash("You smell gas.", 2.5)
	if doc_item != null and doc_item.tag == "" and player.recording:
		if player.ray.is_colliding() and player.ray.get_collider() == doc_chimney:
			doc_progress += delta
			if doc_progress > FLASHBACK_FROM:
				glitch = 0.35   # the tape is fighting something
			if doc_progress >= DOC_TIME:
				doc_item.apply_tag("doc")
				on_tree_updated()
				hud.flash("Chimney recorded.", 2.5)
	return glitch


## Two jump scares in Shift 4, each fires once.
##   1. Raise the camcorder after a few trees: the figure is right at the lens.
##   2. Head back toward the truck with most of the order done: the radio screams.
func _update_scares(delta: float) -> float:
	var g := 0.0
	if scare_timer > 0.0:
		scare_timer -= delta
		g = 1.0
		if scare_timer <= 0.0:
			if director.active():
				director.banish(0.6)
			else:
				figure.position = figure_spots[figure_spot] + Vector3(0, 0.975, 0)
	if not cfg.get("scares", false):
		was_recording = player.recording
		return g
	var done := 0
	for t in work_trees:
		if t.tag != "":
			done += 1
	# 1. At the lens.
	if not scare_cam_done and player.recording and not was_recording and done >= 3:
		scare_cam_done = true
		var cam: Camera3D = player.cam
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		figure.global_position = cam.global_position + fwd.normalized() * 1.3 + Vector3(0, -0.8, 0)
		figure.visible = true
		if player.flashlight_on:
			player.flashlight_on = false
			get_tree().create_timer(1.2).timeout.connect(_light_back)
		figure_seen = -10.0   # don't let the normal vanish logic move it
		audio.sting()
		scare_timer = 0.6
		get_tree().create_timer(0.7).timeout.connect(_reset_figure_seen)
	was_recording = player.recording
	# 2. The radio.
	if not scare_radio_done and done >= int(work_trees.size() * 0.6) \
			and player.global_position.distance_to(TRUCK_POS) < 16.0:
		scare_radio_done = true
		audio.sting()
		truck.alarm(2.5)
		scare_timer = 0.4
		hud.flash("[RADIO]  — static —  \"Unit seven... who's out there with you?\"", 5.0, true)
	return g


func _light_back() -> void:
	if player.battery > 0.0:
		player.flashlight_on = true


func _reset_figure_seen() -> void:
	figure_seen = 0.0


func _flashback_window() -> bool:
	return doc_item != null and doc_item.tag == "" and player.recording \
		and doc_progress > FLASHBACK_FROM and doc_progress < DOC_TIME


## Recorder hook: on capture frames during the window, the town is whole again.
func _on_capture(on: bool) -> void:
	if on and _flashback_window():
		flashback_on = true
		town.ruins.visible = false
		snags_root.visible = false
		for id in all_trees:
			all_trees[id].visible = false
		past.visible = true
		_apply_light(DAY)
	elif not on and flashback_on:
		flashback_on = false
		town.ruins.visible = true
		snags_root.visible = true
		for id in all_trees:
			all_trees[id].visible = true
		past.visible = false
		_apply_light(cfg)


func try_flag_leak(pos: Vector3) -> void:
	for it in items:
		if (it.kind == "leak" or it.kind == "remains") and it.tag == "" and pos.distance_to(it.global_position) < 3.5:
			it.flag()
			if it.kind == "leak":
				audio.spray()
			else:
				hud.flash("Marked for the coroner. Unit seven, out.", 3.5)
			on_tree_updated()
			return


func _spawn_work_tree(entry: Dictionary):
	var t = HazardTreeScript.new()
	t.tree_id = entry["id"]
	t.hint = entry["hint"]
	t.is_work_order = true
	t.height = 11.0
	t.radius = 0.38
	t.position = entry["pos"]
	add_child(t)
	all_trees[t.tree_id] = t
	return t


func _snag_near(pos: Vector3, min_d: float, max_d: float):
	var best = null
	var best_score := INF
	for s in snags:
		var d: float = s.position.distance_to(pos)
		if d < min_d or d > max_d:
			continue
		var score: float = abs(d - 8.0)
		if score < best_score:
			best_score = score
			best = s
	return best


func on_tree_updated() -> void:
	for t in work_trees:
		if t.tag != "" and not tag_order.has(t):
			tag_order.append(t)
			if t.tag == "remove" and t.get("kind") == null:
				director.provoke()
	hud.update_tablet(work_trees)


func on_recording_tree(t, from: Vector3) -> void:
	if not cfg["replay_trees"].has(t.tree_id) or replay_placed.has(t.tree_id):
		return
	replay_placed[t.tree_id] = true
	var away: Vector3 = t.global_position - from
	away.y = 0.0
	away = away.normalized()
	var side := away.cross(Vector3.UP)
	replay_figure.position = t.global_position + away * 2.2 + side * 0.6 + Vector3(0, 0.975, 0)
	replay_figure.visible = true


func truck_prompt(pos: Vector3) -> String:
	for an in animals:
		if is_instance_valid(an):
			var ap: String = an.prompt(pos)
			if ap != "":
				return ap
	if not player.spraying:
		for f in atmosphere.smolders:
			if not f.out and f.visible and pos.distance_to(f.global_position) < (6.0 if f.big else 4.0):
				return "Hold [5] to soak it with the pump" if player.water > 0.0 else "Your bag's empty. Refill at the truck."
	if doc_item != null and doc_item.tag == "" and player.recording and player.ray.is_colliding() \
			and player.ray.get_collider() == doc_chimney:
		return "Recording chimney ... %d%%" % int(min(doc_progress / DOC_TIME, 1.0) * 100.0)
	for it in items:
		if it.kind == "leak" and it.tag == "" and pos.distance_to(it.global_position) < 3.5:
			return "[4] Flag gas leak"
		if it.kind == "remains" and it.tag == "" and pos.distance_to(it.global_position) < 3.5:
			return "[4] Mark for the coroner"
	if _note_near(pos) != null:
		return "[E] Pick up the clipboard"
	var up := _utility_prompt(pos)
	if up != "":
		return up
	if hole_item != null and not ending and pos.distance_to(STUMP_HOLE_POS) < HOLE_RANGE:
		return "[E] Climb down into the stump hole"
	if pos.distance_to(TRUCK_POS) < FILE_RANGE:
		return "[E] File work order"
	return ""


func try_file_order(pos: Vector3) -> void:
	var note = _note_near(pos)
	if note != null:
		note.take()
		player.tablet_open = true
		hud.open_note(note.title, note.text)
		return
	for an in animals:
		if is_instance_valid(an) and an.interact(pos):
			return
	if knocked:
		return
	if hole_item != null and not ending and pos.distance_to(STUMP_HOLE_POS) < HOLE_RANGE:
		_run_ending()
		return
	if shift_done or pos.distance_to(TRUCK_POS) > FILE_RANGE:
		return
	var done := 0
	for t in work_trees:
		if t.is_assessed and t.tag != "":
			done += 1
	if done < work_trees.size():
		hud.flash("Work order incomplete: %d of %d trees done." % [done, work_trees.size()], 3.0)
		return
	shift_done = true
	_set_player_active(false)
	var filed := "SHIFT %d COMPLETE\n\nWork order filed. %d of %d items complete." % [shift + 1, done, work_trees.size()]
	if shift + 1 < SHIFTS.size():
		var next: int = shift + 1
		hud.show_card("%s\n\n\n%s" % [filed, SHIFTS[next]["title"]], 3.0, false, _advance_to.bind(next))
		get_tree().create_timer(5.5).timeout.connect(_resume_play)
	else:
		hud.show_card("%s\n\nEnd of prototype." % filed, 1.0, true)


func _advance_to(n: int) -> void:
	_start_shift(n)
	_reset_player()


func _resume_play() -> void:
	_set_player_active(true)
	hud.flash("%s\nPress TAB to read the work order." % cfg["title"], 6.0)


func _hide_open_figure() -> void:
	open_figure.visible = false


func _set_player_active(on: bool) -> void:
	player.set_physics_process(on)
	player.set_process(on)
	if not on and player.recording:
		player.recording = false
		player.recorder.stop_clip()
		player.cam.cull_mask = 1
		player.cam.fov = PlayerScript.NORMAL_FOV
		audio.camcorder(false)
		hud.show_camcorder(false)


func _reset_player() -> void:
	player.global_position = START_POS
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.battery = 100.0   # fresh batteries from the truck
	player.flashlight_on = false
	player.tablet_open = false
	hud.show_tablet(false)


# ---------- input ----------

func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("sprint", KEY_SHIFT)
	_add_key("flashlight", KEY_F)
	_add_key("tablet", KEY_TAB)
	_add_key("tablet_page", KEY_Q)
	_add_key("interact", KEY_E)
	_add_key("tag_remove", KEY_1)
	_add_key("tag_monitor", KEY_2)
	_add_key("tag_retain", KEY_3)
	_add_key("tag_leak", KEY_4)
	_add_key("spray", KEY_5)
	_add_mouse("camcorder", MOUSE_BUTTON_RIGHT)


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------- world ----------

func _build_environment() -> void:
	env = Environment.new()
	# A real sky, tinted per shift.
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.35
	env.tonemap_white = 6.0
	# Contact shadows in corners and under debris.
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	# Headlights, embers and the light bar bloom a little.
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	# Smoke hangs in the air; your flashlight cuts beams through it.
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_detail_spread = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	# Bounce light: the flashlight spills off walls and ground, the sun fills
	# shadows with the color of what it hits.
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.9
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.6   # soft sun shadows that sharpen at contact
	sun.directional_shadow_blend_splits = true
	_apply_quality(quality)
	add_child(sun)


func _build_ground() -> void:
	# Ash, burned dirt and patches of bare soil.
	var mat = TownScript._noise_mat(Color(0.10, 0.098, 0.095), Color(0.23, 0.205, 0.18), 0.05, Vector3(60, 60, 1), "ground_ash")
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	add_child(mi)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	add_child(body)


func _build_town() -> void:
	# Everything gameplay needs kept open: work trees, anomaly spots, the hole, the truck.
	var clear: Array = [[TRUCK_POS, 11.0], [START_POS, 4.0], [STUMP_HOLE_POS, 12.0]]
	for sh in SHIFTS:
		for entry in sh["trees"]:
			clear.append([entry["pos"], 6.0])
		clear.append([sh["phantom"], 3.0])
		for f in sh["figure_spots"]:
			clear.append([f, 3.0])
	town = TownScript.new()
	add_child(town)
	town.build(clear)


func _build_forest() -> void:
	# Keep every shift's work-order spots and phantom spots clear of snags.
	var keep_clear: Array = []
	for sh in SHIFTS:
		for entry in sh["trees"]:
			keep_clear.append(entry["pos"])
	var phantoms: Array = []
	for sh in SHIFTS:
		phantoms.append(sh["phantom"])

	snags_root = Node3D.new()
	snags_root.name = "Snags"
	add_child(snags_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1108
	var placed := 0
	var tries := 0
	while placed < 240 and tries < 6000:
		tries += 1
		var p := Vector3(rng.randf_range(-90.0, 90.0), 0.0, rng.randf_range(-90.0, 60.0))
		if p.distance_to(TRUCK_POS) < 7.0 or p.distance_to(STUMP_HOLE_POS) < 6.0:
			continue
		var clear := true
		for q in keep_clear:
			if p.distance_to(q) < 3.0:
				clear = false
				break
		for q in phantoms:
			if p.distance_to(q) < 2.5:
				clear = false
				break
		if not clear or town.blocked(p, 1.0):
			continue
		var snag = HazardTreeScript.new()
		snag.height = rng.randf_range(4.0, 14.0)
		snag.radius = rng.randf_range(0.15, 0.45)
		snag.position = p
		snag.rotation = Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(0.0, TAU), rng.randf_range(-0.06, 0.06))
		snags_root.add_child(snag)
		snags.append(snag)
		placed += 1


func _build_truck() -> void:
	truck = TruckScript.new()
	truck.position = TRUCK_POS
	add_child(truck)
	# Gravel pull-off under the truck.
	var gravel = TownScript._noise_mat(Color(0.20, 0.195, 0.19), Color(0.30, 0.29, 0.27), 0.4, Vector3(4, 4, 1), "gravel")
	_box(self, Vector3(5.0, 0.03, 10.0), TRUCK_POS + Vector3(0, 0.015, 1.5), gravel)


func _build_stump_hole() -> void:
	var before := get_child_count()
	_build_stump_hole_meshes()
	hole_root = Node3D.new()
	hole_root.name = "StumpHole"
	var made: Array = []
	for i in range(before, get_child_count()):
		made.append(get_child(i))
	add_child(hole_root)
	for n in made:
		n.reparent(hole_root)
	# The shaft below: only its inside is drawn, so you can climb down into it.
	var earth = TownScript._noise_mat(Color(0.04, 0.035, 0.03), Color(0.12, 0.10, 0.08), 0.3, Vector3(4, 3, 1), "soil", Color(0.45, 0.42, 0.4))
	earth.cull_mode = BaseMaterial3D.CULL_FRONT
	var shaft := CylinderMesh.new()
	shaft.top_radius = 2.7
	shaft.bottom_radius = 2.2
	shaft.height = 8.0
	shaft.cap_top = false
	shaft.radial_segments = 24
	shaft.material = earth
	var sm := MeshInstance3D.new()
	sm.mesh = shaft
	sm.position = STUMP_HOLE_POS + Vector3(0, -4.0, 0)
	hole_root.add_child(sm)


func _build_stump_hole_meshes() -> void:
	# Where a big tree's stump burned out underground: a dark throat ringed by
	# a heaved-up rim of ash and dirt, with burned roots arching down into it.
	var c := STUMP_HOLE_POS
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0, 0, 0)
	black.roughness = 1.0
	black.disable_fog = true   # a true void, even through the haze
	var ash = TownScript._noise_mat(Color(0.08, 0.075, 0.07), Color(0.22, 0.19, 0.16), 0.3, Vector3(3, 3, 1), "ground_ash")
	var root_mat = TownScript._noise_mat(Color(0.02, 0.02, 0.02), Color(0.10, 0.09, 0.08), 0.35, Vector3(1, 4, 1), "burnt_bark", Color(0.7, 0.7, 0.7))

	hole_cover.append(_disc(c + Vector3(0, 0.008, 0), 6.0, ash))
	var rim := TorusMesh.new()
	rim.inner_radius = 2.5
	rim.outer_radius = 3.9
	rim.rings = 24
	rim.ring_segments = 10
	rim.material = ash
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.position = c + Vector3(0, 0.05, 0)
	rim_mi.scale = Vector3(1, 0.75, 1)
	add_child(rim_mi)
	hole_cover.append(_disc(c + Vector3(0, 0.04, 0), 2.7, black))

	var rng := RandomNumberGenerator.new()
	rng.seed = 40
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		var start := c + out * rng.randf_range(4.5, 6.5) + Vector3(0, 0.05, 0)
		var crest := c + out * rng.randf_range(2.8, 3.3) + Vector3(0, rng.randf_range(0.35, 0.6), 0)
		var sink := c + out * rng.randf_range(0.6, 1.6) + Vector3(0, -0.4, 0)
		var r := rng.randf_range(0.05, 0.13)
		_taper(start, crest, r * 0.7, r, root_mat)
		_taper(crest, sink, r, r * 0.4, root_mat)


func _disc(pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.01
	m.radial_segments = 32
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	add_child(mi)
	return mi


func _taper(a: Vector3, b: Vector3, ra: float, rb: float, mat: Material) -> void:
	var d := b - a
	var seg := d.length()
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
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	add_child(mi)


func _build_anomalies() -> void:
	# The thing that hunts you: a burned snag, visible only through the camcorder.
	figure = StalkerTreeScript.new()
	figure.layer_mask = 2
	add_child(figure)

	# Something behind the trunk: only ever captured on tape (render layer 3).
	replay_figure = StalkerTreeScript.new()
	replay_figure.layer_mask = 4
	replay_figure.visible = false
	add_child(replay_figure)

	# The same thing standing in the open: tape only, from Shift 2.
	open_figure = StalkerTreeScript.new()
	open_figure.layer_mask = 4
	open_figure.visible = false
	add_child(open_figure)

	# A tree that is not on the map: also camcorder-only, no collision.
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.06, 0.05, 0.05)
	TownScript.SurfacesScript.apply(bark, "burnt_bark", Color(0.6, 0.6, 0.6), false)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.42
	trunk.height = 10.0
	trunk.radial_segments = 7
	trunk.material = bark
	phantom_tree = MeshInstance3D.new()
	phantom_tree.mesh = trunk
	phantom_tree.layers = 2
	add_child(phantom_tree)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)



# ---------- fires and survivors ----------

## What else they found at the truck.
func _survivor_line() -> String:
	var found: Array = []
	if dog_saved:
		found.append("a dog tied to the truck with flagging tape, tag reads BISCUIT, alive")
	if dog2_saved:
		found.append("an old gray dog beside it, tag reads MAGGIE, alive")
	if cat_saved:
		found.append("a cat asleep on a folded jacket on the hood, alive")
	var s := ""
	if not found.is_empty():
		s = "\n\nAlso recovered at the vehicle:\n" + "\n".join(found) + "."
	if watered_count > 0:
		s += "\nThe operator's water bag was empty. Animal tracks led away from the truck in %d directions." % watered_count
	return s


func _spawn_survivors() -> void:
	# Whoever wasn't helped last shift is gone now.
	for an in animals:
		if is_instance_valid(an) and an.state != "home":
			an.queue_free()
	animals = animals.filter(func(a): return is_instance_valid(a) and a.state == "home")
	if blaze != null and not blaze.out:
		blaze.extinguish_now()   # the engine crew got it overnight
	for f in atmosphere.smolders:
		f.player = player
	match shift:
		0:
			_spawn_dog()
			_spawn_water_animal("rabbit", Vector3(-22, 0, -30))
			_spawn_wildlife("rabbit", 3)
			_spawn_wildlife("squirrel", 3)
		1:
			_spawn_cat()
			_spawn_blaze()
			_spawn_dog2()
			_spawn_wildlife("rabbit", 3)
			_spawn_wildlife("squirrel", 3)
		2:
			_spawn_fawn()
			_spawn_water_animal("skunk", Vector3(26, 0, -70))
			_spawn_wildlife("rabbit", 2)
			_spawn_wildlife("squirrel", 2)
		3:
			if not dog_saved and dog_spot != Vector3.ZERO:
				_place_lure()
			_spawn_water_animal("skunk", Vector3(-12, 0, -18))
			_spawn_wildlife("rabbit", 3)   # eyes in the dark
		4:
			pass   # nothing moves out here anymore


## Somewhere in the open, clear of ruins, near `near`.
func _open_spot(near: Vector3, spread := 10.0) -> Vector3:
	var p := near
	for i in 60:
		if not town.blocked(p, 1.5) and p.distance_to(TRUCK_POS) > 10.0:
			return p
		p = near + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
	return p


func _spawn_water_animal(kind: String, near: Vector3) -> Node3D:
	var a := _new_animal(kind)
	a.global_position = _open_spot(near)
	a.rotation.y = randf() * TAU
	return a


func _spawn_wildlife(kind: String, n: int) -> void:
	for i in n:
		var a := _new_animal(kind, true)
		var p := Vector3(randf_range(-45, 45), 0, randf_range(-100, 0))
		if kind == "squirrel" and not snags.is_empty():
			var sn = snags.pick_random()
			p = sn.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		a.global_position = _open_spot(p, 6.0)
		a.rotation.y = randf() * TAU


func _spawn_dog2() -> void:
	# An older dog hiding under a manufactured home's chassis.
	var a := _new_animal("dog2")
	a.pet_name = "MAGGIE"
	var best: Node3D = null
	var bd := INF
	for info in town.mobile_lots:
		var lot: Node3D = info["lot"]
		var d: float = lot.global_position.distance_to(Vector3(20, 0, -50))
		if d < bd:
			bd = d
			best = lot
	var p := Vector3(24, 0, -48)
	if best != null:
		p = best.to_global(Vector3(0, 0, 2.2))
	p.y = 0.0
	a.global_position = p
	for info in town.mobile_lots:
		var lp: Vector3 = (info["lot"] as Node3D).global_position
		if lp.distance_to(p) < 50.0:
			a.hide_spots.append(lp * Vector3(1, 0, 1))
	for c in town.car_nodes:
		var cp: Vector3 = (c as Node3D).global_position
		if cp.distance_to(p) < 45.0:
			a.hide_spots.append(cp + (c as Node3D).global_basis.z.normalized() * 1.5 * Vector3(1, 0, 1))


func _parcel_house_lots() -> Array:
	var lots: Array = []
	for info in town.house_lots:
		var p: Vector3 = info["lot"].global_position
		if abs(p.x) < 42.0 and p.z < 6.0 and p.z > -100.0 and not info.get("used", false) and info["chimney"] != doc_chimney:
			lots.append(info)
	return lots


func _new_animal(kind: String, wild := false) -> Node3D:
	var a = AnimalScript.new()
	a.kind = kind
	a.wild = wild
	a.player = player
	a.main = self
	add_child(a)
	a.build()
	a.saved.connect(_on_animal_saved)
	a.sprayed.connect(_on_skunked)
	animals.append(a)
	return a


func _spawn_dog() -> void:
	# Hiding beside a burned car, nearest the middle of the parcel.
	var best: Node3D = null
	var bd := INF
	for c in town.car_nodes:
		var d: float = (c as Node3D).global_position.distance_to(Vector3(0, 0, -28))
		if d < bd:
			bd = d
			best = c
	var a := _new_animal("dog")
	a.pet_name = "BISCUIT"
	if best != null:
		dog_spot = best.global_position + best.global_basis.z.normalized() * 1.5
	else:
		dog_spot = Vector3(10, 0, -24)
	dog_spot.y = 0.0
	a.global_position = dog_spot
	for c in town.car_nodes:
		var cp: Vector3 = (c as Node3D).global_position
		if cp.distance_to(dog_spot) < 45.0:
			a.hide_spots.append(cp + (c as Node3D).global_basis.z.normalized() * 1.5 * Vector3(1, 0, 1))
	for info in town.house_lots:
		var ch: Node3D = info["chimney"]
		if ch.global_position.distance_to(dog_spot) < 45.0:
			a.hide_spots.append(ch.to_global(Vector3(1.4, 0, 0.6)) * Vector3(1, 0, 1))
	dog = a


func _spawn_cat() -> void:
	var lots := _parcel_house_lots()
	lots.sort_custom(func(x, y): return x["lot"].global_position.distance_to(Vector3(12, 0, -36)) < y["lot"].global_position.distance_to(Vector3(12, 0, -36)))
	for info in lots:
		if info["kind"] != "house":
			continue
		var ch: Node3D = info["chimney"]
		var a := _new_animal("cat")
		a.global_position = ch.to_global(Vector3(0.1, 0.22, 0.8))   # huddled on the hearth
		a.rotation.y = ch.global_rotation.y - PI * 0.5
		info["used"] = true
		return


func _spawn_blaze() -> void:
	var lots := _parcel_house_lots()
	lots.sort_custom(func(x, y): return x["lot"].global_position.distance_to(Vector3(-14, 0, -44)) < y["lot"].global_position.distance_to(Vector3(-14, 0, -44)))
	if lots.is_empty():
		return
	var info = lots[0]
	info["used"] = true
	var lot: Node3D = info["lot"]
	blaze = atmosphere.add_fire(lot.to_global(Vector3(1.5, 0.33, 1.0)), true)
	blaze.extinguished.connect(_on_fire_out)
	blaze_item = TaskItemScript.new()
	blaze_item.kind = "fire"
	blaze_item.tree_id = "FIRE-1"
	blaze_item.hint = "Rekindle in a debris pile. Knock it down: hold 5 to spray."
	blaze_item.fire = blaze
	add_child(blaze_item)
	blaze_item.global_position = blaze.global_position
	items.append(blaze_item)
	work_trees.append(blaze_item)


func _spawn_fawn() -> void:
	var p := _open_spot(Vector3(18, 0, -34))
	var a := _new_animal("fawn")
	a.global_position = p
	# Its mother, watching from what's left of the tree line. She won't let you close.
	var doe := _new_animal("doe", true)
	doe.global_position = _open_spot(p + Vector3(22, 0, -18), 5.0)
	doe.state = "watching"
	a.leave_target = doe


func _on_animal_saved(a) -> void:
	match a.kind:
		"dog":
			dog_saved = true
		"dog2":
			dog2_saved = true
		"cat":
			cat_saved = true
		"fawn":
			fawn_helped = true
			watered_count += 1
		_:
			watered_count += 1


## The skunk got you. Eyes water, the world goes yellow-green for a while.
func _on_skunked(_a) -> void:
	hud.skunk(25.0)
	hud.flash("It turns, tail up, and lets you have it. Your eyes burn. Everything smells like burnt rubber and garlic.", 5.0, true)


func _on_fire_out(f) -> void:
	fires_out += 1
	if f == blaze and blaze_item != null and blaze_item.tag == "":
		blaze_item.is_assessed = true
		blaze_item.tag = "out"
		on_tree_updated()
		hud.flash("It's out. Steam, and the stink of wet ash.", 3.0)
	elif not f.big:
		hud.flash("Out.", 1.2)


## Called by the director when the thing comes back.
func on_stalker_spawn() -> void:
	if (dog_saved or dog2_saved) and player.global_position.distance_to(TRUCK_POS) < 70.0:
		hud.flash("[Back at the truck, the dog is growling. Not at you. At something behind you.]", 4.0, true)
		var g = audio.get_stream("dog_growl")
		if g != null:
			audio.play_at(g, TRUCK_POS + Vector3(0, 1, 2))


func _place_lure() -> void:
	# The dog you left. Or something that learned how it sounded.
	lure = Node3D.new()
	add_child(lure)
	lure.global_position = dog_spot
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.07
	tor.outer_radius = 0.09
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.55, 0.08, 0.06)
	tor.material = red
	ring.mesh = tor
	ring.position = Vector3(0, 0.02, 0)
	lure.add_child(ring)
	var tag := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.025
	tm.bottom_radius = 0.025
	tm.height = 0.004
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.75, 0.6, 0.3)
	brass.metallic = 0.8
	brass.roughness = 0.3
	tm.material = brass
	tag.mesh = tm
	tag.position = Vector3(0.1, 0.01, 0)
	lure.add_child(tag)
	lure_t = 0.0
	lure_called = false
	lure_sprung = false


func _update_rescue(delta: float) -> void:
	# Water on fire.
	if player.spraying:
		var cam: Camera3D = player.cam
		var fwd := -cam.global_transform.basis.z
		var eye := cam.global_position
		for f in atmosphere.smolders:
			if f.out or not f.visible:
				continue
			var to: Vector3 = f.global_position + Vector3(0, 0.4, 0) - eye
			var d := to.length()
			var flat := Vector2(to.x, to.z).length()
			if flat > player.SPRAY_RANGE + (1.0 if f.big else 0.0):
				continue
			# The stream arcs, so judge aim side to side and forgive the height.
			var side := Vector2(fwd.x, fwd.z).normalized().angle_to(Vector2(to.x, to.z).normalized())
			if absf(side) < deg_to_rad(16.0 if f.big else 12.0) or d < 1.6:
				f.douse(delta * (0.17 if f.big else 0.6))
		for an in animals:
			if not is_instance_valid(an) or an.state in ["gone", "home", "carried"]:
				continue
			var ta: Vector3 = an.global_position + Vector3(0, 0.2, 0) - eye
			if Vector2(ta.x, ta.z).length() < player.SPRAY_RANGE:
				var sa := Vector2(fwd.x, fwd.z).normalized().angle_to(Vector2(ta.x, ta.z).normalized())
				if absf(sa) < deg_to_rad(10.0):
					an.hosed()
	# Too close to the rekindle.
	too_hot_t -= delta
	if blaze != null and not blaze.out and blaze.heat > 0.35:
		var bd: float = Vector2(player.global_position.x - blaze.global_position.x, player.global_position.z - blaze.global_position.z).length()
		if bd < 1.3:
			var push: Vector3 = (player.global_position - blaze.global_position) * Vector3(1, 0, 1)
			player.global_position += push.normalized() * delta * 2.5
			if too_hot_t <= 0.0:
				too_hot_t = 3.0
				hud.flash("Too hot. Back off and hit it from range.", 2.0)
	# Survivors that make it to the truck.
	for an in animals:
		if not is_instance_valid(an):
			continue
		if (an.state == "following" or an.state == "carried") and player.global_position.distance_to(TRUCK_POS) < RECHARGE_RANGE:
			if an.is_dog():
				var spot := Vector3(-1.55, 0.0, 2.4) if homed_dogs == 0 else Vector3(1.55, 0.0, 2.4)
				homed_dogs += 1
				an.go_home(truck, spot)
				hud.flash("You clip a length of flagging tape to its collar and tie it off at the truck. It lies down against the tire. The tag says %s." % an.pet_name, 5.0)
			elif an.kind == "cat":
				var blanket := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.5, 0.08, 0.45)
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.25, 0.3, 0.22)
				bm.material = bmat
				blanket.mesh = bm
				blanket.position = Vector3(0.35, 1.64, -2.65)
				truck.add_child(blanket)
				an.go_home(truck, Vector3(0.35, 1.68, -2.65))
				hud.flash("You fold your jacket on the warm hood and set the cat on it. It curls up and doesn't move.", 4.5)
	# Shift 4: a dog whimpering out in the dark, where you left it.
	if lure != null and not lure_sprung:
		lure_t += delta
		if not lure_called and lure_t > 35.0:
			lure_called = true
			hud.flash("[Somewhere out past the slabs, a dog is whimpering.]", 4.0, true)
			var w = audio.get_stream("dog_whimper")
			if w != null:
				audio.play_at(w, lure.global_position + Vector3(0, 0.4, 0))
		if lure_called and player.global_position.distance_to(lure.global_position) < 3.0:
			lure_sprung = true
			hud.flash("Just a collar. BISCUIT. The ash around it is pressed flat in a wide ring, like something heavy stood here a long time.", 5.0, true)
			if director.active() and not director.stalking:
				director.cooldown = 0.0
