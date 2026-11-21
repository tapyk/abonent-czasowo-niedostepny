extends Node
## Automated verification suite.

var _failed := 0


func _ready() -> void:
	Game.dev["mute"] = true
	Game.dev["savefile"] = "save_test_modes.json"  # never touch the player's save
	get_tree().create_timer(30.0, true, false, true).timeout.connect(func():
		printerr("WATCHDOG_QUIT")
		get_tree().quit(2)
	)
	_run_all.call_deferred()


func _ok(name_txt: String, cond: bool, extra := "") -> void:
	print(("PASS  " if cond else "FAIL  ") + name_txt + ("  (" + extra + ")" if extra != "" else ""))
	if not cond:
		_failed += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run_all() -> void:
	print("=== EXTENDED MODES TEST START ===")

	# 1. Title screen menu
	Game.coop = false
	Game.difficulty = "normal"
	var title_scn: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title_scn)
	await _frames(2)
	title_scn.call("_change", "difficulty", 1)
	_ok("Title switches to HARD difficulty", Game.difficulty == "hard", Game.difficulty)
	title_scn.call("_confirm", "players")
	_ok("Title switches to LOCAL CO-OP", Game.coop)
	title_scn.call("_change", "new", 1)
	_ok("Option change ignores action rows", Game.coop and Game.is_hard())
	title_scn.free()

	# 2. Measure enemy counts across Solo vs Co-op Normal vs Co-op Hard
	var main_scn: PackedScene = load("res://scenes/main.tscn")

	Game.coop = false
	Game.difficulty = "normal"
	var m_solo := main_scn.instantiate()
	add_child(m_solo)
	await _frames(2)
	m_solo.load_map("world")
	await _frames(2)
	var cnt_solo := get_tree().get_nodes_in_group("enemies").size()
	_ok("Normal Solo has no Hard clues spawned", get_tree().get_nodes_in_group("hard_clues").is_empty())
	m_solo.free()
	await _frames(2)

	Game.coop = true
	Game.difficulty = "normal"
	var m_coop_norm := main_scn.instantiate()
	add_child(m_coop_norm)
	await _frames(2)
	m_coop_norm.load_map("world")
	await _frames(2)
	var cnt_coop_norm := get_tree().get_nodes_in_group("enemies").size()
	_ok("Co-op spawns Player 1 and Player 2", is_instance_valid(Game.player) and is_instance_valid(Game.player2))
	# Test Co-op Normal wave during antenna 2 hacking
	Game.has_kable = true
	var a2_coop: Node = get_tree().get_nodes_in_group("antennas").filter(func(a): return a.antenna_id == "a2")[0]
	a2_coop.interact(Game.player)
	await _frames(2)
	a2_coop.set("_wave_t", 0.01)
	a2_coop.call("_tick_coop_waves", 0.05)
	await _frames(2)
	var norm_wave_sz: int = a2_coop.get("_wave_enemies").size()
	_ok("Co-op Normal: a small defense wave when hacking", norm_wave_sz == 1, str(norm_wave_sz))
	# Test Co-op downed & partner proximity revive (no instant party wipe when P2 is alive!)
	Game.dev.erase("god")
	Game.player.take_damage(500, Vector2.ZERO)
	_ok("Co-op single downed player does NOT wipe party while P2 lives", Game.player.dead and not Game.player2.dead)
	Game.player2.global_position = Game.player.global_position + Vector2(8, 0)
	Game.player.set("_downed_t", 0.1)
	Game.player.call("_tick_coop_downed", 0.1)
	_ok("Partner proximity revives downed player", not Game.player.dead and Game.player.hp >= 40, str(Game.player.hp))
	m_coop_norm.free()
	await _frames(2)

	Game.coop = true
	Game.difficulty = "hard"
	var m_coop_hard := main_scn.instantiate()
	add_child(m_coop_hard)
	await _frames(2)
	m_coop_hard.load_map("world")
	await _frames(2)
	var cnt_coop_hard := get_tree().get_nodes_in_group("enemies").size()
	_ok("Enemy scaling: Solo < Co-op Normal < Co-op Hard",
		cnt_solo < cnt_coop_norm and cnt_coop_norm < cnt_coop_hard,
		"%d < %d < %d" % [cnt_solo, cnt_coop_norm, cnt_coop_hard])
	Game.has_kable = true
	var a2_hard_coop: Node = get_tree().get_nodes_in_group("antennas").filter(func(a): return a.antenna_id == "a2")[0]
	a2_hard_coop.interact(Game.player)
	await _frames(2)
	a2_hard_coop.set("_wave_t", 0.01)
	a2_hard_coop.call("_tick_coop_waves", 0.05)
	await _frames(2)
	var hard_wave_sz: int = a2_hard_coop.get("_wave_enemies").size()
	_ok("Co-op Hard: a slightly bigger defense wave", hard_wave_sz == 2, str(hard_wave_sz))
	# a lone guard can hold: the waves stop after a few and never pile up
	for i in 20:
		a2_hard_coop.set("_wave_t", 0.0)
		a2_hard_coop.call("_tick_coop_waves", 0.05)
	var w: Dictionary = a2_hard_coop.WAVES["hard"]
	var alive: int = a2_hard_coop.get("_wave_enemies").size()
	_ok("Co-op Hard waves never exceed the cap", alive <= int(w.alive) and a2_hard_coop.get("_wave_count") <= int(w.waves), "%d alive" % alive)
	m_coop_hard.free()
	await _frames(2)

	_test_settings()
	await _test_return_arrow(main_scn)
	await _test_coop_zipline_and_wreck(main_scn)
	_test_ammo_amounts()

	# 3. Full Hard-Mode Clues & All 3 Multi-Stage Antenna Puzzles
	await _test_hard_antennas_and_clues(main_scn)

	print("=== EXTENDED MODES TEST DONE: %d failed ===" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


## The settings box changes and applies values (without saving the player's file).
func _test_settings() -> void:
	var keep := [Settings.volume, Settings.shake, Settings.touch]
	var panel: Control = load("res://scripts/settings_panel.gd").new()
	add_child(panel)
	panel.open()
	Settings.volume = 80
	panel.call("_change", "volume", -1)
	_ok("settings: volume down 10% and applied", Settings.volume == 70
		and absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.7)) < 0.01, str(Settings.volume))
	panel.call("_change", "shake", 1)
	_ok("settings: shake toggles", Settings.shake != keep[1])
	panel.call("_change", "touch", 1)
	_ok("settings: touch mode cycles", Settings.touch != keep[2] and Touch.mode == Settings.touch, Settings.touch)
	panel.free()
	Settings.volume = keep[0]
	Settings.shake = keep[1]
	Settings.touch = keep[2]
	Settings.apply()


func _test_return_arrow(main_scn: PackedScene) -> void:
	Game.coop = false
	Game.difficulty = "normal"
	var m := main_scn.instantiate()
	add_child(m)
	await _frames(2)
	Game.has_pistol = true
	Game.disabled_ids.append("a1")
	Game.flags["farmer_met"] = true
	Game.parts = 3
	_ok("3 parts: objective says go back to the Farmer", m.objective() == "Wróć do Fasti Farmera.", m.objective())
	_ok("route from the roof to the barn goes through the estate", m.call("_next_map_toward", "roof", "stodola") == "world")
	m.load_map("world")
	await _frames(2)
	var door: Vector2 = Vector2.INF
	for n in m.level.entities.get_children():
		if "target_map" in n and n.target_map == "stodola":
			door = n.global_position
	var arrow: Vector2 = m.quest_arrow_target()
	_ok("on the estate the arrow points at the barn door", arrow != Vector2.INF and arrow.distance_to(door) < 16.0)
	m.load_map("stodola")
	await _frames(2)
	var farmer: Node = get_tree().get_nodes_in_group("npcs").filter(func(n): return n.npc_id == "farmer")[0]
	_ok("in the barn the arrow points at the Farmer", m.quest_arrow_target().distance_to(farmer.global_position) < 40.0)
	Game.has_kable = true
	_ok("after the cables: no arrow", m.quest_arrow_target() == Vector2.INF)
	Game.flags["trybunal_clear"] = true
	Game.disabled_ids.append("a3")
	Game.disabled_ids.append("a2")
	_ok("Trybunał done: go back to Braun", m.objective() == "Wróć do Brauna.", m.objective())
	m.free()
	await _frames(2)


func _test_coop_zipline_and_wreck(main_scn: PackedScene) -> void:
	Game.coop = true
	Game.difficulty = "normal"
	Game.dev["god"] = true
	var m := main_scn.instantiate()
	add_child(m)
	await _frames(2)
	# zipline: both players hang on it at once and both get across
	Game.flags["zip_boss_dead"] = true
	m.load_map("szczelina")
	await _frames(2)
	var zip: Node = get_tree().get_nodes_in_group("ziplines")[0]
	Game.player.global_position = zip.global_position + Vector2(-4, 4)
	Game.player2.global_position = zip.global_position + Vector2(4, 4)
	zip.interact(Game.player)
	_ok("zipline still free for the second player", zip.can_interact())
	zip.interact(Game.player2)
	_ok("two riders on the zipline at once", zip.riders.size() == 2 and Game.player.riding and Game.player2.riding)
	var far: Vector2 = zip.to_global(zip.end_pos - zip.position)
	var waited := 0.0
	while not zip.riders.is_empty() and waited < 9.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_ok("both riders arrive at the far post",
		Game.player.global_position.distance_to(far) < 40.0 and Game.player2.global_position.distance_to(far) < 40.0
		and not Game.player.riding and not Game.player2.riding, "%.0f / %.0f px" % [Game.player.global_position.distance_to(far), Game.player2.global_position.distance_to(far)])
	# crashed jet: mutants jump out
	Game.disabled_ids.append("a1")
	Game.flags.erase("plane_crashed")
	Game.flags.erase("plane_down")
	m.load_map("world")
	var wreck_at: Vector2 = m.level.feet(m.WRECK_CELL.x, m.WRECK_CELL.y)
	var near_before := _enemies_near(wreck_at, 90.0)
	await get_tree().create_timer(3.8).timeout
	_ok("mutants jump out of the crashed jet", _enemies_near(wreck_at, 90.0) >= near_before + 3,
		"%d -> %d" % [near_before, _enemies_near(wreck_at, 90.0)])
	_ok("the jet counts as down after the fall", Game.flags.has("plane_down"))
	Game.dev.erase("god")
	m.free()
	await _frames(2)


func _enemies_near(at: Vector2, r: float) -> int:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e.global_position.distance_to(at) < r).size()


func _test_ammo_amounts() -> void:
	Game.difficulty = "normal"
	var normal := Game.ammo_amount(5)
	Game.difficulty = "hard"
	var hard := Game.ammo_amount(5)
	_ok("ammo pack: a bit more on normal, much more on hard", normal > 5 and hard >= 2 * 5, "%d / %d" % [normal, hard])


func _test_hard_antennas_and_clues(main_scn: PackedScene) -> void:
	Game.coop = false
	Game.difficulty = "hard"
	var m := main_scn.instantiate()
	add_child(m)
	await _frames(2)

	var p: Node = Game.player
	var hard_ui: Control = null
	var maze_ui: Control = null
	for ui in get_tree().get_nodes_in_group("hack_ui"):
		if ui.get_script() == load("res://scripts/hack_hard.gd"):
			hard_ui = ui
		elif ui.get_script() == load("res://scripts/hack_maze.gd"):
			maze_ui = ui

	# Home clue
	var home_clues := get_tree().get_nodes_in_group("hard_clues")
	_ok("Hard clue spawned in home", home_clues.size() == 1)
	home_clues[0].interact(p)
	_ok("Home floor clue recorded", Game.note_ids.has("a1_floor"))

	# Roof: Technician + Plaque + Hard Antenna 1
	m.load_map("roof")
	await _frames(2)
	for n in m.level.entities.get_children():
		if "kind" in n and n.kind == "cable":
			n.interact(p)
	for roof_clue in get_tree().get_nodes_in_group("hard_clues"):
		roof_clue.interact(p)
	_ok("Technician gives cable + PIN clue, roof plaque gives the band",
		Game.has_cable and Game.note_ids.has("a1_tech") and Game.note_ids.has("a1_freq"))
	var a1: Node = get_tree().get_nodes_in_group("antennas")[0]
	a1.interact(p)
	await _frames(2)
	await get_tree().process_frame  # NotesHUD follows Game.hacking in _process
	_ok("Hard mode opens HackHard (not HackMaze) + NotesHUD visible",
		hard_ui.visible and not maze_ui.visible and hard_ui.notes_hud.visible)
	var prev_err := Game.error_boost
	hard_ui.a1_pin.assign([1, 2, 3, 4])
	hard_ui.call("_submit_a1_stage0")
	_ok("Wrong PIN triggers error boost", Game.error_boost > prev_err and hard_ui.stage == 0)
	hard_ui.a1_pin.assign([4, 0, 7, 4])
	hard_ui.a1_freq = 865
	hard_ui.call("_submit_a1_stage0")
	_ok("PIN 4074 + 865 MHz advances Antenna 1 to Stage 2", hard_ui.stage == 1)
	hard_ui.close()
	a1.interact(p)
	_ok("Leaving & reopening Hard panel preserves Stage 2", hard_ui.stage == 1)
	hard_ui.a1_prog = 49.0
	hard_ui.a1_freq = 865
	# Simulate drift trigger at 50%
	hard_ui.a1_prog = 51.0
	hard_ui.a1_drifted = true
	hard_ui.a1_freq = 845
	# Correct drift & finish
	hard_ui.a1_freq = 865
	hard_ui.a1_prog = 100.0
	hard_ui.call("_finish")
	_ok("Hard Antenna 1 shut down cleanly", Game.is_antenna_off("a1") and not p.hacking)

	# Stodola + Plantation: Hard Antenna 2
	m.load_map("stodola")
	await _frames(2)
	Game.parts = 3
	m.call("_talk_farmer")
	m.call("_talk_farmer")
	_ok("Fast Farmer gives cables + Z2/Z4 jumper clue on Hard", Game.has_kable and Game.note_ids.has("a2_farmer"))
	m.load_map("world")
	await _frames(2)
	var world_clues := get_tree().get_nodes_in_group("hard_clues")
	_ok("2 Plantation clues spawned on world in Hard mode", world_clues.size() == 2)
	for wc in world_clues:
		wc.interact(p)
	_ok("Both Plantation clues recorded", Game.note_ids.has("a2_base") and Game.note_ids.has("a2_math"))
	var a2: Node = get_tree().get_nodes_in_group("antennas").filter(func(x): return x.antenna_id == "a2")[0]
	a2.interact(p)
	await _frames(2)
	hard_ui.a2_jumpers.assign([true, true, false, false])
	hard_ui.call("_submit_a2_stage0")
	_ok("Antenna 2 jumpers (GÓRA,GÓRA,DÓŁ,DÓŁ) advance to Stage 2", hard_ui.stage == 1)
	for i in 3:
		hard_ui.a2_green = (i % 2 == 0)
		hard_ui.a2_pair_a = 6 if hard_ui.a2_green else 9
		hard_ui.a2_pair_b = 4 if hard_ui.a2_green else 5
		hard_ui.call("_submit_a2_pair")
	_ok("3 valid dual-mode checksum hits advance Antenna 2 to Stage 3", hard_ui.stage == 2)
	hard_ui.a2_prog = 100.0
	hard_ui.call("_finish")
	_ok("Hard Antenna 2 shut down cleanly", Game.is_antenna_off("a2"))

	# Trybunał: Hard Antenna 3
	m.load_map("trybunal")
	await _frames(2)
	m.call("_talk_braun")
	var tryb_clues := get_tree().get_nodes_in_group("hard_clues")
	_ok("2 Garden meter clues spawned in Trybunał on Hard", tryb_clues.size() == 2)
	for tc in tryb_clues:
		tc.interact(p)
	_ok("All Trybunał clues recorded", Game.note_ids.has("a3_rule") and Game.note_ids.has("a3_main") and Game.note_ids.has("a3_tr"))
	var a3: Node = get_tree().get_nodes_in_group("antennas").filter(func(x): return x.antenna_id == "a3")[0]
	a3.interact(p)
	await _frames(2)
	hard_ui.a3_seq.assign([2, 3, 1])
	hard_ui.a3_phase = -3
	hard_ui.call("_submit_a3_stage0")
	_ok("Sequence T2->T3->T1 and Phase -3 advance Antenna 3 to Stage 2", hard_ui.stage == 1)
	hard_ui.a3_fuse_a = true
	hard_ui.call("_step_a3", 0.5)
	_ok("Tripped fuse pauses Antenna 3 shutdown", hard_ui.a3_prog == 0.0)
	hard_ui.a3_fuse_a = false
	hard_ui.a3_prog = 99.0
	hard_ui.call("_step_a3", 0.5)
	_ok("Resetting fuse completes Hard Antenna 3 shutdown", Game.is_antenna_off("a3"))
	# Test set_hacking(false) interact cooldown (prevents E from re-opening panel in same frame)
	p.set_hacking(true)
	p.set_hacking(false)
	_ok("Closing panel sets interact cooldown so E doesn't reopen it", float(p.get("_interact_cd")) > 0.1)

	# Test save & load preserving difficulty + coop + clues
	Game.coop = true
	var saved_ok := Game.save_game("trybunal", Vector2i(10, 10), 80)
	Game.difficulty = "normal"
	Game.coop = false
	var loaded_dict := Game.read_save()
	var applied := Game.apply_save(loaded_dict)
	_ok("Save/Load preserves HARD difficulty and clues", saved_ok and Game.difficulty == "hard" and Game.note_ids.has("a3_tr") and applied.hp == 80)
	Game.coop = false

	m.free()
