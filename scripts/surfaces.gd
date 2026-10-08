extends RefCounted
## Real photo-scanned surfaces, when you have them.
##
## Drop a downloaded texture set into  res://textures/<set name>/  (one folder
## per set, files exactly as they come out of the ambientCG or Poly Haven zip).
## The game finds the color, normal, roughness and AO maps by their names.
## A set that isn't there falls back to the procedural look, so the game always
## runs, and each folder you add upgrades that surface the next time you play.

const ROOT := "res://textures/"

## How many meters one tile of each set covers in the world.
const TILE := {
	"ground_ash": 4.0,
	"soil": 3.0,
	"gravel": 2.0,
	"asphalt": 4.0,
	"concrete": 3.0,
	"brick": 2.0,
	"charred_wood": 1.5,
	"burnt_bark": 1.6,
	"bark": 1.6,
	"rust": 2.0,
	"metal": 2.0,
	"rock": 2.0,
	"grass": 3.0,
	"roof": 3.0,
}

const EXTS := ["jpg", "jpeg", "png", "webp", "tga", "bmp"]

static var _sets := {}      # set name -> {albedo, normal, roughness, ao, arm} textures (or {} if missing)
static var _reported := false


## Apply the set to `m` if it's installed. Returns true when it was.
static func apply(m: StandardMaterial3D, set_name: String, tint := Color.WHITE, world := true) -> bool:
	var s := _load(set_name)
	if s.is_empty():
		return false
	m.albedo_texture = s["albedo"]
	m.albedo_color = tint
	var tile: float = TILE.get(set_name, 2.0)
	m.uv1_scale = Vector3.ONE / tile
	m.uv1_offset = Vector3.ZERO
	# Box and cylinder UVs stretch; projecting from three sides keeps every
	# surface at true scale. World space so two identical walls don't match.
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if s.has("normal"):
		m.normal_enabled = true
		m.normal_texture = s["normal"]
		m.normal_scale = 1.0
	else:
		m.normal_enabled = false
		m.normal_texture = null
	m.roughness = 1.0
	if s.has("roughness"):
		m.roughness_texture = s["roughness"]
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif s.has("arm"):
		m.roughness_texture = s["arm"]
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	if s.has("ao"):
		m.ao_enabled = true
		m.ao_texture = s["ao"]
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.6
	elif s.has("arm"):
		m.ao_enabled = true
		m.ao_texture = s["arm"]
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.6
	return true


static func has_set(set_name: String) -> bool:
	return not _load(set_name).is_empty()


## Print once which sets were found, like the audio report.
static func report() -> void:
	if _reported:
		return
	_reported = true
	var found: Array = []
	var missing: Array = []
	for k in TILE.keys():
		if has_set(k):
			found.append(k)
		else:
			missing.append(k)
	print("Textures: %d of %d sets loaded. Missing (procedural fallback): %s" % [found.size(), TILE.size(), ", ".join(missing) if missing.size() > 0 else "none"])


static func _load(set_name: String) -> Dictionary:
	if _sets.has(set_name):
		return _sets[set_name]
	var out := {}
	var files := _list(ROOT + set_name)
	var picks := {}   # slot -> [score, path]
	for f in files:
		var slot_score := _classify(f)
		if slot_score.is_empty():
			continue
		var slot: String = slot_score[0]
		var score: int = slot_score[1]
		if not picks.has(slot) or score > picks[slot][0]:
			picks[slot] = [score, ROOT + set_name + "/" + f]
	if picks.has("albedo"):
		for slot in picks.keys():
			var tex := _tex(picks[slot][1])
			if tex != null:
				out[slot] = tex
		if not out.has("albedo"):
			out = {}
	_sets[set_name] = out
	return out


## Folder listing that also works in an exported game, where only the
## .import stubs remain next to the original names.
static func _list(dir_path: String) -> Array:
	var names: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return names
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir():
			if f.ends_with(".import"):
				f = f.trim_suffix(".import")
			if f.get_extension().to_lower() in EXTS and not names.has(f):
				names.append(f)
		f = d.get_next()
	d.list_dir_end()
	return names


## Works out which map a file is from its name. Higher score wins when a set
## has more than one candidate (OpenGL normals over DirectX ones, for example).
static func _classify(file: String) -> Array:
	# Read the name from the end, since the set's own name can contain words
	# like "rough" (rough_concrete_diff_2k). Skip size and format tokens.
	var n := file.get_basename().to_lower().replace("-", "_").replace(" ", "_").replace(".", "_")
	var toks := n.split("_", false)
	var i := toks.size() - 1
	while i >= 0:
		var t: String = toks[i]
		var prev: String = toks[i - 1] if i > 0 else ""
		if t in ["1k", "2k", "4k", "8k", "jpg", "png", "jpeg", "webp", "tga"] or t.is_valid_int():
			i -= 1
			continue
		if t in ["preview", "displacement", "disp", "height", "metalness", "metallic", "metal", "opacity", "mask", "bump", "spec", "specular", "idmask", "emission"]:
			return []
		if t == "gl" and prev in ["nor", "normal", "nrm"]:
			return ["normal", 3]
		if t == "dx" and prev in ["nor", "normal", "nrm"]:
			return ["normal", 1]
		if t in ["normalgl", "normal_gl"]:
			return ["normal", 3]
		if t in ["normaldx"]:
			return ["normal", 1]
		if t in ["normal", "nor", "nrm", "n"]:
			return ["normal", 2]
		if t in ["roughness", "rough", "rgh"]:
			return ["roughness", 2]
		if t in ["ambientocclusion", "ao", "occlusion"]:
			return ["ao", 2]
		if t == "arm":
			return ["arm", 2]
		if t in ["color", "albedo", "basecolor", "diff", "diffuse", "col", "colour", "basecolour"]:
			return ["albedo", 2]
		return []
	return []


static func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var t = load(path)
	if not (t is Texture2D):
		return null
	var tex: Texture2D = t
	# If the editor imported it without mipmaps, far ground shimmers. Build them.
	var img := tex.get_image()
	if img != null and not img.has_mipmaps() and not img.is_compressed():
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	return tex
