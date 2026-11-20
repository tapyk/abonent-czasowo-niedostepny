extends Control
## Antenna 2 mini-game ("pierścienie"): concentric rings spin in different directions.

const PANEL := Vector2(124, 112)
const CENTER := Vector2(62, 58)
const RADII := [38.0, 28.0, 18.0]
const THICK := 6.0
const TOL := 0.24          # radians either side of the marker
const BASE_SPEEDS := [1.5, -2.0, 2.6]
const TARGET := -PI / 2.0  # straight up

var antenna: Node = null
var player: Node = null
var active := false
var angles: Array[float] = []
var speeds: Array[float] = []
var locked: Array[bool] = []
var current := 0
var _seed := -1
var _open_t := 0.0
var _flash := 0.0
var _good := 0.0


func _ready() -> void:
	add_to_group("hack_ui")
	visible = false
	custom_minimum_size = PANEL
	size = PANEL


func open(a: Node, p: Node) -> void:
	if a.minigame != "rings":
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
	if is_instance_valid(player):
		player.set_hacking(false)


func _reset(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var diff := 1.0 + 0.15 * Game.disabled_count
	angles.clear(); speeds.clear(); locked.clear()
	for i in RADII.size():
		angles.append(rng.randf_range(0.0, TAU))
		speeds.append(BASE_SPEEDS[i] * diff)
		locked.append(false)
	current = 0


func is_aligned(i: int) -> bool:
	return absf(angle_difference(angles[i], TARGET)) <= TOL


func _process(delta: float) -> void:
	if not active:
		return
	_flash = maxf(_flash - delta, 0.0)
	_good = maxf(_good - delta, 0.0)
	_open_t -= delta
	if not is_instance_valid(player) or player.dead:
		close()
		return
	if _open_t <= 0.0 and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("back")):
		close()
		return
	for i in RADII.size():
		if not locked[i]:
			angles[i] = wrapf(angles[i] + speeds[i] * delta, -PI, PI)
	if _open_t <= 0.0 and (Input.is_action_just_pressed("accept") or Input.is_action_just_pressed("shoot")):
		press()
	queue_redraw()


## Try to stop the current ring.
func press() -> void:
	if not active or current >= RADII.size():
		return
	if is_aligned(current):
		angles[current] = TARGET
		locked[current] = true
		current += 1
		_good = 0.3
		Sfx.play("confirm", 0.05, -6.0)
		if current >= RADII.size():
			_success()
	else:
		_flash = 0.35
		Game.add_error()
		if current > 0:
			current -= 1
			locked[current] = false


func _success() -> void:
	var a := antenna
	close()
	_seed = -1
	a.on_hacked()


## Dev/test helper: put the current ring under the marker.
func debug_align() -> void:
	if current < RADII.size():
		angles[current] = TARGET + 0.05


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PANEL), Color(0.05, 0.05, 0.1, 0.92))
	draw_rect(Rect2(Vector2.ZERO, PANEL), Color("5a6abf"), false, 1.0)
	var f := Art.font()
	draw_string(f, Vector2(5, 11), "ROZSTRÓJ ANTENĘ", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("a0b0ff"))
	# marker
	var top := CENTER + Vector2(0, -RADII[0] - THICK)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-4, -6), top + Vector2(4, -6), top]), Color("ffd23c"))
	draw_line(CENTER, CENTER + Vector2(0, -RADII[0]), Color(1, 0.85, 0.3, 0.15), 1.0)
	for i in RADII.size():
		var r: float = RADII[i]
		var base := Color("3a4a8a")
		if locked[i]:
			base = Color("4fbf6f")
		elif i == current:
			base = Color("ff5050") if _flash > 0.0 else Color("6a7adf")
		# segmented ring: 8 pieces with gaps, pattern rotates with the ring
		for s in 8:
			var a0: float = angles[i] + s * TAU / 8.0 + 0.12
			draw_arc(CENTER, r, a0, a0 + TAU / 8.0 - 0.24, 6, base, THICK)
		# notch (the piece of the pattern that has to sit under the marker)
		var notch := Color("ffe08a") if i == current or locked[i] else Color("a09060")
		draw_arc(CENTER, r, angles[i] - 0.2, angles[i] + 0.2, 4, notch, THICK + 1.0)
	draw_circle(CENTER, 6.0, Color("8fe0a0") if current >= RADII.size() else Color("2a2a3a"))
	if _good > 0.0:
		draw_circle(CENTER, 9.0, Color(0.5, 1.0, 0.6, _good))
	draw_string(f, Vector2(5, PANEL.y - 9), "SPACJA/LPM: stop", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("8a92cf"))
	draw_string(f, Vector2(5, PANEL.y - 1), "E: odejdź", HORIZONTAL_ALIGNMENT_LEFT, -1, Art.FONT_SIZE, Color("8a92cf"))
