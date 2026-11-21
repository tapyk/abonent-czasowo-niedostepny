extends Control
## Antenna 1 mini-game.

const COLS := 8
const ROWS := 6
const CELL := 12
const WALL := 2
const DOT := 3.0
const SPEED := 34.0
const PANEL := Vector2(124, 112)
const ORIGIN := Vector2(10, 16)  # maze top-left inside the panel

var walls: Array[Rect2] = []
var start := Vector2.ZERO
var goal := Rect2()
var dot := Vector2.ZERO
var antenna: Node = null
var player: Node = null
var active := false
var _open_t := 0.0
var _flash := 0.0
var _seed := -1
var _trail: PackedVector2Array = []


func _ready() -> void:
	add_to_group("hack_ui")
	visible = false
	custom_minimum_size = PANEL
	size = PANEL


func open(a: Node, p: Node) -> void:
	if Game.is_hard() or a.minigame != "maze":
		return
	antenna = a
	player = p
	if _seed != a.maze_seed:
		_seed = a.maze_seed
		_generate(_seed)
		dot = start
		_trail.clear()
	visible = true
	active = true
	_open_t = 0.25
	p.set_hacking(true)
	Sfx.play("beep")


func close() -> void:
	visible = false
	active = false
	if is_instance_valid(player):
		player.set_hacking(false)


func _process(delta: float) -> void:
	if not active:
		return
	_flash = maxf(_flash - delta, 0.0)
	_open_t -= delta
	if not is_instance_valid(player) or player.dead:
		close()
		return
	var local_split := Game.coop and not SteamNet.is_online_coop()
	var is_p2 := local_split and player == Game.player2
	var leave := Input.is_action_just_pressed("back") or Input.is_action_just_pressed("p2_interact" if is_p2 else ("p1_interact" if local_split else "interact"))
	if _open_t <= 0.0 and leave:
		close()
		return
	var v := Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down") if is_p2 else (
		Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down") if local_split else
		Input.get_vector("move_left", "move_right", "move_up", "move_down")
	)
	if v != Vector2.ZERO:
		var next := dot + v * SPEED * delta
		if _hits_wall(next):
			_fail()
		else:
			dot = next
			if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(dot) > 2.0:
				_trail.append(dot)
		if goal.has_point(dot):
			_success()
	queue_redraw()


func _fail() -> void:
	dot = start
	_trail.clear()
	_flash = 0.35
	Game.add_error()


func _success() -> void:
	var a := antenna
	close()
	a.on_hacked()


func _hits_wall(p: Vector2) -> bool:
	var r := Rect2(p - Vector2(DOT, DOT) / 2.0, Vector2(DOT, DOT))
	for w in walls:
		if w.intersects(r):
			return true
	return false


## Recursive-backtracker maze -> list of wall rectangles (panel coordinates).
func _generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# right[x][y] / down[x][y] = wall present
	var right := []
	var down := []
	var seen := []
	for x in COLS:
		right.append([]); down.append([]); seen.append([])
		for y in ROWS:
			right[x].append(true); down[x].append(true); seen[x].append(false)
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	seen[0][0] = true
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts: Array[Vector2i] = []
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var nb: Vector2i = c + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < COLS and nb.y < ROWS and not seen[nb.x][nb.y]:
				opts.append(nb)
		if opts.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
		if n.x > c.x: right[c.x][c.y] = false
		elif n.x < c.x: right[n.x][n.y] = false
		elif n.y > c.y: down[c.x][c.y] = false
		else: down[n.x][n.y] = false
		seen[n.x][n.y] = true
		stack.append(n)

	walls.clear()
	var w := COLS * CELL
	var h := ROWS * CELL
	var o := ORIGIN
	walls.append(Rect2(o + Vector2(-WALL, -WALL), Vector2(w + WALL * 2, WALL)))      # top
	walls.append(Rect2(o + Vector2(-WALL, h), Vector2(w + WALL * 2, WALL)))           # bottom
	walls.append(Rect2(o + Vector2(-WALL, CELL), Vector2(WALL, h - CELL)))            # left (entry gap at row 0)
	walls.append(Rect2(o + Vector2(w, 0), Vector2(WALL, h - CELL)))                   # right (exit gap at last row)
	for x in COLS:
		for y in ROWS:
			var cell_pos := o + Vector2(x * CELL, y * CELL)
			if right[x][y] and x < COLS - 1:
				walls.append(Rect2(cell_pos + Vector2(CELL - WALL / 2.0, -WALL / 2.0), Vector2(WALL, CELL + WALL)))
			if down[x][y] and y < ROWS - 1:
				walls.append(Rect2(cell_pos + Vector2(-WALL / 2.0, CELL - WALL / 2.0), Vector2(CELL + WALL, WALL)))
	start = o + Vector2(CELL / 2.0 - 3.0, CELL / 2.0)
	goal = Rect2(o + Vector2(w, h - CELL + 1), Vector2(10, CELL - 2))


## Dev/test helper.
func debug_solve() -> PackedVector2Array:
	var center := func(c: Vector2i) -> Vector2: return ORIGIN + Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)
	var prev := {Vector2i(0, 0): Vector2i(-1, -1)}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var goal_cell := Vector2i(COLS - 1, ROWS - 1)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal_cell:
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS or prev.has(n):
				continue
			var a: Vector2 = center.call(c)
			var b: Vector2 = center.call(n)
			var clear := true
			for i in 13:
				if _hits_wall(a.lerp(b, i / 12.0)):
					clear = false
					break
			if clear:
				prev[n] = c
				queue.append(n)
	if not prev.has(goal_cell):
		return PackedVector2Array()
	var pts := PackedVector2Array()
	var cur := goal_cell
	while cur != Vector2i(-1, -1):
		pts.insert(0, center.call(cur))
		cur = prev[cur]
	pts.append(goal.get_center())
	return pts


## Dev/test helper: move the dot toward `target` like the player would.
func debug_step(target: Vector2, delta: float) -> bool:
	var next := dot.move_toward(target, SPEED * delta)
	if _hits_wall(next):
		_fail()
		return false
	dot = next
	_trail.append(dot)
	if goal.has_point(dot):
		_success()
	return true


func _draw() -> void:
	var bg := Color(0.04, 0.09, 0.06, 0.92)
	draw_rect(Rect2(Vector2.ZERO, PANEL), bg)
	draw_rect(Rect2(Vector2.ZERO, PANEL), Color("3f8f5a"), false, 1.0)
	var f := Art.font()
	draw_string(f, Vector2(5, 11), "PANEL ANTENY", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("8fe0a0"))
	var wall_col := Color("ff5050") if _flash > 0.0 else Color("47c46b")
	for wr in walls:
		draw_rect(wr, wall_col)
	# kill switch
	draw_rect(goal, Color("ffd23c"))
	# trail + signal dot
	for p in _trail:
		draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.6, 0.9, 1.0, 0.5))
	draw_rect(Rect2(dot - Vector2(DOT, DOT) / 2.0, Vector2(DOT, DOT)), Color("bff3ff"))
	draw_string(f, Vector2(5, PANEL.y - 9), "WSAD: sygnał", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("6fae7f"))
	draw_string(f, Vector2(5, PANEL.y - 1), "E: odejdź", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("6fae7f"))
