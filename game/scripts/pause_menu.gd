extends CanvasLayer
## Esc: pause / resume.

const ROW_Y := 100.0
const ROW_W := 60.0

var _box: Control
var _msg := ""
var _open := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.visible = false
	_box.draw.connect(_draw_box)
	add_child(_box)


func is_open() -> bool:
	return _open


func _options() -> Array:
	if Net.is_client():
		return [["ESC", "wróć", "resume"], ["Q", "wyjdź", "quit"]]
	return [["ESC", "wróć", "resume"], ["S", "zapisz", "save"], ["W", "wczytaj", "load"], ["Q", "menu", "quit"]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not Game.hacking:
		_toggle()
		get_viewport().set_input_as_handled()
	elif not _open:
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				_do("quit")
			KEY_S:
				_do("save")
			KEY_W:
				_do("load")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var opts := _options()
		var x0 := 160.0 - opts.size() * ROW_W / 2.0
		for i in opts.size():
			if Rect2(x0 + i * ROW_W, ROW_Y - 10, ROW_W - 4, 16).has_point(event.position):
				_do(opts[i][2])
				get_viewport().set_input_as_handled()


func _do(what: String) -> void:
	if not _options().any(func(o): return o[2] == what):
		return
	match what:
		"resume":
			_toggle()
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
	_msg = ""
	_box.queue_redraw()


func _draw_box() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	_box.draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0, 0.6))
	_box.draw_string(f, Vector2(0, 66), "PAUZA", HORIZONTAL_ALIGNMENT_CENTER, 320, fs * 2, Color("e8e8e8"))
	var who := "1 GRACZ"
	if Net.is_host():
		who = "HOST (online)"
	elif Net.is_client():
		who = "GRACZ 2 (online)"
	elif Game.coop:
		who = "2 GRACZY"
	var mode_info := "%s  |  POZIOM: %s" % [who, "TRUDNY" if Game.is_hard() else "NORMALNY"]
	_box.draw_string(f, Vector2(0, 82), mode_info, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("ffe08a"))
	var opts := _options()
	var x0 := 160.0 - opts.size() * ROW_W / 2.0
	for i in opts.size():
		var r := Rect2(x0 + i * ROW_W, ROW_Y - 10, ROW_W - 4, 16)
		_box.draw_rect(r, Color(0.08, 0.09, 0.12, 0.9))
		_box.draw_rect(r, Color("4a5160"), false, 1.0)
		_box.draw_string(f, Vector2(r.position.x, ROW_Y + 1), "%s  %s" % [opts[i][0], opts[i][1]],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color("c0c8d0"))
	if Net.active():
		_box.draw_string(f, Vector2(0, 124), "Gra online biegnie dalej.", HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("8a929c"))
	if _msg != "":
		_box.draw_string(f, Vector2(0, 136), _msg, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("8fe0a0"))
