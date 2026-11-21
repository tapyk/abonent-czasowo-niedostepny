extends Control
## Settings box, the same on the title screen and in the pause menu.

signal closed

const BOX := Rect2(50, 46, 220, 104)
const ROW_W := 200.0
const ROW0 := 70.0
const ROW_STEP := 13.0

var _rows: Array[String] = []
var _sel := 0
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rows = ["volume"]
	if Settings.can_fullscreen():
		_rows.append("fullscreen")
	_rows.append_array(["shake", "touch", "back"])


func open() -> void:
	_sel = 0
	visible = true
	Sfx.play("confirm", 0.05, -10.0)


func close() -> void:
	visible = false
	Settings.save()
	Sfx.play("beep", 0.05, -10.0)
	closed.emit()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _row_rect(i: int) -> Rect2:
	return Rect2(160.0 - ROW_W / 2.0, ROW0 + i * ROW_STEP - 9.0, ROW_W, 12.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("back"):
		close()
	elif event.is_action_pressed("move_up"):
		_sel = wrapi(_sel - 1, 0, _rows.size())
		Sfx.play("beep", 0.05, -12.0)
	elif event.is_action_pressed("move_down"):
		_sel = wrapi(_sel + 1, 0, _rows.size())
		Sfx.play("beep", 0.05, -12.0)
	elif event.is_action_pressed("move_left"):
		_change(_rows[_sel], -1)
	elif event.is_action_pressed("move_right"):
		_change(_rows[_sel], 1)
	elif event.is_action_pressed("accept") or event.is_action_pressed("interact"):
		_confirm(_rows[_sel], 1)
	elif event is InputEventMouse:
		var at: Vector2 = make_input_local(event).position
		var row := -1
		for i in _rows.size():
			if _row_rect(i).has_point(at):
				row = i
		if row >= 0 and event is InputEventMouseMotion and row != _sel:
			_sel = row
		elif row >= 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_sel = row
			_confirm(_rows[row], -1 if at.x < 160.0 + 20.0 else 1)
		elif not (event is InputEventMouseButton and event.pressed):
			handled = false
	else:
		handled = event is InputEventKey or event is InputEventAction  # nothing behind gets keys
	if handled:
		get_viewport().set_input_as_handled()


func _confirm(row: String, step: int) -> void:
	if row == "back":
		close()
	else:
		_change(row, step)


func _change(row: String, step: int) -> void:
	match row:
		"volume":
			Settings.volume = clampi(Settings.volume + step * 10, 0, 100)
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
		"shake":
			Settings.shake = not Settings.shake
		"touch":
			var modes := Settings.TOUCH_MODES
			Settings.touch = modes[wrapi(modes.find(Settings.touch) + step, 0, modes.size())]
		_:
			return
	Settings.apply()
	Sfx.play("confirm", 0.05, -10.0)


func _value(row: String) -> String:
	match row:
		"volume":
			var bars := Settings.volume / 10
			return "%s %d%%" % ["|".repeat(bars) + ".".repeat(10 - bars), Settings.volume]
		"fullscreen":
			return "TAK" if Settings.fullscreen else "NIE"
		"shake":
			return "TAK" if Settings.shake else "NIE"
		"touch":
			return {"auto": "AUTO", "on": "ZAWSZE", "off": "WYŁ."}[Settings.touch]
	return ""


func _describe(row: String) -> String:
	match row:
		"volume":
			return "Wszystkie dźwięki gry."
		"fullscreen":
			return "Okno albo cały ekran."
		"shake":
			return "Trzęsienie kamery przy trafieniach."
		"touch":
			return {"auto": "Na telefonie albo po pierwszym dotyku.", "on": "Przyciski dotykowe zawsze widoczne.",
				"off": "Bez przycisków (klawiatura / pad)."}[Settings.touch]
	return "Zapisuje i wraca."


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(Vector2.ZERO, Vector2(320, 180)), Color(0, 0, 0, 0.45))
	draw_rect(BOX, Color(0.04, 0.05, 0.08, 0.96))
	draw_rect(BOX, Color("4a5160"), false, 1.0)
	draw_string(f, Vector2(0, BOX.position.y + 11), "USTAWIENIA", HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("ff6a5a"))
	var labels := {"volume": "GŁOŚNOŚĆ", "fullscreen": "PEŁNY EKRAN", "shake": "WSTRZĄSY", "touch": "DOTYK", "back": "WRÓĆ"}
	for i in _rows.size():
		var row := _rows[i]
		var r := _row_rect(i)
		var sel := i == _sel
		if sel:
			draw_rect(r, Color(1, 0.16, 0.1, 0.12))
			if fmod(_t, 1.2) < 0.7:
				draw_rect(Rect2(r.position.x + 4, r.position.y + 4, 4, 4), Color("ff2a2a"))
		var col := Color("ffe08a") if sel else Color("aab2bc")
		var y := r.position.y + 9.0
		if row == "back":
			draw_string(f, Vector2(0, y), labels[row], HORIZONTAL_ALIGNMENT_CENTER, 320, fs, col)
			continue
		draw_string(f, Vector2(0, y), labels[row], HORIZONTAL_ALIGNMENT_RIGHT, 160.0 - 6.0, fs, col)
		var v := _value(row)
		draw_string(f, Vector2(160.0 + 6.0, y), ("< %s >" % v) if sel else v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_string(f, Vector2(0, BOX.end.y - 5), _describe(_rows[_sel]), HORIZONTAL_ALIGNMENT_CENTER, 320, fs, Color("9fd8ff"))
