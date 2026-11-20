extends CanvasLayer
## Esc: pause / resume. Q while paused: back to the title screen.

var _box: Control


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
	elif _box.visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _toggle() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_box.visible = p
	_box.queue_redraw()


func _draw_box() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	_box.draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0, 0.6))
	_box.draw_string(f, Vector2(0, 80), "PAUZA", HORIZONTAL_ALIGNMENT_CENTER, 320, fs * 2, Color("e8e8e8"))
	_box.draw_string(f, Vector2(0, 104), "[ESC] wróć    [Q] menu", HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("c0c8d0"))
