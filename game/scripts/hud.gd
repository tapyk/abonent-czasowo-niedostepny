extends CanvasLayer
## In-game HUD: tablet.

const HackMaze := preload("res://scripts/hack_maze.gd")
const Tablet := preload("res://scripts/tablet.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")

var tablet: Control
var dialog: Control
var hack: Control
var objective: Label
var prompt: Label
var fader: ColorRect
var big: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tablet = Tablet.new()
	tablet.position = Vector2(4, 4)
	root.add_child(tablet)

	objective = _label(Color("c8d0d8"))
	objective.position = Vector2(120, 4)
	objective.size = Vector2(196, 24)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective)

	prompt = _label(Color("ffe08a"))
	prompt.position = Vector2(60, 124)
	prompt.size = Vector2(200, 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)

	dialog = DialogBox.new()
	dialog.position = Vector2(10, 142)
	root.add_child(dialog)

	hack = HackMaze.new()
	hack.position = Vector2(192, 30)
	root.add_child(hack)

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


func set_objective(text: String) -> void:
	objective.text = text


func _process(_delta: float) -> void:
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
