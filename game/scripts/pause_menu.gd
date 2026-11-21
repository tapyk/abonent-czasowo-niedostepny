extends CanvasLayer
## Esc: pause / resume.

const SETTINGS_PANEL := preload("res://scripts/settings_panel.gd")
const ROW0 := 76.0
const ROW_STEP := 14.0
const ROW_W := 140.0

var _box: Control
var _settings: Control
var _msg := ""
var _open := false
var _sel := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	# clicks / taps must reach _input below, not stop at this full-screen backdrop
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_box.draw.connect(_draw_box)
	add_child(_box)
	_settings = SETTINGS_PANEL.new()
	_settings.closed.connect(_box.queue_redraw)
	add_child(_settings)


func is_open() -> bool:
	return _open


## [key, label, action]
func _options() -> Array:
	if Net.is_client():
		return [["ESC", "wróć do gry", "resume"], ["O", "ustawienia", "settings"], ["Q", "wyjdź", "quit"]]
	return [["ESC", "wróć do gry", "resume"], ["S", "zapisz", "save"], ["W", "wczytaj", "load"],
		["O", "ustawienia", "settings"], ["Q", "wyjdź do menu", "quit"]]


func _row_rect(i: int) -> Rect2:
	return Rect2(160.0 - ROW_W / 2.0, ROW0 + i * ROW_STEP - 10.0, ROW_W, 12.0)


func _input(event: InputEvent) -> void:
	# Clicks and taps on the options (touch.gd turns taps into clicks). In _input, so no
	# GUI control in the game scene can swallow them first.
	if not _open or _settings.visible or not (event is InputEventMouse):
		return
	var opts := _options()
	for i in opts.size():
		if _row_rect(i).has_point(event.position):
			if event is InputEventMouseMotion and i != _sel:
				_sel = i
				_box.queue_redraw()
			elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				_sel = i
				_do(opts[i][2])
			return


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible:
		return  # the settings box handles its own keys (ESC closes it first)
	if event.is_action_pressed("back") and not Game.hacking:
		_toggle()
		get_viewport().set_input_as_handled()
	elif not _open:
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		var opts := _options()
		match event.physical_keycode:
			KEY_Q:
				_do("quit")
			KEY_S:
				_do("save")
			KEY_W:
				_do("load")
			KEY_O:
				_do("settings")
			KEY_UP:
				_sel = wrapi(_sel - 1, 0, opts.size())
			KEY_DOWN:
				_sel = wrapi(_sel + 1, 0, opts.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_do(opts[_sel][2])
		_box.queue_redraw()


func _do(what: String) -> void:
	if not _options().any(func(o): return o[2] == what):
		return
	match what:
		"resume":
			_toggle()
		"settings":
			_msg = ""
			_settings.open()
		"quit":
			get_tree().paused = false
			Game.menu_open = false
			Net.leave()
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		"save":
			var story := get_tree().get_first_node_in_group("story")
			var ok: bool = story != null and story.save_game()
			_msg = "Zapisano." if ok else "Teraz nie można zapisać."
			_box.queue_redraw()
		"load":
			if Game.has_save():
				Game.menu_open = false
				Game.pending_load = Game.read_save()
				get_tree().paused = false
				get_tree().reload_current_scene()
			else:
				_msg = "Brak zapisu."
				_box.queue_redraw()


func _toggle() -> void:
	_open = not _open
	Game.menu_open = _open
	if not Net.active():
		get_tree().paused = _open
	_box.visible = _open
	_sel = 0
	_msg = ""
	_box.queue_redraw()


func _draw_box() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	_box.draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0, 0.6))
	_box.draw_string(f, Vector2(0, 44), "PAUZA", HORIZONTAL_ALIGNMENT_CENTER, 320, fs * 2, Color("e8e8e8"))
	var who := "1 GRACZ"
	if Net.is_host():
		who = "HOST (online)"
	elif Net.is_client():
		who = "GRACZ 2 (online)"
	elif Game.coop:
		who = "2 GRACZY"
	var mode_info := "%s  |  POZIOM: %s" % [who, "TRUDNY" if Game.is_hard() else "NORMALNY"]
	_box.draw_string(f, Vector2(0, 58), mode_info, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("ffe08a"))
	var opts := _options()
	for i in opts.size():
		var r := _row_rect(i)
		var sel := i == _sel
		_box.draw_rect(r, Color(0.2, 0.08, 0.06, 0.95) if sel else Color(0.08, 0.09, 0.12, 0.9))
		_box.draw_rect(r, Color("ffe08a") if sel else Color("4a5160"), false, 1.0)
		var col := Color("ffe08a") if sel else Color("c0c8d0")
		_box.draw_string(f, Vector2(r.position.x + 5, r.position.y + 9), opts[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8a929c"))
		_box.draw_string(f, Vector2(r.position.x, r.position.y + 9), opts[i][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
	var y := ROW0 + opts.size() * ROW_STEP + 4.0
	if _msg != "":
		_box.draw_string(f, Vector2(0, y), _msg, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("8fe0a0"))
		y += 11.0
	if Net.active():
		_box.draw_string(f, Vector2(0, y), "Gra online biegnie dalej.", HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("8a929c"))
