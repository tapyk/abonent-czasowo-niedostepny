extends CanvasLayer
## Esc: pause / resume. While paused: S saves, W loads the save, Q goes to the title screen.

var _box: Control
var _msg := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.visible = false
	_box.draw.connect(_draw_box)
	add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not Game.hacking:
		_toggle()
		get_viewport().set_input_as_handled()
	elif _box.visible and event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/title.tscn")
			KEY_S:
				var story := get_tree().get_first_node_in_group("story")
				var ok: bool = story != null and story.save_game()
				_msg = "Zapisano." if ok else "Teraz nie można zapisać."
				_box.queue_redraw()
			KEY_W:
				if Game.has_save():
					Game.pending_load = Game.read_save()
					get_tree().paused = false
					get_tree().reload_current_scene()
				else:
					_msg = "Brak zapisu."
					_box.queue_redraw()


func _toggle() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_box.visible = p
	_msg = ""
	_box.queue_redraw()


func _draw_box() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	_box.draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0, 0.6))
	_box.draw_string(f, Vector2(0, 80), "PAUZA", HORIZONTAL_ALIGNMENT_CENTER, 320, fs * 2, Color("e8e8e8"))
	_box.draw_string(f, Vector2(0, 104), "[ESC] wróć    [S] zapisz    [W] wczytaj    [Q] menu", HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("c0c8d0"))
	if _msg != "":
		_box.draw_string(f, Vector2(0, 120), _msg, HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("8fe0a0"))
