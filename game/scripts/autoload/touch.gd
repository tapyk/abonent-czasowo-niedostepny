extends CanvasLayer
## On-screen controls for phones and tablets.

const STICK_R := 20.0
const DEAD := 0.18
const STICK_HOME := Vector2(44, 136)

var active := false
## Settings "DOTYK": "auto" (phones / first touch), "on" (always), "off" (never).
var mode := "auto"
## A finger is on the aim side (gameplay): aim / shoot toward aim_pos.
var aiming := false
## Viewport coordinates (320x180) of the aiming finger.
var aim_pos := Vector2.ZERO
## Where the stick last pointed (unit vector, ZERO before the first push).
var look_dir := Vector2.ZERO

var _stick_finger := -1
var _stick_origin := STICK_HOME
var _stick_vec := Vector2.ZERO
var _aim_finger := -1
var _mouse_finger := -1
var _held := {}            # button id -> finger
var _layer: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.emulate_mouse_from_touch = false  # we turn taps into clicks ourselves (_click)
	get_tree().quit_on_go_back = false  # Android back: pause / leave a panel, not quit
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_controls)
	add_child(_layer)
	set_mode(Settings.touch)
	if Game.dev.has("touch"):
		_enable()
		if not OS.has_feature("mobile"):
			Input.emulate_touch_from_mouse = true


func set_mode(m: String) -> void:
	mode = m
	if mode == "off":
		_release_all()
		active = false
		Input.emulate_mouse_from_touch = true  # taps still click menus, no on-screen pad
	else:
		Input.emulate_mouse_from_touch = false  # we turn taps into clicks ourselves (_click)
		if mode == "on" or OS.has_feature("mobile"):
			_enable()


func _enable() -> void:
	if active:
		return
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Android back button / gesture works like ESC (pause, close a panel, back in menus).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_tap_action("back")


## World position under the aiming finger (through the game camera).
func aim_world(_from: Node = null) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * aim_pos


# --- modes ---------------------------------------------------------------------------

func _story() -> Node:
	return get_tree().get_first_node_in_group("story")


## The game scene is up and no menu covers it: stick and buttons are live.
func _in_game() -> bool:
	return _story() != null and not Game.menu_open and not Game.cutscene


func _buttons() -> Array:
	# [id, centre, radius, label, action]
	var out := []
	if not _in_game():
		return out
	out.append(["pause", Vector2(112, 10), 7.0, "II", "back"])
	if Game.is_hard():
		out.append(["notes", Vector2(130, 10), 7.0, "?", "toggle_notes"])
	if Game.hacking:
		# under the hack panel: E leaves it, OK presses / holds (rings, wires, hard panel)
		out.append(["interact", Vector2(302, 164), 10.0, "E", "interact"])
		out.append(["accept", Vector2(274, 164), 11.0, "OK", "accept"])
		return out
	# the punch is the big thumb button; E (things, people) sits next to it
	if _story().hud.dialog.visible:
		out.append(["accept", Vector2(296, 128), 13.0, "OK", "accept"])
	else:
		out.append(["melee", Vector2(296, 128), 13.0, "CIOS", "melee"])
	out.append(["interact", Vector2(266, 148), 11.0, "E", "interact"])
	return out


func _button_at(pos: Vector2) -> Array:
	for b in _buttons():
		if pos.distance_to(b[1]) <= b[2] + 4.0:
			return b
	return []


# --- input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if mode == "off":
		return
	if event is InputEventScreenTouch:
		_enable()
		if event.pressed:
			_finger_down(event.index, event.position)
		else:
			_finger_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_finger_move(event.index, event.position)
		get_viewport().set_input_as_handled()


func _finger_down(i: int, pos: Vector2) -> void:
	if _in_game():
		var b := _button_at(pos)
		if not b.is_empty():
			_held[b[0]] = i
			_send_action(_act(b[4]), true)
			_layer.queue_redraw()
			return
		var dialog_box: Control = _story().hud.dialog
		if dialog_box.visible and dialog_box.get_global_rect().has_point(pos):
			_tap_action(_act("accept"))  # tap the dialog strip: next line
			return
		if pos.x < 150.0 and _stick_finger < 0:
			_stick_finger = i
			_stick_origin = pos
			_stick_vec = Vector2.ZERO
			_layer.queue_redraw()
			return
		if not Game.hacking and _aim_finger < 0:
			_aim_finger = i
			aiming = true
			aim_pos = pos
			_send_action(_act("shoot"), true)
			_layer.queue_redraw()
			return
	if _mouse_finger < 0:
		_mouse_finger = i
		_click(pos, true)
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path in ["res://scenes/intro.tscn", "res://scenes/ending.tscn"]:
			_tap_action("accept")  # cutscenes skip on Enter


func _finger_move(i: int, pos: Vector2) -> void:
	if i == _stick_finger:
		var d := pos - _stick_origin
		if d.length() > STICK_R:
			_stick_origin = pos - d.limit_length(STICK_R)  # the stick follows a long drag
			d = pos - _stick_origin
		_stick_vec = d / STICK_R
		if _stick_vec.length() > DEAD:
			look_dir = _stick_vec.normalized()
		_apply_stick()
		_layer.queue_redraw()
	elif i == _aim_finger:
		aim_pos = pos
		_layer.queue_redraw()
	elif i == _mouse_finger:
		_mouse_motion(pos)


func _finger_up(i: int, pos: Vector2) -> void:
	for id in _held.keys():
		if _held[id] == i:
			_held.erase(id)
			for b in _all_button_actions():
				if b[0] == id:
					_send_action(_act(b[1]), false)
	if i == _stick_finger:
		_stick_finger = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	if i == _aim_finger:
		_aim_finger = -1
		aiming = false
		_send_action(_act("shoot"), false)
	if i == _mouse_finger:
		_mouse_finger = -1
		_click(pos, false)
	_layer.queue_redraw()


func _all_button_actions() -> Array:
	return [["pause", "back"], ["notes", "toggle_notes"], ["interact", "interact"],
		["accept", "accept"], ["melee", "melee"]]


func _act(action: String) -> String:
	return Game.action_for(Game.player, action) if is_instance_valid(Game.player) else action


func _apply_stick() -> void:
	var v := _stick_vec if _stick_vec.length() > DEAD else Vector2.ZERO
	for pair in [["move_left", maxf(-v.x, 0.0)], ["move_right", maxf(v.x, 0.0)],
			["move_up", maxf(-v.y, 0.0)], ["move_down", maxf(v.y, 0.0)]]:
		var action := _act(pair[0])
		if pair[1] > 0.0:
			Input.action_press(action, clampf(pair[1], 0.0, 1.0))
		else:
			Input.action_release(action)


func _process(_delta: float) -> void:
	if not active:
		return
	# Leaving the game (menu, cutscene, hack panel closed...) lets go of everything.
	if not _in_game() and (_stick_finger >= 0 or _aim_finger >= 0 or not _held.is_empty()):
		_release_all()
	if _aim_finger >= 0 and Game.hacking:
		_aim_finger = -1
		aiming = false
		_send_action(_act("shoot"), false)
	_layer.visible = _in_game()
	_layer.queue_redraw()


func _release_all() -> void:
	_stick_finger = -1
	_stick_vec = Vector2.ZERO
	_apply_stick()
	if _aim_finger >= 0:
		_send_action(_act("shoot"), false)
	_aim_finger = -1
	aiming = false
	for id in _held.keys():
		for b in _all_button_actions():
			if b[0] == id:
				_send_action(_act(b[1]), false)
	_held.clear()


## Press / release an input action the way a key would (events and Input state).
func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _tap_action(action: String) -> void:
	_send_action(action, true)
	_send_action.call_deferred(action, false)


## A finger in a menu or panel acts as the left mouse button at that spot.
func _click(pos: Vector2, pressed: bool) -> void:
	_mouse_motion(pos)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _mouse_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _mouse_finger >= 0 else 0
	Input.parse_input_event(ev)
	Input.warp_mouse(ev.position)


func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


# --- drawing -------------------------------------------------------------------------

func _draw_controls() -> void:
	if not active or not _in_game():
		return
	var f := Art.font()
	var fs := Art.FONT_SIZE
	var base := _stick_origin if _stick_finger >= 0 else STICK_HOME
	var a := 0.45 if _stick_finger >= 0 else 0.18
	_layer.draw_circle(base, STICK_R, Color(1, 1, 1, a * 0.35))
	_layer.draw_arc(base, STICK_R, 0, TAU, 24, Color(1, 1, 1, a), 1.0)
	_layer.draw_circle(base + _stick_vec.limit_length(1.0) * STICK_R, 7.0, Color(1, 1, 1, a + 0.1))
	for b in _buttons():
		var held := _held.has(b[0])
		var fill := Color(1, 0.85, 0.45, 0.45) if held else Color(0.05, 0.06, 0.08, 0.55)
		_layer.draw_circle(b[1], b[2], fill)
		_layer.draw_arc(b[1], b[2], 0, TAU, 24, Color(1, 1, 1, 0.55), 1.0)
		_layer.draw_string(f, b[1] + Vector2(-b[2], 3), b[3], HORIZONTAL_ALIGNMENT_CENTER, b[2] * 2.0, fs,
			Color(1, 1, 1, 0.9))
	if aiming:
		_layer.draw_arc(aim_pos, 6.0, 0, TAU, 16, Color(1, 0.9, 0.6, 0.8), 1.0)
