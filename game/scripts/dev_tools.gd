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
	Game.save_state()  # dev-given items survive a death
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
	var hack: Node = _find("hack_ui", func(n): return n.get_script() == preload("res://scripts/hack_maze.gd"))
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
	_check("without a pistol LPM punches instead of shooting", not p.can_shoot())
	_check("no checkpoint yet: death returns to start stats",
		Game._saved.ammo == 0 and Game._saved.parts == 0 and not Game._saved.has_pistol and Game._saved.gone.is_empty())
	var start := p.global_position
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _wait(0.3)
	Input.action_release("move_right")
	Input.action_release("move_down")
	var moved := p.global_position - start
	_check("walks diagonally", moved.x > 6.0 and absf(moved.x - moved.y) < 2.0, str(moved))
	var to_mouse := p.get_global_mouse_position() - (p.global_position + Vector2(0, -6))
	_check("flashlight points at the mouse cursor",
		absf(angle_difference(p.facing_node.rotation, to_mouse.angle())) < 0.1,
		"%.2f vs %.2f" % [p.facing_node.rotation, to_mouse.angle()])
	var voice: AudioStreamWAV = Sfx._make_voice(Sfx.VOICES["Mama"], true)
	_check("voice blips synthesized per speaker", voice.data.size() > 1000, str(voice.data.size()))
	await _use_warp("world")
	_check("can't leave home without pistol", Game.current_map == "home")
	var pistol := _find_child(func(n): return "kind" in n and n.kind == "pistol")
	_check("pistol lies at home", pistol != null)
	p.global_position = pistol.global_position
	await _frames(3)
	_check("pistol picked up, 14 rounds", Game.has_pistol and Game.ammo == 14, str(Game.ammo))
	var q: Array = main.hud.dialog._queue.map(func(x): return x[1])
	var i_pistol := q.find("Pistolet taty. Oby się nie przydał.")
	var i_story := q.find("…jestem w domu za jeziorem… zacznij od bloku naprzeciwko…")
	_check("pickup line jumps ahead of queued story lines", i_pistol >= 0 and (i_story < 0 or i_pistol < i_story), str(q))
	_check("control hint shown at once on the HUD", main.hud.hint.text.contains("LPM"), main.hud.hint.text)
	_check("first mutant in the stairwell", get_tree().get_nodes_in_group("enemies").size() >= 1)
	p._fire_cd = 0.0
	p.shoot()
	await _frames(3)
	_check("shooting where there is no network keeps 0 bars", Game.bars == 0, str(Game.bars))
	Game.add_ammo(1)
	var tab: Control = main.hud.tablet
	_check("tablet tucked away until hovered", tab.position.y > tab.base_position.y + 20.0, str(tab.position))
	Game.dev["god"] = true
	await _use_warp("world")
	_check("stairs lead to the estate", Game.current_map == "world")
	_check("player placed in world", main.level.bounds().has_point(p.global_position), str(p.global_position))

	# --- world content ---
	var enemies := get_tree().get_nodes_in_group("enemies")
	_check("mutants in the world", enemies.size() >= 15, str(enemies.size()))
	_check("burnt mutants present", enemies.any(func(e): return e.burnt))
	_check("bushes spawned", get_tree().get_nodes_in_group("bushes").size() >= 15)
	_check("antenna masts (a1 roof, a2 plantation) are signal sources", Game.antennas.size() == 2, str(Game.antennas.size()))
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
	p._fire_cd = 0.0
	var aim := Vector2(1, -1).normalized()
	p.shoot(aim)
	var shot: Node = _find_child(func(n): return "direction" in n and n.direction.is_equal_approx(aim))
	_check("shots fly toward the aim point (mouse), not only 4 directions", shot != null)
	Game.add_ammo(1)
	_check("bullets hurt mutants", not is_instance_valid(target) or target.hp < hp_before or target.state == target.State.DEAD)
	var victim: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	victim.global_position = p.global_position + Vector2(0, 12)
	p.facing = Vector2.DOWN
	var vhp: int = victim.hp
	p._melee_cd = 0.0
	p.melee()
	_check("melee hits in facing direction", victim.hp < vhp)
	var ammo_keep := Game.ammo
	Game.ammo = 0
	vhp = victim.hp
	p._melee_cd = 0.0
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	_check("with no ammo LPM / J punches", victim.hp < vhp and p._melee_cd > 0.0, "%d -> %d" % [vhp, victim.hp])
	Game.ammo = ammo_keep
	Game.stats_changed.emit()
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
	var hack: Node = _find("hack_ui", func(n): return n.get_script() == preload("res://scripts/hack_maze.gd"))
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
	var cp_ammo := Game.ammo
	var cp_parts := Game.parts
	Game.ammo = maxi(cp_ammo - 3, 0)
	Game.add_part()
	Game.mark_gone("roof:test-after-checkpoint")
	Game.flags["test_after_checkpoint"] = true
	Game.dev.erase("god")
	p._invuln = 0.0
	p.take_damage(999, p.global_position + Vector2(10, 0))
	_check("player dies", p.dead)
	await _wait(3.6)
	_check("player respawns on the roof", not p.dead and p.hp == p.MAX_HP and Game.current_map == "roof")
	_check("death rolls ammo and parts back to the checkpoint", Game.ammo == cp_ammo and Game.parts == cp_parts,
		"ammo %d/%d parts %d/%d" % [Game.ammo, cp_ammo, Game.parts, cp_parts])
	_check("death brings back the world since the checkpoint",
		not Game.is_gone("roof:test-after-checkpoint") and not Game.flags.has("test_after_checkpoint"))
	Game.dev["god"] = true

	# --- horde 1 gone, horde 2 still on the road ---
	await _use_warp("world")
	_check("back in the world", Game.current_map == "world")
	var hordes := get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get_script() == preload("res://scripts/horde.gd"))
	_check("horde 1 left after antenna 1 went silent", not hordes.any(func(h): return h.antenna_id == "a1"))
	_check("horde 2 still blocks the road to the crevice", hordes.any(func(h): return h.antenna_id == "a2"))
	_check("cut thicket stays cut", _find("interactable", func(n): return n.get_script() == preload("res://scripts/thicket.gd")) == null)
	_check("no plane on the overworld any more", _find("interactable", func(n): return n.has_method("prompt") and n.prompt() == "[E] Samolot") == null)

	# --- Fast Farmer's barn: no signal, 3 parts -> cables ---
	await _use_warp("stodola")
	_check("barn door leads inside", Game.current_map == "stodola")
	await _wait(0.2)
	_check("no signal in the foil barn (BRAK ZASIĘGU)", Game.bars == 0, str(Game.bars))
	var farmer: Node = _find("npcs", func(n): return n.npc_id == "farmer")
	_check("Fast Farmer is in the barn", farmer != null)
	farmer.talk()
	_check("farmer met, no cables without parts", Game.flags.has("farmer_met") and not Game.has_kable)
	Game.parts = 3
	farmer.talk()
	_check("3 parts traded for the farmer's cables", Game.has_kable and Game.parts == 0, str(Game.parts))
	await _use_warp("world")

	# --- antenna 2: plantation, rings mini-game ---
	var a2: Node = _find("antennas", func(n): return n.antenna_id == "a2")
	_check("antenna 2 stands on the plantation, hackable (rings)", a2 != null and a2.hackable and a2.minigame == "rings")
	p.global_position = a2.get_interact_position() + Vector2(0, 10)
	await _wait(0.2)
	a2.interact(p)
	await _wait(0.4)
	var rings: Node = _find("hack_ui", func(n): return n.get_script() == preload("res://scripts/hack_rings.gd"))
	_check("rings panel opens", rings.visible and rings.active and p.hacking)
	rings.angles[0] = rings.TARGET + PI
	err = Game.error_boost
	rings.press()
	_check("badly stopped ring is an error", Game.error_boost > err and rings.current == 0)
	for i in rings.RADII.size():
		rings.debug_align()
		rings.press()
	_check("all rings aligned -> antenna 2 off", Game.is_antenna_off("a2") and not p.hacking)
	main.load_map("world", Vector2i(100, 12))
	await _frames(2)
	hordes = get_tree().get_nodes_in_group("interactable").filter(func(n): return n.get_script() == preload("res://scripts/horde.gd"))
	_check("horde 2 left after antenna 2 went silent", hordes.is_empty())

	# --- crevice: zipline + zipline mutant ---
	await _use_warp("szczelina")
	_check("road's end leads to the crevice", Game.current_map == "szczelina")
	_check("checkpoint at the crevice", Game.respawn_map == "szczelina")
	var zip: Node2D = get_tree().get_first_node_in_group("ziplines")
	_check("zipline over the chasm", zip != null)
	p.global_position = zip.global_position + Vector2(-2, 2)
	await _frames(2)
	zip.interact(p)
	await _frames(2)
	_check("riding the zipline", p.riding and zip.rider == p)
	_check("zipline mutant appears", is_instance_valid(zip.boss) and zip.boss.alive)
	var waited_zip := 0.0
	while is_instance_valid(zip.boss) and zip.boss.alive and waited_zip < 15.0:
		p._fire_cd = 0.0
		Game.ammo = maxi(Game.ammo, 5)
		p.shoot((zip.boss.global_position + Vector2(0, -10) - (p.global_position + Vector2(0, -6))).normalized())
		await _wait(0.25)
		waited_zip += 0.25
	_check("zipline mutant shot off the line", Game.flags.has("zip_boss_dead"), "%.1fs" % waited_zip)
	waited_zip = 0.0
	while zip.rider != null and waited_zip < 10.0:
		await _wait(0.1)
		waited_zip += 0.1
	_check("rode across the chasm", not p.riding and Game.respawn_cell == Vector2i(29, 7), str(Game.respawn_cell))

	# --- Trybunał CURN: Braun's quest + antenna 3 (wires) ---
	await _use_warp("trybunal")
	_check("crevice leads to the Trybunał", Game.current_map == "trybunal")
	var braun: Node = _find("npcs", func(n): return n.npc_id == "braun")
	_check("Donald Braun in the Trybunał", braun != null)
	braun.talk()
	_check("Braun gives the quest", Game.flags.has("braun_met"))
	var boat: Node = get_tree().get_first_node_in_group("boats")
	_check("boat at the pier", boat != null)
	boat.interact(p)
	await _wait(0.5)
	_check("boat locked before the quest is done", Game.current_map == "trybunal" and not p.frozen)
	var left: int = get_tree().get_nodes_in_group("enemies").size()
	_check("Trybunał full of mutants", left >= 8, str(left))
	for e in get_tree().get_nodes_in_group("enemies"):
		e.take_damage(99, Vector2.ZERO)
	await _wait(0.3)
	_check("Trybunał cleared", Game.flags.has("trybunal_clear"))
	var a3: Node = _find("antennas", func(n): return n.antenna_id == "a3")
	_check("antenna 3 in the garden (wires)", a3 != null and a3.minigame == "wires")
	a3.interact(p)
	await _wait(0.4)
	var wires: Node = _find("hack_ui", func(n): return n.get_script() == preload("res://scripts/hack_wires.gd"))
	_check("wires panel opens", wires.visible and p.hacking)
	wires.pick(0)
	wires.plug(wires.debug_socket_for(0))
	wires.pick(1)
	err = Game.error_boost
	wires.plug(wires.debug_socket_for(2))
	_check("wrong socket sparks and pulls all wires", Game.error_boost > err and not wires.links.any(func(l): return l >= 0))
	for i in 4:
		wires.pick(i)
		wires.plug(wires.debug_socket_for(i))
	_check("all wires matched -> antenna 3 off", Game.is_antenna_off("a3") and not p.hacking)
	braun.talk()
	_check("Braun hands over the boat", Game.flags.has("braun_done"))

	# --- boat across the lake, Mama, Braun's jet ---
	boat.interact(p)
	await _wait(9.0)
	_check("boat crossing lands on Mama's shore", Game.current_map == "mama" and not p.frozen)
	var plane := _find("interactable", func(n): return n.has_method("prompt") and n.prompt() == "[E] Samolot")
	_check("Braun's jet on the strip", plane != null)
	plane.interact(p)
	await _wait(0.5)
	_check("no take-off without Mama", get_tree().current_scene == main)
	await _use_warp("mama_dom")
	_check("Mama's house", Game.current_map == "mama_dom")
	var mama: Node = _find("npcs", func(n): return n.npc_id == "mama")
	_check("Mama is home", mama != null)
	mama.talk()
	_check("met Mama", Game.flags.has("mama_met"))
	await _use_warp("mama")
	plane = _find("interactable", func(n): return n.has_method("prompt") and n.prompt() == "[E] Samolot")
	if plane:
		reparent(get_tree().root)  # survive the scene change
		plane.interact(p)
		await _wait(2.0)
		var cur := get_tree().current_scene
		_check("ending scene loads", cur != null and cur.scene_file_path.ends_with("ending.tscn"))
	print("AUTOTEST done: %d failed" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
