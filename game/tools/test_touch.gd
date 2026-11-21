extends Node
## Touch controls check (touch.gd) with synthetic fingers, solo game.

var _failed := 0


func _ready() -> void:
	Game.dev["mute"] = true
	Game.dev["savefile"] = "save_test_touch.json"
	get_tree().create_timer(15.0, true, false, true).timeout.connect(func():
		printerr("WATCHDOG_QUIT")
		get_tree().quit(2))
	_run.call_deferred()


func _ok(what: String, cond: bool, info := "") -> void:
	print(("PASS  " if cond else "FAIL  ") + what + ("  (" + info + ")" if info != "" else ""))
	if not cond:
		_failed += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Wait for the input Touch sent to be flushed and seen (it lands with the next frame).
func _settle() -> void:
	for k in 2:
		await get_tree().process_frame
	await get_tree().physics_frame


func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = i
	t.position = pos
	t.pressed = pressed
	Touch._input(t)


func _drag(i: int, pos: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = i
	d.position = pos
	Touch._input(d)


func _run() -> void:
	Game.coop = false
	Game.difficulty = "normal"
	_touch(9, Vector2(5, 5), false)  # any touch turns the controls on
	_ok("touch controls turn on with the first touch", Touch.active)

	var m: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await _frames(2)
	m.load_map("world")
	await _frames(2)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Node2D = Game.player

	# stick: finger down on the left, drag right
	var start := p.global_position
	_touch(0, Vector2(40, 140), true)
	_drag(0, Vector2(60, 140))
	await _frames(20)
	_ok("stick drag right moves Johnny right", p.global_position.x - start.x > 10.0, "%.1f" % (p.global_position.x - start.x))
	_touch(0, Vector2(60, 140), false)
	await _frames(2)
	var stop_at := p.global_position
	await _frames(10)
	_ok("letting go of the stick stops him", p.global_position.distance_to(stop_at) < 1.0)

	# aim side: tap above-right of Johnny shoots there
	Game.has_pistol = true
	Game.ammo = 5
	p.set("_fire_cd", 0.0)
	var screen_p: Vector2 = p.get_global_transform_with_canvas().origin
	var tap := screen_p + Vector2(60, -30)
	tap.x = maxf(tap.x, 200.0)
	_touch(1, tap, true)
	await _frames(2)
	_ok("tap on the right shoots", Game.ammo == 4, str(Game.ammo))
	var shot: Node = null
	for n in m.level.entities.get_children():
		if "direction" in n and n.get("visual") == false:
			shot = n
	var want: Vector2 = (Touch.aim_world() - (p.global_position + Vector2(0, -6))).normalized()
	_ok("the shot flies toward the finger", shot != null and shot.direction.dot(want) > 0.95)
	_ok("the flashlight follows the finger", Touch.aiming)
	_touch(1, tap, false)
	await _frames(2)
	_ok("letting go stops aiming", not Touch.aiming and not Input.is_action_pressed("shoot"))

	# E button presses interact
	var got := [false]
	var watcher := func(ev: InputEvent): if ev.is_action_pressed("interact"): got[0] = true
	var probe := _Probe.new()
	probe.cb = watcher
	add_child(probe)
	_touch(2, Vector2(266, 148), true)
	await _settle()
	_ok("E button presses interact", got[0] and Input.is_action_pressed("interact"))
	_touch(2, Vector2(266, 148), false)
	await _settle()
	_ok("E released", not Input.is_action_pressed("interact"))
	m.hud.dialog._queue.clear()
	m.hud.dialog._next()  # no dialog line: the big button is CIOS, not OK
	_touch(2, Vector2(296, 128), true)
	await _settle()
	_ok("the big button punches", Input.is_action_pressed("melee"))
	_touch(2, Vector2(296, 128), false)
	await _settle()

	# pause: the II button opens it, tapping "wróć" closes it
	_touch(3, Vector2(112, 10), true)
	await _frames(1)
	_touch(3, Vector2(112, 10), false)
	for k in 3:
		await get_tree().process_frame
	_ok("II button opens the pause menu", Game.menu_open and get_tree().paused)
	if DisplayServer.get_name() != "headless":
		var pm: Node = get_tree().get_first_node_in_group("pause_menu")
		var resume_at: Vector2 = pm._row_rect(0).get_center()
		_touch(3, resume_at, true)
		for k in 3:
			await get_tree().process_frame
		_touch(3, resume_at, false)
		for k in 3:
			await get_tree().process_frame
		_ok("tapping 'wróć' closes the pause menu", not Game.menu_open and not get_tree().paused)
	else:
		get_tree().paused = false
		Game.menu_open = false
	m.queue_free()
	await _frames(3)

	# title: a tap clicks a row
	if DisplayServer.get_name() == "headless":
		print("SKIP  tap on a title row clicks it (headless)")
		print("=== TOUCH TEST DONE: %d failed ===" % _failed)
		get_tree().quit(1 if _failed > 0 else 0)
		return
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var before := Game.coop
	var y: float = title.ROW_Y["players"] - 4
	_touch(0, Vector2(160, y), true)
	for k in 3:
		await get_tree().process_frame  # emulated clicks arrive with the next input flush
	_touch(0, Vector2(160, y), false)
	for k in 3:
		await get_tree().process_frame
	_ok("tap on a title row clicks it", Game.coop != before)
	title.queue_free()

	print("=== TOUCH TEST DONE: %d failed ===" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


class _Probe extends Node:
	var cb: Callable

	func _input(ev: InputEvent) -> void:
		cb.call(ev)
