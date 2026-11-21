extends CanvasLayer
## In-game HUD: status strip.

const HackMaze := preload("res://scripts/hack_maze.gd")
const HackRings := preload("res://scripts/hack_rings.gd")
const HackWires := preload("res://scripts/hack_wires.gd")
const HackHard := preload("res://scripts/hack_hard.gd")
const NotesHUD := preload("res://scripts/notes_hud.gd")
const Tablet := preload("res://scripts/tablet.gd")
const StatusBar := preload("res://scripts/status_bar.gd")
const DialogBox := preload("res://scripts/dialog_box.gd")
const VIEW := Vector2(320, 180)

var tablet: Control
var status: Control
var crosshair: Control
## Arrow to the person to go back to (main.gd quest_arrow_target()).
var quest_arrow: Control
var _arrow_t := 0.0
var _bars: Array[ColorRect] = []
var dialog: Control
var hack: Control
var notes_box: Control
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
	hint.position = Vector2(4, 25 if Game.coop else 22)
	hint.size = Vector2(220, 10)
	hint.modulate.a = 0.0
	root.add_child(hint)
	Game.hint.connect(show_hint)

	# cinematic bars for hard cutscenes (under the dialog strip, which stays readable)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(VIEW.x, 0)
		bar.position.y = 0.0 if top else VIEW.y
		bar.set_meta("top", top)
		root.add_child(bar)
		_bars.append(bar)

	dialog = DialogBox.new()
	dialog.position = Vector2(3, 150)
	root.add_child(dialog)

	notes_box = NotesHUD.new()
	root.add_child(notes_box)

	hack = HackMaze.new()
	for panel in [hack, HackRings.new(), HackWires.new()]:
		panel.position = Vector2(VIEW.x - 124 - 4, 6)
		root.add_child(panel)

	var hard_panel := HackHard.new()
	hard_panel.notes_hud = notes_box
	notes_box.hard_panel = hard_panel
	hard_panel.position = Vector2(VIEW.x - HackHard.PANEL.x - 4, 6)
	root.add_child(hard_panel)

	quest_arrow = Control.new()
	quest_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	quest_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_arrow.draw.connect(_draw_quest_arrow)
	root.add_child(quest_arrow)

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


func set_hp2(v: int, m: int) -> void:
	status.set_hp2(v, m)


## On screen: a bobbing arrow above the person (or door).
func _draw_quest_arrow() -> void:
	if Game.hacking or Game.menu_open or Game.cutscene:
		return
	var story := get_tree().get_first_node_in_group("story")
	if story == null or not story.has_method("quest_arrow_target"):
		return
	var world: Vector2 = story.quest_arrow_target()
	if world == Vector2.INF:
		return
	var at := get_viewport().get_canvas_transform() * world
	var inner := Rect2(Vector2(12, 26), VIEW - Vector2(24, 52))
	var col := Color("ffe08a")
	var dir := Vector2.DOWN
	if inner.has_point(at):
		at.y += sin(_arrow_t * 5.0) * 2.0 - 4.0
	else:
		dir = (at - VIEW / 2.0).normalized()
		at = Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))
		at += dir * sin(_arrow_t * 5.0) * 1.5
	var side := dir.orthogonal()
	var arrow := func(size: float) -> PackedVector2Array:
		return PackedVector2Array([at + dir * size, at - dir * size * 0.6 + side * size, at - dir * size * 0.6 - side * size])
	quest_arrow.draw_colored_polygon(arrow.call(6.5), Color(0, 0, 0, 0.7))  # outline
	quest_arrow.draw_colored_polygon(arrow.call(4.5), col)


func _draw_crosshair() -> void:
	var m := crosshair.get_local_mouse_position()
	if Touch.active:
		if not Touch.aiming or Game.hacking:
			return
		m = Touch.aim_pos
	var c := Color(1, 0.9, 0.6, 0.9) if Game.has_pistol and Game.ammo > 0 else Color(0.8, 0.8, 0.8, 0.5)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		crosshair.draw_line(m + d * 2.0, m + d * 5.0, Color(0, 0, 0, 0.6), 2.0)
		crosshair.draw_line(m + d * 2.0, m + d * 5.0, c, 1.0)
	crosshair.draw_rect(Rect2(m - Vector2(0.5, 0.5), Vector2(1, 1)), c)


func _process(delta: float) -> void:
	_arrow_t += delta
	quest_arrow.queue_redraw()
	crosshair.queue_redraw()
	var panel_open := Game.hacking or (is_instance_valid(notes_box) and notes_box.visible)
	# a cutscene shows only the picture (and the dialog strip)
	status.visible = not Game.cutscene
	tablet.visible = not Game.cutscene
	crosshair.visible = not Game.cutscene
	objective.visible = not Game.hacking and not Game.cutscene
	hint.visible = not panel_open and not Game.cutscene
	# touch: the dialog strip sits up top, so the tip goes just under it
	var hint_y := 25.0 if Game.coop else 22.0
	if dialog.visible and dialog.is_top():
		hint_y = dialog.position.y + dialog.size.y + 2.0
	hint.position.y = hint_y
	var p := Game.player
	var p2 := Game.player2
	if Game.cutscene:
		prompt.text = ""
	elif is_instance_valid(p) and p.current_interactable and not p.hacking and not p.dead:
		prompt.text = p.current_interactable.prompt()
	elif Game.coop and is_instance_valid(p2) and p2.current_interactable and not p2.hacking and not p2.dead:
		var p2_prompt: String = p2.current_interactable.prompt()
		prompt.text = p2_prompt.replace("[E]", "[L]") if Game.is_shared_p2(p2) else p2_prompt
	else:
		prompt.text = ""


## Black bars in / out for a hard cutscene.
func cinematic(on: bool) -> void:
	for bar in _bars:
		var h := 18.0 if on else 0.0
		var tw := bar.create_tween().set_parallel(true)
		tw.tween_property(bar, "size:y", h, 0.4)
		if not bar.get_meta("top"):
			tw.tween_property(bar, "position:y", VIEW.y - h, 0.4)
		else:
			bar.position.y = 0.0


func show_big(text: String, color: Color, hold := 1.5) -> void:
	Net.send_hud("show_big", [text, color, hold])
	big.text = text
	big.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(big, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(big, "modulate:a", 0.0, 0.6)


func fade(to_alpha: float, time := 0.6) -> Tween:
	Net.send_hud("fade", [to_alpha, time])
	var tw := create_tween()
	tw.tween_property(fader, "color:a", to_alpha, time)
	return tw
