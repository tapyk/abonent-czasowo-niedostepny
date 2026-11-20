class_name DevTools
extends Node
## Dev helpers driven by command-line user args (after `--`).

var main: Node2D
var _failed := 0


static func attach(m: Node2D) -> void:
	if Game.dev.is_empty():
		return
	var d := DevTools.new()
	d.main = m
	d.name = "DevTools"
	m.add_child(d)


func _ready() -> void:
	if Game.dev.has("pistol"):
		Game.has_pistol = true
		Game.ammo = Game.START_AMMO
	Game.has_sekator = Game.has_sekator or Game.dev.has("sekator")
	Game.has_cable = Game.has_cable or Game.dev.has("cable")
	if Game.dev.has("warp"):
		var parts: PackedStringArray = str(Game.dev["warp"]).split(",")
		main.player.global_position = main.level.feet(int(parts[0]), int(parts[1]))
		main.player.camera.reset_smoothing()
	Game.stats_changed.emit()
	if Game.dev.has("autotest"):
		_autotest.call_deferred()
	elif Game.dev.has("hack"):
		_open_hack.call_deferred()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _open_hack() -> void:
	await _wait(0.3)
	Game.has_cable = true
	Game.antennas[0].interact(main.player)
	var hack: Node = get_tree().get_first_node_in_group("hack_ui")
	await _wait(0.3)
	for i in 20:
		hack.dot += Vector2(1.0, 0)
		hack._trail.append(hack.dot)


func _check(what: String, ok: bool, info := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + what + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_failed += 1


func _find(group: String, pred: Callable) -> Node:
	for n in get_tree().get_nodes_in_group(group):
		if pred.call(n):
			return n
	return null


func _find_child(pred: Callable) -> Node:
	for n in main.level.entities.get_children():
		if pred.call(n):
			return n
	return null


## Walk the player into a warp tile and wait for the map change.
func _use_warp(target_map: String) -> void:
	var w: Node = _find_child(func(n): return n.get_script() == preload("res://scripts/warp.gd") and n.target_map == target_map)
	if w == null:
		_check("warp to %s exists" % target_map, false)
		return
	main.player.global_position = w.global_position + Vector2(0, 3)
	await _wait(1.0)


func _autotest() -> void:
	var p: CharacterBody2D = main.player
	print("AUTOTEST start")
	await _wait(0.5)

	# --- home: pistol gate ---
	_check("starts at home", Game.current_map == "home")
	_check("no pistol at start", not Game.has_pistol and Game.ammo == 0)
	await _use_warp("world")
	_check("can't leave home without pistol", Game.current_map == "home")
	var pistol := _find_child(func(n): return "kind" in n and n.kind == "pistol")
	_check("pistol lies at home", pistol != null)
	p.global_position = pistol.global_position
	await _frames(3)
	_check("pistol picked up, 14 rounds", Game.has_pistol and Game.ammo == 14, str(Game.ammo))
	_check("first mutant in the stairwell", get_tree().get_nodes_in_group("enemies").size() >= 1)
	Game.dev["god"] = true
	await _use_warp("world")
	_check("stairs lead to the estate", Game.current_map == "world")
	_check("player placed in world", main.level.bounds().has_point(p.global_position), str(p.global_position))

	# --- world content ---
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check("mutants in the world", enemies.size() >= 15, str(enemies.size()))
	_check("burnt mutants present", enemies.any(func(e): return e.burnt))
	_check("bushes spawned", get_tree().get_nodes_in_group("bushes").size() >= 15)
	_check("antenna mast is a signal source", Game.antennas.size() == 1)
	var thicket := _find("interactable", func(n): return n.get_script() == preload("res://scripts/thicket.gd"))
	var horde := _find("interactable", func(n): return n.get_script() == preload("res://scripts/horde.gd"))
	_check("thicket and horde gates exist", thicket != null and horde != null)

	# --- shooting & melee (enemies frozen for determinism) ---
	for e in enemies:
		e.set_physics_process(false)
	var target: Node2D = enemies[0]
	p.global_position = main.level.feet(10, 16)
	target.global_position = p.global_position + Vector2(40, 0)
	p.facing = Vector2.RIGHT
	p._animate(Vector2.ZERO)
	var hp_before: int = target.hp
	for i in 3:
		p._fire_cd = 0.0
		p.shoot()
		await _wait(0.2)
	_check("pistol uses ammo", Game.ammo == 11, str(Game.ammo))
	_check("bullets hurt mutants", not is_instance_valid(target) or target.hp < hp_before or target.state == target.State.DEAD)
	var victim: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	victim.global_position = p.global_position + Vector2(0, 12)
	p.facing = Vector2.DOWN
	var vhp: int = victim.hp
	p._melee_cd = 0.0
	p.melee()
	_check("melee hits in facing direction", victim.hp < vhp)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(true)

	# --- mutant AI ---
	Game.dev.erase("god")
	var hunter: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	p.global_position = main.level.feet(14, 33)
	hunter.global_position = main.level.feet(14, 29)
	hunter.state = hunter.State.WANDER
	await _frames(2)
	Game.make_noise(p.global_position, 150.0)
	var hp0: int = p.hp
	var waited := 0.0
	while waited < 5.0 and p.hp == hp0:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	_check("noise alerts mutant, it chases and bites", p.hp < hp0, "%.1fs" % waited)
	p.heal(100)
	Game.dev["god"] = true

	# --- thicket gate ---
	thicket.interact(p)
	await _frames(2)
	_check("thicket blocks without shears", is_instance_valid(thicket) and thicket.collision_layer == 1)
	var shears := _find_child(func(n): return "kind" in n and n.kind == "sekator")
	_check("shears lie in the garages", shears != null)
	p.global_position = shears.global_position
	await _frames(3)
	_check("shears picked up", Game.has_sekator)
	thicket.interact(p)
	await _wait(0.4)
	_check("thicket cut with shears", not is_instance_valid(thicket))
	horde.interact(p)
	_check("horde still blocks the east road", is_instance_valid(horde))

	# --- roof: antenna ---
	await _use_warp("roof")
	_check("block door leads to the roof", Game.current_map == "roof")
	var antenna: Node2D = Game.antennas[0]
	_check("roof antenna is hackable", antenna.hackable and not antenna.disabled)
	p.global_position = antenna.global_position + Vector2(14, 16)
	await _wait(0.3)
	_check("bars high near antenna", Game.bars >= 4, str(Game.bars))
	antenna.interact(p)
	await _wait(0.1)
	_check("no hacking without cable", not p.hacking)
	var tech := _find("interactable", func(n): return "kind" in n and n.kind == "cable")
	_check("dead technician has the cable", tech != null)
	tech.interact(p)
	_check("cable taken", Game.has_cable)
	antenna.interact(p)
	await _wait(0.4)
	var hack: Node = get_tree().get_first_node_in_group("hack_ui")
	_check("hack panel opens", hack.visible and p.hacking)
	var err := Game.error_boost
	hack._fail()
	_check("maze error raises bars", Game.error_boost > err)
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
	_check("maze walked to the switch without touching walls", not touched and antenna.disabled)
	_check("antenna 1 off, respawn moved to roof", Game.is_antenna_off("a1") and Game.respawn_map == "roof")

	# --- death + respawn ---
	Game.dev.erase("god")
	p._invuln = 0.0
	p.take_damage(999, p.global_position + Vector2(10, 0))
	_check("player dies", p.dead)
	await _wait(3.6)
	_check("player respawns on the roof", not p.dead and p.hp == p.MAX_HP and Game.current_map == "roof")
	Game.dev["god"] = true

	# --- horde gone, east open, plane ---
	await _use_warp("world")
	_check("back in the world", Game.current_map == "world")
	horde = _find("interactable", func(n): return n.get_script() == preload("res://scripts/horde.gd"))
	_check("horde left after antenna went silent", horde == null)
	_check("cut thicket stays cut", _find("interactable", func(n): return n.get_script() == preload("res://scripts/thicket.gd")) == null)
	var plane := _find("interactable", func(n): return n.has_method("prompt") and n.prompt() == "[E] Samolot")
	_check("plane at the airfield", plane != null)
	if plane:
		reparent(get_tree().root)  # survive the scene change
		plane.interact(p)
		await _wait(2.0)
		var cur := get_tree().current_scene
		_check("ending scene loads", cur != null and cur.scene_file_path.ends_with("ending.tscn"))
	print("AUTOTEST done: %d failed" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
