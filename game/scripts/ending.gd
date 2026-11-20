extends Control
## Ending board (static, not a cutscene): dawn, Braun's jet takes off, Ireland.

var _t := 0.0
var _plane: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_plane = PropArt.plane()
	Sfx.set_static(0.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t > 4.0 and Input.is_action_just_pressed("accept"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _draw() -> void:
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var dawn := clampf(_t / 6.0, 0.0, 1.0)
	var top := Color("0a0d18").lerp(Color("2a3a6a"), dawn)
	var bottom := Color("1a1420").lerp(Color("e0905a"), dawn)
	for y in 180:
		draw_line(Vector2(0, y), Vector2(320, y), top.lerp(bottom, y / 180.0))
	for i in 14:
		var h := 14 + (i * 29) % 30
		draw_rect(Rect2(i * 24, 180 - h, 22, h), Color("0b0c10"))
	var p := Vector2(-60 + _t * 45.0, 150 - maxf(_t - 1.5, 0.0) * 18.0)
	if _plane:
		draw_set_transform(p, -0.12 if _t > 1.5 else 0.0)
		draw_texture(_plane, -_plane.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
	if _t > 2.5:
		_center(f, "Braun: Proszę przełączyć urządzenia", 22, fs, Color("e8e8e8"))
		_center(f, "w tryb samolotowy.", 32, fs, Color("e8e8e8"))
	if _t > 4.0:
		_center(f, "Johnny: Już dawno są.", 46, fs, Color("8fc0ff"))
	if _t > 5.5:
		_center(f, "TRYB SAMOLOTOWY: WŁĄCZONY", 70, fs, Color("8fe0a0"))
	if _t > 7.0:
		_center(f, "Irlandia. Tam wojny nigdy nie było.", 92, fs, Color("ffe08a"))
	if _t > 9.0 and fmod(_t, 1.0) < 0.65:
		_center(f, "[ENTER] menu", 120, fs, Color("c0c8d0"))


func _center(f: Font, text: String, y: float, fs: int, c: Color) -> void:
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, c)
