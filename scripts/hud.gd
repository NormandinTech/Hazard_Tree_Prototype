extends CanvasLayer
## On-screen layer: camcorder overlay, prompts, flashlight battery,
## the tablet work order, and the end-of-shift card.

const VHS_SHADER = preload("res://shaders/vhs.gdshader")

var cam_overlay: Control
var vhs_mat: ShaderMaterial
var rec_label: Label
var time_label: Label
var crosshair: Label
var prompt: Label
var message: Label
var battery_label: Label
var water_label: Label
var skunk_rect: ColorRect
var skunk_t := 0.0
var skunk_len := 1.0
var tablet: PanelContainer
var tab_header: Label
var order_text: RichTextLabel
var tapes_box: HBoxContainer
var tape_list: RichTextLabel
var tape_view: TextureRect
var tape_time: Label
var recorder
var page := 0   # 0 = work order, 1 = tapes
var tape_sel := 0
var playing := false
var play_t := 0.0
var complete: ColorRect
var complete_label: Label
var message_time := 0.0
var player   # for live GPS on the tablet
var last_items: Array = []
var notes: Array = []        # [{title, text}] found so far
var note_sel := 0
var notes_box: HBoxContainer
var notes_list: RichTextLabel
var note_text: RichTextLabel
var ghost_t := 0.0
var intro_cards: Array = []
var intro_i := -1
var intro_done: Callable
var intro_on := false
var intro_t := 0.0
var intro_hint: Label
var intro_tw: Tween
var gps_timer := 0.0
var order_title := "WORK ORDER 0417 — PARCEL 7B"
var order_sub := "Shift 1 · Morning · Hazard-tree assessment"


func _ready() -> void:
	# Camcorder overlay sits underneath the text so prompts stay readable.
	cam_overlay = Control.new()
	cam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cam_overlay)
	cam_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_overlay.visible = false

	var vhs := ColorRect.new()
	vhs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = VHS_SHADER
	vhs.material = vhs_mat
	cam_overlay.add_child(vhs)
	vhs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	rec_label = _label(cam_overlay, "● REC", 26, Color(0.95, 0.15, 0.10))
	rec_label.position = Vector2(48, 36)

	time_label = _label(cam_overlay, "00:00:00", 26, Color(0.95, 0.95, 0.90))
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	time_label.offset_left = -260.0
	time_label.offset_right = -48.0
	time_label.offset_top = 36.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var sp := _label(cam_overlay, "SP   PARCEL 7B", 20, Color(0.95, 0.95, 0.90))
	sp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	sp.offset_left = 48.0
	sp.offset_top = -64.0

	crosshair = _label(self, "+", 22, Color(1, 1, 1, 0.55))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -20.0
	crosshair.offset_right = 20.0
	crosshair.offset_top = -16.0
	crosshair.offset_bottom = 16.0
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	prompt = _label(self, "", 22, Color(0.95, 0.95, 0.92))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -560.0
	prompt.offset_right = 560.0
	prompt.offset_top = -130.0
	prompt.offset_bottom = -90.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	message = _label(self, "", 26, Color(0.95, 0.95, 0.92))
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message.offset_left = -560.0
	message.offset_right = 560.0
	message.offset_top = 90.0
	message.offset_bottom = 180.0
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	battery_label = _label(self, "LIGHT 100%", 18, Color(0.85, 0.85, 0.80))
	battery_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	battery_label.offset_left = -220.0
	battery_label.offset_right = -32.0
	battery_label.offset_top = -48.0
	battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	skunk_rect = ColorRect.new()
	skunk_rect.color = Color(0.55, 0.6, 0.12, 0.0)
	skunk_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skunk_rect)
	skunk_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	water_label = _label(self, "WATER 100%", 18, Color(0.7, 0.82, 0.9))
	water_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	water_label.offset_left = -220.0
	water_label.offset_right = -32.0
	water_label.offset_top = -76.0
	water_label.offset_bottom = -50.0
	water_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_tablet()
	_build_complete()


func _process(delta: float) -> void:
	if skunk_t > 0.0:
		skunk_t -= delta
		var k := clampf(skunk_t / skunk_len, 0.0, 1.0)
		skunk_rect.color.a = 0.32 * k * (0.85 + 0.15 * sin(Time.get_ticks_msec() / 300.0))
	elif skunk_rect.color.a > 0.0:
		skunk_rect.color.a = 0.0
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message.text = ""
	if cam_overlay.visible:
		rec_label.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	if intro_on:
		_intro_tick(delta)
	if ghost_t > 0.0:
		ghost_t -= delta
	if tablet.visible:
		_tablet_input(delta)
		gps_timer -= delta
		if page == 0 and gps_timer <= 0.0:
			gps_timer = 0.25
			update_tablet(last_items)


# ---------- called by player / main ----------

func set_prompt(text: String) -> void:
	prompt.text = text


var message_locked := false


## Priority messages (radio) can't be overwritten by routine ones until they expire.
func flash(text: String, seconds: float, priority := false) -> void:
	if message_locked and message_time > 0.0 and not priority:
		return
	message_locked = priority
	message.text = text
	message_time = seconds


func skunk(seconds: float) -> void:
	skunk_t = seconds
	skunk_len = seconds


func set_water(pct: float) -> void:
	water_label.text = "WATER %d%%" % int(ceil(pct))
	water_label.modulate = Color(1, 0.4, 0.3) if pct < 15.0 else Color(1, 1, 1)


func set_battery(pct: float) -> void:
	battery_label.text = "LIGHT %d%%" % int(ceil(pct))
	battery_label.modulate = Color(1, 0.4, 0.3) if pct < 15.0 else Color(1, 1, 1)


func show_camcorder(on: bool) -> void:
	cam_overlay.visible = on
	crosshair.visible = not on


func set_rec_time(t: float) -> void:
	var total := int(t)
	time_label.text = "%02d:%02d:%02d" % [floori(total / 3600.0), floori(total / 60.0) % 60, total % 60]


func set_glitch(amount: float) -> void:
	vhs_mat.set_shader_parameter("glitch", amount)


func show_tablet(on: bool) -> void:
	tablet.visible = on
	playing = false
	if on:
		if recorder != null:
			tape_sel = clampi(tape_sel, 0, maxi(recorder.clips.size() - 1, 0))
		play_t = 0.0
		_refresh_page()


## Distance and clock direction from where the player is facing.
func _gps(pos: Vector3) -> String:
	if player == null:
		return ""
	var to: Vector3 = pos - player.global_position
	to.y = 0.0
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	var ang := fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP)
	var clock := posmod(int(round(-ang / (TAU / 12.0))), 12)
	if clock == 0:
		clock = 12
	return "   [color=#9fd0ff]%d m · %d o'clock[/color]" % [int(to.length()), clock]


func update_tablet(trees: Array) -> void:
	last_items = trees
	var s := "[b]%s[/b]\n" % order_title
	s += "[color=#999999]%s[/color]\n\n" % order_sub
	var done := 0
	if ghost_t > 0.0:
		s += "[b][color=#d04040]HT-000[/color][/b]  [color=#d04040]NOT ASSESSED[/color]   [color=#9fd0ff]2 m · 6 o'clock[/color]   [color=#8a8a8a]Behind you.[/color]\n"
	for t in trees:
		var status := "[color=#888888]NOT ASSESSED[/color]"
		var kind = t.get("kind")
		if kind == "leak" and t.tag == "":
			status = "[color=#d08040]NOT FLAGGED[/color]"
		elif kind == "doc" and t.tag == "":
			status = "[color=#888888]NOT RECORDED[/color]"
		elif kind == "remains" and t.tag == "":
			status = "[color=#d07090]NOT LOCATED[/color]"
		elif kind == "fire" and t.tag == "":
			status = "[color=#ff7040]BURNING[/color]"
		if t.tag == "out":
			status = "[color=#66cc66]PUT OUT[/color]"
			done += 1
		elif t.tag == "gas":
			status = "[color=#66cc66]FLAGGED · GAS LEAK[/color]"
			done += 1
		elif t.tag == "marked":
			status = "[color=#66cc66]MARKED FOR CORONER[/color]"
			done += 1
		elif t.tag == "recorded":
			status = "[color=#66cc66]RECORDED[/color]"
			done += 1
		elif t.tag != "" and (kind == "pole" or kind == "xfmr"):
			status = "[color=#66cc66]RATED %s[/color]" % t.tag.to_upper()
			done += 1
		elif t.tag != "":
			status = "[color=#66cc66]TAGGED %s[/color]" % t.tag.to_upper()
			done += 1
		elif t.is_assessed and (kind == "pole" or kind == "xfmr"):
			status = "[color=#e0c040]RECORDED · NEEDS RATING[/color]"
		elif t.is_assessed and kind == null:
			status = "[color=#e0c040]RECORDED · NEEDS TAG[/color]"
		var gps := "" if t.tag != "" else _gps(t.global_position)
		# One line per item, so long work orders still fit.
		s += "[b]%s[/b]  %s%s   [color=#8a8a8a]%s[/color]\n" % [t.tree_id, status, gps, t.hint]
	s += "\nCompleted %d of %d. File the order at the truck when done.\n\n" % [done, trees.size()]
	s += "[color=#888888]Hold RMB record · 1/2/3 tag · 4 flag / mark · 5 pump · F flashlight · E file · Q tapes · TAB close[/color]"
	order_text.text = s


## Fades a full-screen black card in, holds, and (unless final) fades it out.
## `mid` runs while the screen is fully black, so the world can change unseen.
# ---------- the opening ----------

## Typed cards on black before the first shift. Space / E finishes the line,
## then moves on; each card also moves on by itself after a while.
func play_intro(cards: Array, done: Callable) -> void:
	intro_cards = cards
	intro_i = -1
	intro_done = done
	intro_on = true
	complete.color = Color(0, 0, 0, 1)
	complete.modulate.a = 1.0
	complete.visible = true
	cam_overlay.visible = false
	complete_label.add_theme_font_size_override("font_size", 26)
	complete_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	complete_label.offset_left = 220.0
	complete_label.offset_right = -220.0
	complete_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.74))
	if intro_hint == null:
		intro_hint = _label(complete, "SPACE to continue", 15, Color(0.45, 0.45, 0.42))
		intro_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		intro_hint.offset_top = -60.0
		intro_hint.offset_left = -200.0
		intro_hint.offset_right = 200.0
		intro_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_hint.visible = true
	_next_card()


func skip_intro() -> void:
	if intro_on:
		intro_i = intro_cards.size()
		_next_card()


func _intro_tick(delta: float) -> void:
	intro_t += delta
	var text: String = intro_cards[intro_i]
	var typed := complete_label.visible_ratio >= 1.0
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		if not typed:
			if intro_tw != null:
				intro_tw.kill()
			complete_label.visible_ratio = 1.0
		else:
			_next_card()
		return
	if typed and intro_t > text.length() / 32.0 + 4.5:
		_next_card()


func _next_card() -> void:
	intro_i += 1
	intro_t = 0.0
	if intro_i >= intro_cards.size():
		intro_on = false
		intro_hint.visible = false
		complete_label.remove_theme_font_size_override("font_size")
		complete_label.add_theme_font_size_override("font_size", 28)
		complete_label.text = ""
		var tw := create_tween()
		tw.tween_property(complete, "modulate:a", 0.0, 2.0)
		tw.tween_callback(_intro_finished)
		if intro_done.is_valid():
			intro_done.call()
		return
	var text: String = intro_cards[intro_i]
	complete_label.text = text
	complete_label.visible_ratio = 0.0
	intro_tw = create_tween()
	intro_tw.tween_property(complete_label, "visible_ratio", 1.0, text.length() / 32.0)


func _intro_finished() -> void:
	complete.visible = false
	complete.color = Color(0, 0, 0, 0.92)


## Hard cut to black with text (no fade), for the very end of the tape.
func cut_to_card(text: String) -> void:
	complete_label.text = text
	complete.modulate.a = 1.0
	complete.color = Color(0, 0, 0, 1)
	complete.visible = true
	cam_overlay.visible = false
	tablet.visible = false
	prompt.text = ""
	message.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_card(text: String, hold: float, final: bool, mid: Callable = Callable()) -> void:
	complete_label.text = text
	complete.modulate.a = 0.0
	complete.visible = true
	cam_overlay.visible = false
	tablet.visible = false
	prompt.text = ""
	var tw := create_tween()
	tw.tween_property(complete, "modulate:a", 1.0, 1.2)
	if mid.is_valid():
		tw.tween_callback(mid)
	tw.tween_interval(hold)
	if final:
		tw.tween_callback(_release_mouse)
	else:
		tw.tween_property(complete, "modulate:a", 0.0, 1.5)
		tw.tween_callback(_hide_card)


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_card() -> void:
	complete.visible = false


func show_shift_complete(shift: int, trees_done: int) -> void:
	complete_label.text = "SHIFT %d COMPLETE\n\nWork order filed. %d trees assessed and tagged.\n\nEnd of prototype." % [shift, trees_done]
	complete.visible = true
	cam_overlay.visible = false
	prompt.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------- builders ----------

func _build_tablet() -> void:
	tablet = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.07, 0.95)
	style.border_color = Color(0.35, 0.36, 0.34)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	tablet.add_theme_stylebox_override("panel", style)
	add_child(tablet)
	tablet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tablet.offset_left = -560.0
	tablet.offset_right = 560.0
	tablet.offset_top = -300.0
	tablet.offset_bottom = 300.0
	tablet.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	tablet.add_child(vbox)

	tab_header = Label.new()
	tab_header.add_theme_font_size_override("font_size", 18)
	tab_header.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	vbox.add_child(tab_header)

	order_text = RichTextLabel.new()
	order_text.bbcode_enabled = true
	order_text.scroll_active = false
	order_text.custom_minimum_size = Vector2(1070, 500)
	order_text.add_theme_font_size_override("normal_font_size", 16)
	order_text.add_theme_font_size_override("bold_font_size", 16)
	vbox.add_child(order_text)

	tapes_box = HBoxContainer.new()
	tapes_box.add_theme_constant_override("separation", 20)
	tapes_box.visible = false
	vbox.add_child(tapes_box)

	tape_list = RichTextLabel.new()
	tape_list.bbcode_enabled = true
	tape_list.scroll_active = false
	tape_list.custom_minimum_size = Vector2(300, 440)
	tape_list.add_theme_font_size_override("normal_font_size", 18)
	tape_list.add_theme_font_size_override("bold_font_size", 18)
	tapes_box.add_child(tape_list)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	tapes_box.add_child(right)

	tape_view = TextureRect.new()
	tape_view.custom_minimum_size = Vector2(528, 297)
	tape_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tape_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tape_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(tape_view)

	tape_time = Label.new()
	tape_time.add_theme_font_size_override("font_size", 18)
	right.add_child(tape_time)

	# Notes page: HT-6's field notes.
	notes_box = HBoxContainer.new()
	notes_box.add_theme_constant_override("separation", 24)
	notes_box.visible = false
	tapes_box.get_parent().add_child(notes_box)
	notes_list = RichTextLabel.new()
	notes_list.bbcode_enabled = true
	notes_list.scroll_active = false
	notes_list.custom_minimum_size = Vector2(300, 480)
	notes_list.add_theme_font_size_override("normal_font_size", 16)
	notes_list.add_theme_font_size_override("bold_font_size", 16)
	notes_box.add_child(notes_list)
	note_text = RichTextLabel.new()
	note_text.bbcode_enabled = true
	note_text.scroll_active = false
	note_text.custom_minimum_size = Vector2(740, 480)
	note_text.add_theme_font_size_override("normal_font_size", 19)
	note_text.add_theme_color_override("default_color", Color(0.9, 0.86, 0.75))
	notes_box.add_child(note_text)

	var help := Label.new()
	help.text = "Up/Down select   Space play/pause   Left/Right scrub 1s"
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	right.add_child(help)


# ---------- tablet pages and tape playback ----------

func _tablet_input(delta: float) -> void:
	if Input.is_action_just_pressed("tablet_page"):
		page = (page + 1) % 3
		playing = false
		_refresh_page()
	if page == 2 and not notes.is_empty():
		if Input.is_action_just_pressed("ui_down"):
			note_sel = mini(note_sel + 1, notes.size() - 1)
			_refresh_notes()
		elif Input.is_action_just_pressed("ui_up"):
			note_sel = maxi(note_sel - 1, 0)
			_refresh_notes()
		return
	if page != 1 or recorder == null or recorder.clips.is_empty():
		return
	var n: int = recorder.clips.size()
	if Input.is_action_just_pressed("ui_down"):
		tape_sel = mini(tape_sel + 1, n - 1)
		_select_tape()
	elif Input.is_action_just_pressed("ui_up"):
		tape_sel = maxi(tape_sel - 1, 0)
		_select_tape()
	var length: float = recorder.clip_length(recorder.clips[tape_sel])
	if Input.is_action_just_pressed("ui_accept"):
		if play_t >= length:
			play_t = 0.0
		playing = not playing
	if Input.is_action_just_pressed("ui_right"):
		play_t = minf(play_t + 1.0, length)
	if Input.is_action_just_pressed("ui_left"):
		play_t = maxf(play_t - 1.0, 0.0)
	if playing:
		play_t += delta
	_show_frame()


func _refresh_page() -> void:
	var count: int = 0 if recorder == null else recorder.clips.size()
	var labels := ["WORK ORDER", "TAPES (%d)" % count, "NOTES (%d)" % notes.size()]
	labels[page] = "[ %s ]" % labels[page]
	tab_header.text = "%s     %s     %s          Q to switch" % labels
	order_text.visible = page == 0
	tapes_box.visible = page == 1
	notes_box.visible = page == 2
	if page == 2:
		_refresh_notes()
	if page == 1:
		_refresh_tape_list()
		_show_frame()


## Picked up a note: open the tablet straight to it.
func open_note(title: String, text: String) -> void:
	notes.append({"title": title, "text": text})
	note_sel = notes.size() - 1
	page = 2
	show_tablet(true)


func _refresh_notes() -> void:
	if notes.is_empty():
		notes_list.text = "[color=#888888]No notes yet.[/color]"
		note_text.text = ""
		return
	var s := "[b]FIELD NOTES — UNIT HT-6[/b]\n\n"
	for i in notes.size():
		if i == note_sel:
			s += "[b][color=#f0e6c8]> %s[/color][/b]\n" % notes[i]["title"]
		else:
			s += "[color=#999999]  %s[/color]\n" % notes[i]["title"]
	notes_list.text = s
	note_text.text = notes[note_sel]["text"]


## Something on the work order that shouldn't be there.
func ghost_line(seconds: float) -> void:
	ghost_t = seconds
	if tablet.visible and page == 0:
		update_tablet(last_items)


func _select_tape() -> void:
	play_t = 0.0
	playing = false
	_refresh_tape_list()


func _refresh_tape_list() -> void:
	if recorder == null or recorder.clips.is_empty():
		tape_list.text = "[color=#888888]No tapes yet.\n\nHold right mouse to record.[/color]"
		tape_view.texture = null
		tape_time.text = ""
		return
	var s := ""
	for i in recorder.clips.size():
		var clip: Dictionary = recorder.clips[i]
		var trees: Array = clip["trees"]
		var subject := "—" if trees.is_empty() else ", ".join(PackedStringArray(trees))
		var line := "%s   %s   %s" % [clip["label"], _fmt(recorder.clip_length(clip)), subject]
		if i == tape_sel:
			s += "[b][color=#f0e6c8]> %s[/color][/b]\n" % line
		else:
			s += "[color=#999999]  %s[/color]\n" % line
	tape_list.text = s


func _show_frame() -> void:
	if recorder == null or recorder.clips.is_empty():
		return
	var clip: Dictionary = recorder.clips[tape_sel]
	var frames: Array = clip["frames"]
	var length: float = recorder.clip_length(clip)
	if play_t >= length:
		play_t = length
		playing = false
	var idx := clampi(int(play_t * recorder.fps), 0, frames.size() - 1)
	tape_view.texture = frames[idx]
	tape_time.text = "%s   %s / %s" % ["PLAYING" if playing else "PAUSED", _fmt(play_t), _fmt(length)]


func _fmt(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


func _build_complete() -> void:
	complete = ColorRect.new()
	complete.color = Color(0, 0, 0, 0.92)
	add_child(complete)
	complete.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	complete.visible = false

	complete_label = _label(complete, "", 28, Color(0.92, 0.92, 0.88))
	complete_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l
