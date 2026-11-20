extends CanvasLayer
## In-game HUD: status strip.

const HackMaze := preload("res://scripts/hack_maze.gd")
const HackRings := preload("res://scripts/hack_rings.gd")
const HackWires := preload("res://scripts/hack_wires.gd")
const Tablet := preload("res://scripts/tablet.gd")
const StatusBar := preload("res://scripts/status_bar.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")
const VIEW := Vector2(320, 180)

var tablet: Control
var status: Control
var crosshair: Control
var dialog: Control
var hack: Control
var objective: Label
var prompt: Label
var hint: Label
var _hint_tw: Tween
var fader: ColorRect
var big: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	status = StatusBar.new()
	status.position = Vector2(4, 4)
	root.add_child(status)

	tablet = Tablet.new()
	tablet.base_position = VIEW - Vector2(Tablet.W, Tablet.H) - Vector2(2, 2)
	tablet.position = tablet.base_position + Vector2(0, Tablet.H - Tablet.PEEK)
	root.add_child(tablet)

	objective = _label(Color("c8d0d8"))
	objective.position = Vector2(150, 3)
	objective.size = Vector2(167, 20)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective)

	prompt = _label(Color("ffe08a"))
	prompt.position = Vector2(4, 126)
	prompt.size = Vector2(210, 10)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)

	hint = _label(Color("9fd8ff"))
	hint.position = Vector2(4, 22)
	hint.size = Vector2(220, 10)
	hint.modulate.a = 0.0
	root.add_child(hint)
	Game.hint.connect(show_hint)

	dialog = DialogBox.new()
	dialog.position = Vector2(3, 150)
	root.add_child(dialog)

	hack = HackMaze.new()
	for panel in [hack, HackRings.new(), HackWires.new()]:
		panel.position = Vector2(VIEW.x - 124 - 4, 6)
		root.add_child(panel)

	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)

	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fader)

	big = _label(Color("ff4a3a"))
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.modulate.a = 0.0
	big.add_theme_font_size_override("font_size", Art.FONT_SIZE * 2)
	root.add_child(big)


func _label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Art.font())
	l.add_theme_font_size_override("font_size", Art.FONT_SIZE)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Control tip under the status strip; shows at once, independent of dialog lines.
func show_hint(text: String, hold := 7.0) -> void:
	hint.text = text
	if _hint_tw:
		_hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(hint, "modulate:a", 1.0, 0.2)
	_hint_tw.tween_interval(hold)
	_hint_tw.tween_property(hint, "modulate:a", 0.0, 0.8)


func set_objective(text: String) -> void:
	objective.text = text


func set_hp(v: int, m: int) -> void:
	status.set_hp(v, m)


func _draw_crosshair() -> void:
	var m := crosshair.get_local_mouse_position()
	var c := Color(1, 0.9, 0.6, 0.9) if Game.has_pistol and Game.ammo > 0 else Color(0.8, 0.8, 0.8, 0.5)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		crosshair.draw_line(m + d * 2.0, m + d * 5.0, Color(0, 0, 0, 0.6), 2.0)
		crosshair.draw_line(m + d * 2.0, m + d * 5.0, c, 1.0)
	crosshair.draw_rect(Rect2(m - Vector2(0.5, 0.5), Vector2(1, 1)), c)


func _process(_delta: float) -> void:
	crosshair.queue_redraw()
	var p := Game.player
	if is_instance_valid(p) and p.current_interactable and not p.hacking and not p.dead:
		prompt.text = p.current_interactable.prompt()
	else:
		prompt.text = ""


func show_big(text: String, color: Color, hold := 1.5) -> void:
	big.text = text
	big.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(big, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(big, "modulate:a", 0.0, 0.6)


func fade(to_alpha: float, time := 0.6) -> Tween:
	var tw := create_tween()
	tw.tween_property(fader, "color:a", to_alpha, time)
	return tw
