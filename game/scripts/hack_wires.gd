extends Control
## Antenna 3 mini-game ("kable").

const PANEL := Vector2(124, 112)
const COLORS := [Color("ff4a3a"), Color("ffd23c"), Color("4a8aff"), Color("4fdf6f")]
const LEFT_X := 14.0
const RIGHT_X := 108.0
const TOP_Y := 26.0
const STEP := 16.0

var antenna: Node = null
var player: Node = null
var active := false
## sockets[i] = colour index of the socket in row i (right side).
var sockets: Array[int] = []
## links[left row] = right row (or -1).
var links: Array[int] = []
var picked := -1   # left row being carried
var cursor := 0
var _seed := -1
var _open_t := 0.0
var _flash := 0.0
var _sparks: Array = []


func _ready() -> void:
	add_to_group("hack_ui")
	visible = false
	custom_minimum_size = PANEL
	size = PANEL


func open(a: Node, p: Node) -> void:
	if Game.is_hard() or a.minigame != "wires":
		return
	antenna = a
	player = p
	if _seed != a.maze_seed:
		_seed = a.maze_seed
		_reset(_seed)
	visible = true
	active = true
	_open_t = 0.25
	p.set_hacking(true)
	Sfx.play("beep")


func close() -> void:
	visible = false
	active = false
	picked = -1
	if is_instance_valid(player):
		player.set_hacking(false)


func _reset(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	sockets = [0, 1, 2, 3]
	while sockets[0] == 0 and sockets[1] == 1 and sockets[2] == 2:
		for i in range(sockets.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := sockets[i]
			sockets[i] = sockets[j]
			sockets[j] = tmp
	links = [-1, -1, -1, -1]
	picked = -1
	cursor = 0


func _left_pos(i: int) -> Vector2:
	return Vector2(LEFT_X, TOP_Y + i * STEP)


func _right_pos(i: int) -> Vector2:
	return Vector2(RIGHT_X, TOP_Y + i * STEP)


func _process(delta: float) -> void:
	if not active:
		return
	_flash = maxf(_flash - delta, 0.0)
	_open_t -= delta
	for s in _sparks:
		s[0] += s[1] * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)
	if not is_instance_valid(player) or player.dead:
		close()
		return
	if _open_t <= 0.0 and (Input.is_action_just_pressed(Game.action_for(player, "interact")) or Input.is_action_just_pressed("back")):
		close()
		return
	if Input.is_action_just_pressed(Game.action_for(player, "move_up")):
		cursor = wrapi(cursor - 1, 0, 4)
	if Input.is_action_just_pressed(Game.action_for(player, "move_down")):
		cursor = wrapi(cursor + 1, 0, 4)
	if _open_t <= 0.0 and Input.is_action_just_pressed(Game.action_for(player, "accept")):
		if picked < 0:
			pick(cursor)
		else:
			plug(cursor)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not active or _open_t > 0.0:
		return
	if Game.is_shared_p2(player):
		return  # the mouse belongs to P1
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = make_input_local(event).position
		for i in 4:
			if m.distance_to(_left_pos(i)) < 8.0:
				pick(i)
				return
			if m.distance_to(_right_pos(i)) < 8.0 and picked >= 0:
				plug(i)
				return


## Take the wire from left row `i` (re-plugging a connected one is allowed).
func pick(i: int) -> void:
	picked = i
	links[i] = -1
	cursor = i
	Sfx.play("beep", 0.1, -12.0)


## Plug the carried wire into right socket `j`.
func plug(j: int) -> void:
	if picked < 0:
		return
	if links.has(j):
		links[links.find(j)] = -1
	if sockets[j] == picked:
		links[picked] = j
		Sfx.play("confirm", 0.05, -6.0)
		picked = -1
		if not links.has(-1):
			_success()
	else:
		_spark(_right_pos(j))
		for k in links.size():
			links[k] = -1
		picked = -1
		_flash = 0.4
		Game.add_error()


func _spark(at: Vector2) -> void:
	for i in 10:
		_sparks.append([at, Vector2.from_angle(randf() * TAU) * randf_range(20, 60), randf_range(0.2, 0.45)])


func _success() -> void:
	var a := antenna
	close()
	_seed = -1
	a.on_hacked()


## Dev/test helper: right row of the socket matching left wire `i`.
func debug_socket_for(i: int) -> int:
	return sockets.find(i)


func _draw() -> void:
	var bg := Color(0.1, 0.04, 0.04, 0.92) if _flash <= 0.0 else Color(0.35, 0.08, 0.05, 0.95)
	draw_rect(Rect2(Vector2.ZERO, PANEL), bg)
	draw_rect(Rect2(Vector2.ZERO, PANEL), Color("bf5a3a"), false, 1.0)
	var f := Art.font()
	draw_string(f, Vector2(5, 11), "ODETNIJ ZASILANIE", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("ffb090"))
	for i in 4:
		var lp := _left_pos(i)
		var rp := _right_pos(i)
		var sel := Color(1, 1, 1, 0.8) if cursor == i else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(lp - Vector2(6, 5), Vector2(12, 10)), Color("1a1414"))
		draw_rect(Rect2(lp - Vector2(4, 3), Vector2(8, 6)), COLORS[i])
		draw_rect(Rect2(rp - Vector2(6, 5), Vector2(12, 10)), Color("1a1414"))
		draw_rect(Rect2(rp - Vector2(4, 3), Vector2(8, 6)), COLORS[sockets[i]].darkened(0.35))
		draw_rect(Rect2(rp - Vector2(2, 1), Vector2(4, 2)), Color("050505"))
		if picked < 0:
			draw_rect(Rect2(lp - Vector2(7, 6), Vector2(14, 12)), sel, false, 1.0)
		else:
			draw_rect(Rect2(rp - Vector2(7, 6), Vector2(14, 12)), sel, false, 1.0)
		if links[i] >= 0:
			_wire(lp, _right_pos(links[i]), COLORS[i])
	if picked >= 0:
		# Carried wire follows the mouse inside the panel, otherwise the keyboard cursor.
		var m := get_local_mouse_position()
		var to := m if Rect2(Vector2.ZERO, PANEL).has_point(m) else _right_pos(cursor) - Vector2(8, 0)
		_wire(_left_pos(picked), to, COLORS[picked])
	for s in _sparks:
		draw_rect(Rect2(s[0], Vector2(1, 1)), Color(1, 0.9, 0.4, clampf(s[2] * 3.0, 0, 1)))
	draw_string(f, Vector2(5, PANEL.y - 9), "LPM / W S SPACJA", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("cf8a72"))
	draw_string(f, Vector2(5, PANEL.y - 1), "E: odejdź", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("cf8a72"))


func _wire(a: Vector2, b: Vector2, c: Color) -> void:
	var mid := (a + b) / 2.0 + Vector2(0, 6)
	var pts := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, c.darkened(0.4), 3.0)
	draw_polyline(pts, c, 1.0)
