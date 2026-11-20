class_name DevTools
extends Node
## Dev helpers driven by command-line user args (after `--`).

var main: Node2D
var _results: Array[String] = []
var _failed := 0


static func attach(m: Node2D) -> void:
	if Game.dev.is_empty():
		return
	var d := DevTools.new()
	d.main = m
	d.name = "DevTools"
	m.add_child(d)


func _ready() -> void:
	var p: Node2D = main.player
	if Game.dev.has("warp"):
		var parts: PackedStringArray = str(Game.dev["warp"]).split(",")
		p.global_position = main.level.feet(int(parts[0]), int(parts[1]))
		p.camera.reset_smoothing()
	if Game.dev.has("cable"):
		Game.has_cable = true
	if Game.dev.has("autotest"):
		_autotest.call_deferred()
	elif Game.dev.has("hack"):
		_open_hack.call_deferred()


func _open_hack() -> void:
	await _wait(0.3)
	Game.has_cable = true
	Game.antennas[0].interact(main.player)
	var hack: Node = get_tree().get_first_node_in_group("hack_ui")
	await _wait(0.3)
	# Steer a bit into the maze so the screenshot shows the trail.
	for i in 20:
		hack.dot += Vector2(1.0, 0)
		hack._trail.append(hack.dot)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout


func _check(what: String, ok: bool, info := "") -> void:
	var line := ("PASS  " if ok else "FAIL  ") + what + ("  (" + info + ")" if info != "" else "")
	_results.append(line)
	print(line)
	if not ok:
		_failed += 1


func _autotest() -> void:
	var p: CharacterBody2D = main.player
	var level = main.level
	print("AUTOTEST start")
	await _wait(1.0)
	_check("level built", level.width > 100 and level.height > 20, "%dx%d" % [level.width, level.height])
	_check("player on floor at start", p.is_on_floor(), str(p.global_position))
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check("enemies spawned", enemies.size() >= 10, str(enemies.size()))
	_check("burnt mutants present", enemies.any(func(e): return e.burnt))
	_check("one antenna registered", Game.antennas.size() == 1)
	_check("bushes spawned", get_tree().get_nodes_in_group("bushes").size() >= 5)
	_check("start ammo = 14", Game.ammo == 14)

	# --- shooting ---
	var target: Node2D = enemies[0]
	for e in enemies:
		e.set_physics_process(e == target)
	target.global_position = p.global_position + Vector2(40, 0)
	target.velocity = Vector2.ZERO
	p.facing = 1
	var hp_before: int = target.hp
	for i in 3:
		p._fire_cd = 0.0
		p.shoot()
		await _wait(0.2)
	_check("pistol uses ammo", Game.ammo == 11, str(Game.ammo))
	_check("bullets hurt mutants", not is_instance_valid(target) or target.hp < hp_before or target.state == target.State.DEAD)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(true)

	# --- melee ---
	var victim: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	victim.set_physics_process(false)
	victim.global_position = p.global_position + Vector2(12, 0)
	var vhp: int = victim.hp
	p._melee_cd = 0.0
	p.melee()
	_check("melee hits", victim.hp < vhp)
	victim.set_physics_process(true)

	# --- mutant AI: noise alerts it, it chases and bites ---
	var hunter: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	p.global_position = level.feet(8, 25)
	hunter.global_position = level.feet(16, 25)
	hunter.velocity = Vector2.ZERO
	hunter.state = hunter.State.PATROL
	await get_tree().physics_frame
	Game.make_noise(p.global_position, 150.0)
	var hp0: int = p.hp
	var waited := 0.0
	while waited < 5.0 and p.hp == hp0:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	_check("noise alerts mutant, it chases and bites", p.hp < hp0, "%.1fs" % waited)
	p.heal(100)

	# --- signal bars near antenna ---
	var antenna: Node2D = Game.antennas[0]
	var far := Game.bars
	p.global_position = antenna.global_position + Vector2(-30, -4)
	await _wait(0.3)
	_check("bars rise near antenna", Game.bars >= 4 and Game.bars > far, "%d -> %d" % [far, Game.bars])
	var e2: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	var r_far := Game.detection_radius(e2.detect_base, e2.detect_per_bar)
	_check("detection radius grows with bars", r_far > e2.detect_base + 60.0, str(r_far))

	# --- hacking ---
	Game.dev["god"] = true
	antenna.interact(p)
	await _wait(0.1)
	_check("no hacking without cable", not p.hacking)
	Game.has_cable = true
	antenna.interact(p)
	await _wait(0.4)
	var hack: Node = get_tree().get_first_node_in_group("hack_ui")
	_check("hack panel opens", hack.visible and p.hacking and Game.hacking)
	_check("maze generated", hack.walls.size() > 20, str(hack.walls.size()))
	hack.dot = hack.start
	var err_before := Game.error_boost
	hack._fail()
	_check("maze error raises bars", Game.error_boost > err_before)
	var path: PackedVector2Array = hack.debug_solve()
	_check("maze solvable with real collision", path.size() > 2, "%d points" % path.size())
	var touched := false
	hack.dot = hack.start
	for waypoint in path:
		while hack.active and hack.dot.distance_to(waypoint) > 0.01:
			if not hack.debug_step(waypoint, 1.0 / 60.0):
				touched = true
				break
			await get_tree().physics_frame
		if touched or not hack.active:
			break
	_check("maze walked start -> switch without touching walls", not touched and antenna.disabled)
	await _wait(0.2)
	_check("antenna disabled", antenna.disabled and Game.disabled_count == 1)
	_check("player released from panel", not p.hacking)
	_check("respawn moved to antenna", Game.respawn_point.distance_to(antenna.global_position) < 40.0)

	# --- death + respawn ---
	Game.dev.erase("god")
	p._invuln = 0.0
	p.take_damage(999, p.global_position + Vector2(10, 0))
	_check("player dies", p.dead)
	await _wait(3.4)
	_check("player respawns", not p.dead and p.hp == p.MAX_HP)
	_check("respawn at antenna", p.global_position.distance_to(Game.respawn_point) < 24.0, str(p.global_position))

	# --- ending ---
	var plane: Node = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("prompt") and n.prompt() == "[E] Samolot":
			plane = n
	_check("plane exists", plane != null)
	if plane:
		reparent(get_tree().root)  # survive the scene change
		plane.interact(p)
		await _wait(2.0)
		var cur := get_tree().current_scene
		_check("ending scene loads", cur != null and cur.scene_file_path.ends_with("ending.tscn"), str(cur.scene_file_path) if cur else "null")
	print("AUTOTEST done: %d failed" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
