extends Node
## Camcorder tape recorder. While the camcorder is up, grabs small frames of
## the screen at a low frame rate and keeps the most recent clips as "tapes".
##
## Each capture frame briefly adds render layer 3 (cull bit value 4) to the
## camera, so replay-only things appear on tape and flash for a single frame live.

const REPLAY_LAYER_BIT := 4
const FRAME_SIZE := Vector2i(256, 144)
const MAX_SECONDS := 15.0
const MAX_CLIPS := 6
const MIN_FRAMES := 4

var fps := 8.0
var cam: Camera3D
var clips: Array = []   # newest first: {"label", "frames", "trees"}
var current = null
var timer := 0.0
var pending := false
var tape_count := 0
## Called with true just before a capture frame renders and false right after.
var capture_hook: Callable


func start_clip() -> void:
	tape_count += 1
	current = {"label": "TAPE %02d" % tape_count, "frames": [], "trees": []}
	timer = 0.0
	pending = false


## Ends the clip. Returns true if it was long enough to keep.
func stop_clip() -> bool:
	if current == null:
		return false
	if pending:
		cam.cull_mask &= ~REPLAY_LAYER_BIT
		pending = false
		_hook(false)
	var kept := false
	if current["frames"].size() >= MIN_FRAMES:
		clips.push_front(current)
		if clips.size() > MAX_CLIPS:
			clips.pop_back()
		kept = true
	else:
		tape_count -= 1
	current = null
	return kept


func note_tree(id: String) -> void:
	if current != null and not current["trees"].has(id):
		current["trees"].append(id)


func tick(delta: float) -> void:
	if current == null:
		return
	var frames: Array = current["frames"]
	if pending:
		# The viewport texture now holds the frame rendered with the replay layer on.
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_BILINEAR)
		frames.append(ImageTexture.create_from_image(img))
		cam.cull_mask &= ~REPLAY_LAYER_BIT
		pending = false
		_hook(false)
	if frames.size() >= int(fps * MAX_SECONDS):
		return
	timer -= delta
	if timer <= 0.0:
		timer += 1.0 / fps
		cam.cull_mask |= REPLAY_LAYER_BIT
		pending = true
		_hook(true)


func _hook(on: bool) -> void:
	if capture_hook.is_valid():
		capture_hook.call(on)


func clip_length(clip: Dictionary) -> float:
	return clip["frames"].size() / fps
