extends CanvasLayer
## Esc: pause. Resume, toggle fullscreen, change graphics quality, or quit.
## F11 (or Alt+Enter) toggles fullscreen any time.

var main
var root: Control
var quality_btn: Button
var screen_btn: Button
var _was_captured := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -170
	box.offset_right = 170
	box.offset_top = -170
	box.offset_bottom = 170

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	box.add_child(title)
	box.add_child(_button("Resume", _resume))
	screen_btn = _button("", _toggle_fullscreen)
	box.add_child(screen_btn)
	quality_btn = _button("", _cycle_quality)
	box.add_child(quality_btn)
	box.add_child(_button("Quit to desktop", _quit))
	_refresh()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if root.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _resume() -> void:
	root.visible = false
	get_tree().paused = false
	if _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
	else:
		w.mode = Window.MODE_FULLSCREEN
	_refresh()


func _cycle_quality() -> void:
	if main != null:
		main._apply_quality((main.quality + 1) % 3)
	_refresh()


func _quit() -> void:
	get_tree().quit()


func _refresh() -> void:
	if screen_btn == null:
		return
	var w := get_window()
	var full := w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	screen_btn.text = "Fullscreen: %s   (F11)" % ("ON" if full else "OFF")
	if main != null:
		quality_btn.text = "Graphics: %s   (F10)" % main.QUALITY_NAMES[main.quality]
