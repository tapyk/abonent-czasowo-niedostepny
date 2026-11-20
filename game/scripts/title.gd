extends Control
## Title screen.

var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.set_static(0.15)
	if Game.dev.has("autostart") or Game.dev.has("autotest") or Game.dev.has("shot"):
		_start.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if Input.is_action_just_pressed("accept"):
		_start()


func _start() -> void:
	Sfx.set_static(0.0)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	draw_rect(Rect2(Vector2.ZERO, size), Color("07080c"))
	# horizon blocks + antenna
	for i in 12:
		var h := 20 + (i * 37) % 45
		draw_rect(Rect2(i * 28, 180 - h, 24, h), Color("10131a"))
	draw_line(Vector2(250, 180 - 50), Vector2(250, 60), Color("2a2e36"), 2.0)
	if fmod(_t, 1.2) < 0.7:
		draw_rect(Rect2(248, 57, 4, 4), Color("ff2a2a"))
		draw_circle(Vector2(250, 59), 10.0, Color(1, 0.1, 0.1, 0.12))
	_center(f, "ABONENT NIEDOSTĘPNY", 48, fs * 2, Color("e8e8e8"))
	_center(f, "Wszyscy przywracają zasięg. My go wyłączamy.", 66, fs, Color("ff6a5a"))
	if fmod(_t, 1.0) < 0.65:
		_center(f, "[ENTER] start", 96, fs, Color("ffe08a"))
	_center(f, "A/D ruch   SPACJA skok   S+SPACJA zeskok   J/LPM strzał", 128, fs, Color("8a929c"))
	_center(f, "K/PPM cios   E akcja   ESC wyjście z panelu", 140, fs, Color("8a929c"))


func _center(f: Font, text: String, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, c)
