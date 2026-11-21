extends Node
## Automated verification suite.

var _failed := 0


func _ready() -> void:
	Game.dev["mute"] = true
	get_tree().create_timer(12.0, true, false, true).timeout.connect(func():
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

	# 1. Title screen + Steam AppID 480 check
	var title_scn: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title_scn)
	await _frames(2)
	title_scn.set("_row", 1)
	title_scn.call("_change_option", 1)
	_ok("Title switches to HARD difficulty", Game.difficulty == "hard", Game.difficulty)
	title_scn.set("_row", 0)
	title_scn.call("_change_option", 1)
	_ok("Title switches to LOCAL CO-OP", Game.coop and not Game.coop_steam)
	title_scn.free()
	_ok("Steam AppID 480 configured & SteamMultiplayerPeer present",
		SteamNet.SPACEWAR_APP_ID == 480 and ClassDB.class_exists("SteamMultiplayerPeer"))

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
	_ok("Co-op Normal spawns 2-mutant defense wave when hacking", norm_wave_sz == 2, str(norm_wave_sz))
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
	_ok("Co-op Hard spawns larger 3-mutant wave when hacking", hard_wave_sz == 3, str(hard_wave_sz))
	m_coop_hard.free()
	await _frames(2)

	# 3. Full Hard-Mode Clues & All 3 Multi-Stage Antenna Puzzles
	await _test_hard_antennas_and_clues(main_scn)

	print("=== EXTENDED MODES TEST DONE: %d failed ===" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
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
	_ok("Technician gives cable + Hard clues (PIN 4074 & 865 MHz)",
		Game.has_cable and Game.note_ids.has("a1_tech") and Game.note_ids.has("a1_freq"))
	var a1: Node = get_tree().get_nodes_in_group("antennas")[0]
	a1.interact(p)
	await _frames(2)
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
