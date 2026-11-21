extends Node2D
## Game scene: loads maps.

const LEVEL := preload("res://scripts/level.gd")
const PLAYER_SCN := preload("res://scenes/player.tscn")
const PICKUP_SCN := preload("res://scenes/pickup.tscn")
const BULLET_SCN := preload("res://scenes/bullet.tscn")
const NET_PUPPET := preload("res://scripts/net_puppet.gd")
const BRIGHT_AFTER := Color(0.5, 0.5, 0.6)
const INTERIORS := ["home", "stodola", "mama_dom"]
const PARTS_NEEDED := 3
## Where the damaged jet comes down on the estate after antenna 1.
const WRECK_CELL := Vector2i(46, 37)
const ENEMY_SCN := preload("res://scenes/enemy.tscn")
## Mutants that jump out of the wreck when it lands: [cell offset from WRECK_CELL, burnt].
const WRECK_MUTANTS := [[Vector2i(-3, 1), false], [Vector2i(3, 1), true], [Vector2i(0, 2), false],
	[Vector2i(-4, -1), false], [Vector2i(4, -1), true]]

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var darkness: CanvasModulate = $Darkness

var player2: CharacterBody2D = null
var level: Node2D
var _busy := false
var _dying := false
var _ending := false
var _objective := ""
var _announced_return := ""
# online client: host mutants / drops shown here (net id -> node), host map revision
var _puppets := {}
var _drops := {}
var _net_rev := -1


func _ready() -> void:
	add_to_group("story")
	if not Game.pending_load.is_empty():
		if str(Game.pending_load.get("difficulty", "")) in ["normal", "hard"]:
			Game.difficulty = str(Game.pending_load.get("difficulty", "normal"))
		if Game.pending_load.has("coop"):
			Game.coop = bool(Game.pending_load.get("coop", false))
	Game.new_game()
	Game.player = player  # new_game() runs after the player registered itself
	player.died.connect(_on_player_died)
	player.hp_changed.connect(hud.set_hp)
	if Game.coop:
		player2 = PLAYER_SCN.instantiate()
		player2.name = "Player2"
		player2.player_index = 2
		add_child(player2)
		Game.player2 = player2
		player2.died.connect(_on_player_died)
		player2.hp_changed.connect(hud.set_hp2)
	Game.antenna_disabled.connect(_on_antenna_disabled)
	add_child(preload("res://scripts/pause_menu.gd").new())
	if not Game.dev.has("autotest") and not Touch.active:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # HUD draws a crosshair instead
	if Net.is_client():
		_client_start()
		return
	if not Game.pending_load.is_empty():
		var s := Game.apply_save(Game.pending_load)
		Game.pending_load = {}
		load_map(s.map, s.cell)
		if s.hp > 0:
			player.hp = 0
			player.heal(s.hp)
		hud.show_big("WCZYTANO", Color("8fe0a0"), 1.0)
	else:
		var start: String = str(Game.dev.get("map", "home"))
		load_map(start)
		_intro()
	DevTools.attach(self)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0  # in case the game is left during the death slow motion


## The story setup.
func _intro() -> void:
	if Game.coop:
		# Player 2, Adam Białawski, explains the missing cap
		Game.say_line("Johnny", "Białawski, a twoja czapka z folii?")
		Game.say_line("Białawski", "Nie potrzebuję. Fale odbijają się od łysej glacy.")
	if Touch.active:
		hud.show_hint("Lewa strona: ruch   prawa: celuj i strzel   E: akcja")
	elif Net.is_host():
		hud.show_hint("Online: grasz jako P1 (WASD + mysz, E). Zapisujesz ty.")
	elif Game.coop:
		hud.show_hint("P1: WASD+Mysz+E   P2: Strzałki+P/O/L (lub Pad)" + ("   TAB: wskazówki" if Game.is_hard() else ""))
	elif Game.is_hard():
		hud.show_hint("WASD: ruch   E: akcja   TAB: wskazówki   LPM: cios")
	else:
		hud.show_hint("WASD: ruch   E: akcja   LPM: cios   Enter: dalej")


func _brightness() -> float:
	return clampf(0.3 * Game.disabled_count, 0.0, 0.85)


## Builds `map_name` and puts Johnny (and P2 in Co-op) on `cell` (or the map's P marker).
func load_map(map_name: String, cell := Vector2i(-1, -1)) -> void:
	if level:
		player.reparent(self)
		if is_instance_valid(player2):
			player2.reparent(self)
		level.free()
	Game.antennas.clear()
	Game.current_map = map_name
	level = LEVEL.new()
	level.name = "Level"
	world.add_child(level)
	level.build(map_name)
	var c: Vector2i = cell if cell.x >= 0 else level.player_start
	player.reparent(level.entities)
	player.global_position = level.feet(c.x, c.y)
	player.in_bush = 0
	player.riding = false
	if player.dead and Game.coop:
		player.dead = false
		player.heal(35)
	if is_instance_valid(player2):
		var c2: Vector2i = level.nearest_walkable(c + Vector2i(1, 0))
		if c2.x < 0:
			c2 = c
		player2.reparent(level.entities)
		player2.global_position = level.feet(c2.x, c2.y)
		player2.in_bush = 0
		player2.riding = false
		if player2.dead:
			player2.dead = false
			player2.heal(35)
	if level.header.has("checkpoint") and cell.x >= 0:
		Game.set_checkpoint(map_name, c)
	var dark: Color = level.darkness
	if not map_name in INTERIORS:
		dark = dark.lerp(BRIGHT_AFTER, _brightness())
	darkness.color = dark
	_fit_camera(level.bounds())
	player.camera.position = Vector2(0, -8)
	player.camera.reset_smoothing()
	if Net.is_client():
		_client_map_built()
		return
	_on_enter_map(map_name)
	if Net.is_host():
		Net.map_loaded()


func _fit_camera(b: Rect2) -> void:
	var cam: Camera2D = player.camera
	var view := get_viewport().get_visible_rect().size
	if b.size.x < view.x:
		cam.limit_left = int(b.get_center().x - view.x / 2)
		cam.limit_right = int(b.get_center().x + view.x / 2)
	else:
		cam.limit_left = int(b.position.x)
		cam.limit_right = int(b.end.x)
	if b.size.y < view.y:
		cam.limit_top = int(b.get_center().y - view.y / 2)
		cam.limit_bottom = int(b.get_center().y + view.y / 2)
	else:
		cam.limit_top = int(b.position.y)
		cam.limit_bottom = int(b.end.y)


func warp_to(map_name: String, cell: Vector2i) -> void:
	if _busy:
		return
	_busy = true
	player.frozen = true
	if is_instance_valid(player2):
		player2.frozen = true
	await hud.fade(1.0, 0.25).finished
	load_map(map_name, cell)
	await hud.fade(0.0, 0.25).finished
	player.frozen = false
	if is_instance_valid(player2):
		player2.frozen = false
	_busy = false


## Say these lines only the first time `flag` comes up.
func _once(flag: String, lines: Array) -> void:
	if Game.flags.has(flag):
		return
	Game.flags[flag] = true
	for l in lines:
		Game.say_line(l[0], l[1], l.size() > 2)


func _on_enter_map(map_name: String) -> void:
	if map_name == "world" and Game.is_antenna_off("a1"):
		if Game.flags.has("plane_crashed"):
			_spawn_wreck(false)
		else:
			_plane_crash()
	match map_name:
		"world":
			_once("world_seen", [["Mama", "Widzisz czerwone światło na bloku naprzeciwko? Zacznij od tej anteny.", true]])
		"stodola":
			_once("stodola_seen", [["Johnny", "Folia aluminiowa na ścianach. Zero kresek."]])
		"szczelina":
			_once("szczelina_seen", [["Johnny", "Szczelina po wybuchu CURNu."],
				["Mama", "Nad szczeliną tyrolka… coś na niej wisi…", true]])
		"trybunal":
			# Braun shouts the deal across the plaza right away, so the player knows
			# why the mutants have to go before fighting through them.
			if not Game.flags.has("braun_met"):
				Game.flags["braun_met"] = true
				var deal := [["Johnny", "Trybunał CURN. Pełno mutantów. I facet w garniturze."],
					["Braun", "Pan tam! Tak, pan, w czapce z folii!"],
					["Braun", "Oczyści pan Trybunał i wyłączy antenę w ogrodzie, a łódka jest pańska."],
					["Johnny", "Łódka. Dom mamy jest za jeziorem. Umowa."]]
				if Game.is_hard():
					Game.add_clue("a3_rule", "a3", "Braun: transformatory od największej mocy, faza przeciwna do zewnętrznej")
					deal.append(["Braun", "Antenę zasilają trzy transformatory. Odcina się od najmocniejszego, a fazę ustawia przeciwnie do sieci."])
				_once("trybunal_seen", deal)
		"mama":
			_once("mama_shore_seen", [["Johnny", "Dom mamy na górce. I odrzutowiec na pasie?"]])


func objective() -> String:
	var m := Game.current_map
	if not Game.has_pistol:
		return "Weź pistolet taty ze stołu."
	var back := return_target()
	if not back.is_empty():
		return back.text
	if not Game.is_antenna_off("a1"):
		if m == "home":
			return "Zejdź schodami na osiedle."
		if m == "roof":
			return "Zhakuj panel anteny [E]." if Game.has_cable else "Znajdź kabel (technik na dachu)."
		if not Game.has_sekator:
			return "Znajdź sekator. Może między blokami?" if Game.flags.has("thicket_seen") \
				else "Blok naprzeciwko: czerwone światło."
		return "Przetnij gąszcz, wejdź do bloku."
	if not Game.has_kable:
		if not Game.flags.has("farmer_met"):
			return "Na wschód: stodoła Fasti Farmera na polach."
		return "Części od spalonych: %d/%d." % [Game.parts, PARTS_NEEDED]
	if not Game.is_antenna_off("a2"):
		return "Plantacja na wschodzie: zhakuj antenę 2."
	if m in ["world", "stodola", "roof", "home"]:
		return "Droga na wschód wolna. Do szczeliny."
	if m == "szczelina":
		return "Przejedź tyrolką na drugą stronę [E]." if not Game.flags.has("zip_across") \
			else "Na wschód, do Trybunału CURN."
	if not Game.flags.has("braun_met"):
		return "Na wschód, do Trybunału CURN."
	var left := _mutants_left()
	if not Game.flags.has("trybunal_clear"):
		return "Oczyść Trybunał z mutantów (%d)." % left if left >= 0 else "Oczyść Trybunał z mutantów."
	if not Game.is_antenna_off("a3"):
		return "Zhakuj antenę 3 w ogrodzie Trybunału."
	if not Game.flags.has("mama_met"):
		if m == "trybunal":
			return "Łódka na przystani. Płyń do mamy."
		return "Idź do domu mamy."
	return "Odrzutowiec Brauna czeka na pasie."


## Living mutants on the Trybunał map (-1 elsewhere).
func _mutants_left() -> int:
	if Game.current_map != "trybunal":
		return -1
	return get_tree().get_nodes_in_group("enemies").size()


func _process(_delta: float) -> void:
	if Game.coop and is_instance_valid(player2):
		_update_coop_camera_and_tether()
	if Net.is_client():
		_update_objective()
		return
	if Game.current_map == "trybunal" and not Game.flags.has("trybunal_clear") and _mutants_left() == 0 and not _busy:
		Game.flags["trybunal_clear"] = true
		hud.show_big("TRYBUNAŁ CZYSTY", Color("8fe0a0"), 1.0)
		if Game.flags.has("braun_met"):
			Game.say_line("Johnny", "Ostatni. Ogród czysty.")
			if not Game.is_antenna_off("a3"):
				Game.say_line("Johnny", "Została antena.")
			else:
				Game.say_line("Johnny", "Wracam do Brauna.")
	_update_objective()


func _update_objective() -> void:
	var o := objective()
	if o != _objective:
		_objective = o
		hud.set_objective(o)
		var back := return_target()
		if not back.is_empty() and o == back.text and o != _announced_return:
			_announced_return = o  # quest done: say once who to go back to
			hud.show_big(o.trim_suffix(".").to_upper(), Color("ffe08a"), 1.2)
			Sfx.play("confirm", 0.0, -4.0)


# --- going back to people after a quest ------------------------------------------------

## The person the player has to go back to now that their task is done, or {}.
func return_target() -> Dictionary:
	if Game.flags.has("farmer_met") and Game.parts >= PARTS_NEEDED and not Game.has_kable:
		return {"map": "stodola", "npc": "farmer", "text": "Wróć do Fasti Farmera."}
	if _trybunal_done() and not Game.flags.has("braun_done"):
		return {"map": "trybunal", "npc": "braun", "text": "Wróć do Brauna."}
	if Game.flags.has("mama_met"):
		return {"map": "mama", "npc": "braun", "text": "Wróć do Brauna przy odrzutowcu."}
	return {}


## Where the HUD's quest arrow points (world position), or Vector2.INF for no arrow.
func quest_arrow_target() -> Vector2:
	var back := return_target()
	if back.is_empty() or level == null:
		return Vector2.INF
	if Game.current_map == back.map:
		for n in get_tree().get_nodes_in_group("npcs"):
			if n.npc_id == back.npc:
				return n.global_position + Vector2(0, -28)
		return Vector2.INF
	var next := _next_map_toward(Game.current_map, back.map)
	for n in level.entities.get_children():
		if "target_map" in n and n.target_map == next:
			return n.global_position + Vector2(0, -10)
	return Vector2.INF


## Doors and boats between maps, read once from the map headers: map -> [maps].
static var _map_links := {}


## First map to go to on the way from `from` to `to` (breadth-first over the links).
func _next_map_toward(from: String, to: String) -> String:
	if _map_links.is_empty():
		for f in DirAccess.get_files_at("res://maps"):
			if not f.ends_with(".txt"):
				continue
			var links: Array[String] = []
			var file := FileAccess.open("res://maps/" + f, FileAccess.READ)
			while file != null and not file.eof_reached():
				var line := file.get_line()
				var parts := line.split("=", true, 1)
				if parts.size() == 2 and (parts[1].begins_with("warp:") or parts[1].begins_with("boat:")):
					links.append(parts[1].split(":")[1])
			_map_links[f.get_basename()] = links
	var came_from := {from: ""}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var m: String = queue.pop_front()
		if m == to:
			while came_from[m] != from and came_from[m] != "":
				m = came_from[m]
			return m
		for nb in _map_links.get(m, []):
			if not came_from.has(nb):
				came_from[nb] = m
				queue.append(nb)
	return ""


func on_trigger(id: String) -> void:
	match id:
		"thicket":
			Game.flags["thicket_seen"] = true
			if not Game.has_sekator:
				Game.say_line("Johnny", "Gąszcz. Bez sekatora nie przejdę.", false, true)
		"horde":
			if not Game.is_antenna_off("a1"):
				Game.say_line("Johnny", "Horda nasłuchuje sygnału. Nie przejdę.", false, true)
		"barn":
			if not Game.flags.has("farmer_met"):
				_once("barn_seen", [["???", "Stój! Masz telefon? Włączony?!"],
					["Johnny", "…Już nie."]])
		"plantation":
			_once("plantation_seen", [["Johnny", "Palmy? Tutaj? Ktoś się bawił w Cayo Perico."],
				["Mama", "Druga antena… stoi między palmami… pilnują jej spaleni…", true]])
		"crevice":
			pass
		"zip_boss":
			Game.say_line("Johnny", "Coś jedzie z drugiej strony!", false, true)
			_once("zip_boss_seen", [["Mama", "Tyrolkowy… [szum]… strzelaj, zanim cię zrzuci!", true]])
		"zip_boss_dead":
			hud.show_big("TYROLKOWY MUTANT POKONANY", Color("ffb060"), 1.0)
			Game.say_line("Johnny", "Leć. Daleko.")
		"zip_across":
			_once("zip_across", [["Johnny", "Druga strona. Trybunał CURN jest na wschód."]])


# --- characters ---------------------------------------------------------------

func npc_has_news(id: String) -> bool:
	match id:
		"farmer":
			return not Game.flags.has("farmer_met") or (Game.parts >= PARTS_NEEDED and not Game.has_kable)
		"braun":
			if Game.current_map == "mama":
				return Game.flags.has("mama_met")
			return not Game.flags.has("braun_met") or (_trybunal_done() and not Game.flags.has("braun_done"))
		"mama":
			return not Game.flags.has("mama_met")
	return false


func _trybunal_done() -> bool:
	return Game.flags.has("trybunal_clear") and Game.is_antenna_off("a3")


func on_npc(id: String) -> void:
	match id:
		"farmer":
			_talk_farmer()
		"braun":
			_talk_braun()
		"mama":
			_talk_mama()
	hud.dialog.begin_conversation()  # Johnny and the mutants wait until it's over


# --- the damaged jet -----------------------------------------------------------

## After antenna 1.
func _plane_crash() -> void:
	Game.flags["plane_crashed"] = true
	if Game._saved.has("flags"):
		Game._saved.flags["plane_crashed"] = true  # dying doesn't replay the crash
	await get_tree().create_timer(1.2).timeout
	if Game.current_map != "world":
		return
	Net.send_wreck_fall()
	_spawn_wreck(true)


func _spawn_wreck(falling: bool) -> void:
	var t := PropArt.plane_wrecked()
	var n := Node2D.new()
	n.name = "Wreck"
	n.position = level.feet(WRECK_CELL.x, WRECK_CELL.y)
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(Vector2(cos(i * TAU / 16.0) * t.get_width() * 0.4, sin(i * TAU / 16.0) * 5.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.35)
	n.add_child(shadow)
	var s := Sprite2D.new()
	s.texture = t
	var rest := Vector2(0, -t.get_height() / 2.0 + 4.0)
	s.position = rest
	s.rotation = 0.06
	n.add_child(s)
	var fire := PointLight2D.new()
	fire.texture = Art.light_radial(96)
	fire.color = Color(1.0, 0.55, 0.25)
	fire.energy = 0.9
	fire.position = Vector2(-10, -14)
	n.add_child(fire)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(t.get_width() * 0.55, 10)
	shape.shape = rect
	shape.position = Vector2(4, -5)
	body.add_child(shape)
	n.add_child(body)
	level.entities.add_child(n)
	var flicker := n.create_tween().set_loops()
	flicker.tween_property(fire, "energy", 0.6, 0.15)
	flicker.tween_property(fire, "energy", 1.0, 0.2)
	if not falling:
		_mark_plane_down()
		return
	# comes in from the upper left, nose down, its shadow growing on the ground
	s.position = rest + Vector2(-240, -200)
	s.rotation = 0.45
	shadow.scale = Vector2(0.2, 0.2)
	fire.visible = false
	body.process_mode = Node.PROCESS_MODE_DISABLED
	Sfx.play("growl", 0.0, -20.0)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(s, "position", rest, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "rotation", 0.06, 1.4)
	tw.tween_property(shadow, "scale", Vector2.ONE, 1.4)
	await tw.finished
	fire.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	Sfx.play("explosion", 0.0, 2.0)
	player.shake(4.0)
	if Net.is_client():
		return  # the host spawns the mutants and says the lines
	_mark_plane_down()
	_wreck_mutants(n.position)
	Game.say_line("Johnny", "…Samolot spadł.")
	Game.say_line("Mama", "Johnny? Co tak huknęło?", true)
	Game.say_line("Johnny", "Samolot. Ja jestem cały.")


## The jet lies on the estate now (the online client draws it as a wreck from then on).
func _mark_plane_down() -> void:
	Game.flags["plane_down"] = true
	if Game._saved.has("flags"):
		Game._saved.flags["plane_down"] = true


## Mutants jump out of the crashed jet and come at Johnny (more in co-op, more burnt on hard).
func _wreck_mutants(at: Vector2) -> void:
	var count := WRECK_MUTANTS.size() if Game.coop else 3
	for i in count:
		var c: Vector2i = level.nearest_walkable(WRECK_CELL + WRECK_MUTANTS[i][0])
		if c.x < 0:
			continue
		var e: CharacterBody2D = ENEMY_SCN.instantiate()
		e.burnt = WRECK_MUTANTS[i][1] or (Game.is_hard() and i == 0)
		e.position = at + Vector2(randf_range(-10, 10), -12)
		level.entities.add_child(e)
		e.set_physics_process(false)
		var land: Vector2 = level.feet(c.x, c.y)
		var from := e.position
		var top := (from + land) / 2.0 + Vector2(0, -26)
		var tw := e.create_tween()
		tw.tween_interval(0.15 * i)
		# a hop in an arc: out of the fuselage, up, down onto the ground
		tw.tween_method(func(k: float) -> void:
			e.position = from.lerp(top, k).lerp(top.lerp(land, k), k), 0.0, 1.0, 0.5)
		tw.tween_callback(func() -> void:
			e.home = land
			e.set_physics_process(true)
			e.alert())
	get_tree().create_timer(0.6).timeout.connect(func():
		Game.say_line("Johnny", "Z samolotu wyłażą mutanci!", false, true))


## Esc menu save / autosave. Not while riding, sailing or switching maps.
func can_save() -> bool:
	if Net.is_client():
		return false  # the host keeps the save
	return not (_busy or _ending or player.dead or player.riding or Game.hacking)


func save_game(auto := false) -> bool:
	if not can_save():
		return false
	var ok := Game.save_game(Game.current_map, level.to_cell(player.global_position), player.hp)
	if ok and auto:
		hud.show_big("AUTOZAPIS", Color("8fe0a0"), 0.8)
	return ok


func _update_coop_camera_and_tether() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player2):
		return
	if not Net.is_client() and not player.riding and not player2.riding and not player.dead and not player2.dead:
		var diff := player2.global_position - player.global_position
		if absf(diff.x) > 256.0:
			player2.global_position.x = player.global_position.x + signf(diff.x) * 256.0
		if absf(diff.y) > 132.0:
			player2.global_position.y = player.global_position.y + signf(diff.y) * 132.0
	var target := player.global_position
	if not player.dead and not player2.dead:
		target = (player.global_position + player2.global_position) * 0.5
	elif player.dead and not player2.dead:
		target = player2.global_position
	player.camera.global_position = target + Vector2(0, -8)


func _talk_farmer() -> void:
	if not Game.flags.has("farmer_met"):
		Game.flags["farmer_met"] = true
		save_game.call_deferred(true)
		# The phone question was already shouted from the barn (barn trigger).
		if not Game.flags.has("barn_seen"):
			Game.say_line("Farmer", "Stój! Masz telefon? Włączony?!")
			Game.say_line("Johnny", "…Już nie.")
		Game.say_line("Farmer", "Dwadzieścia lat mówiłem, że ta sieć nas zje.")
		Game.say_line("Farmer", "Kable do anten dam. Za trzy części od spalonych.")
		_farmer_hard_tip()
		if Game.parts < PARTS_NEEDED:
			return
	if Game.has_kable:
		Game.say_line("Farmer", "Kable masz. Antena jest na plantacji na wschodzie. Cayo Perico, tylko ze spalonymi.")
		_farmer_hard_tip()
		return
	if Game.parts >= PARTS_NEEDED:
		Game.take_parts(PARTS_NEEDED)
		Game.has_kable = true
		Game.stats_changed.emit()
		save_game.call_deferred(true)
		Sfx.play("pickup")
		hud.show_big("KABLE OD FARMERA", Color("8fe0a0"), 0.8)
		Game.say_line("Farmer", "Trzy. Masz kable. Pasują do plantacji i Trybunału.")
		Game.say_line("Farmer", "W Trybunale siedzi Donald. Garnitur, krawat. Nic mu nie dawaj za darmo.")
		Game.say_line("Farmer", "Plantacja na wschodzie. Palmy jak na Cayo Perico.")
		Game.say_line("Johnny", "A teraz?")
		Game.say_line("Farmer", "Teraz rośnie tam tylko sygnał.")
	else:
		Game.say_line("Farmer", "Trzy części od spalonych. Masz %d. Świecą w ciemności." % Game.parts)


## HARD: the Farmer also knows how the plantation masts are wired (once).
func _farmer_hard_tip() -> void:
	if Game.is_hard() and Game.add_clue("a2_farmer", "a2", "Farmer: odwróć Z2, a przy czerwonej diodzie też Z4"):
		Game.say_line("Farmer", "I zapamiętaj: w masztach na plantacji odwróć zworkę Z2. Świeci czerwona dioda? To i Z4.")


func _talk_braun() -> void:
	if Game.current_map == "mama":
		if not Game.flags.has("mama_met"):
			Game.say_line("Braun", "Najpierw matka, panie Walker.")
		else:
			Game.say_line("Braun", "Proszę wsiadać. Lot do Irlandii.")
		return
	if not Game.flags.has("braun_met"):
		Game.flags["braun_met"] = true
		Game.say_line("Braun", "Kto pana tu wpuścił?")
		Game.say_line("Johnny", "Pana ogród jest pełen mutantów.")
		Game.say_line("Braun", "Dlatego stoję tutaj.")
		Game.say_line("Braun", "Umowa: oczyści pan Trybunał i wyłączy antenę w ogrodzie.")
		Game.say_line("Braun", "Ja mam łódkę i odrzutowiec za jeziorem.")
		Game.say_line("Johnny", "Dom mamy jest za jeziorem.")
		Game.say_line("Braun", "Wspólny interes. Proszę zaczynać.")
		return
	if Game.flags.has("braun_done"):
		Game.say_line("Braun", "Łódka na przystani. Spotkamy się przy odrzutowcu.")
		return
	if _trybunal_done():
		Game.flags["braun_done"] = true
		Sfx.play("pickup")
		Game.say_line("Braun", "Cisza. Proszę, kluczyk do łodzi.")
		Game.say_line("Braun", "Odrzutowiec czeka przy domu pańskiej matki. Mam jeszcze dokumenty do podpisania.")
		Game.say_line("Johnny", "Komu?")
		Game.say_line("Braun", "Sobie. Ktoś musi.")
		return
	var left := _mutants_left()
	if not Game.flags.has("trybunal_clear"):
		Game.say_line("Braun", "Słyszę ich jeszcze. Zostało %d." % left if left > 0 else "Słyszę ich jeszcze.")
	else:
		Game.say_line("Braun", "Antena w ogrodzie dalej nadaje.")


func _talk_mama() -> void:
	if Game.flags.has("mama_met"):
		Game.say_line("Mama", "Donald czeka przy odrzutowcu. Chodź.")
		return
	Game.flags["mama_met"] = true
	hud.show_big("MAMA", Color("ffe08a"), 0.8)
	Game.say_line("Johnny", "Cześć, mamo. Abonent dostępny.")
	Game.say_line("Mama", "Potem się przytulimy. Odrzutowiec Donalda stoi za domem.")
	Game.say_line("Johnny", "Wiem. Wspólny interes.")


# --- boat -------------------------------------------------------------------------

func board_boat(boat: Node2D, _p: Node) -> void:
	if _busy:
		return
	if Game.current_map == "trybunal" and not Game.flags.has("braun_done"):
		if not Game.flags.has("braun_met"):
			Game.say_line("Johnny", "Łódka na kłódkę. Kto ma kluczyk?", false, true)
		else:
			Game.say_line("Johnny", "Łódka Brauna. Kluczyk dostanę po robocie.", false, true)
		return
	_busy = true
	player.frozen = true
	player.riding = true
	if is_instance_valid(player2):
		player2.frozen = true
		player2.riding = true
	Sfx.play("step", 0.1, -4.0)
	var east := 1.0 if Game.current_map == "trybunal" else -1.0
	var from := boat.global_position
	var sail := func(v: Vector2) -> void:
		boat.global_position = v
		player.global_position = v + Vector2(-4, -3)
		if is_instance_valid(player2):
			player2.global_position = v + Vector2(3, -3)
	var tw := create_tween()
	tw.tween_method(sail, from, from + Vector2(140.0 * east, 24.0), 3.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.8).timeout
	await hud.fade(1.0, 1.0).finished
	tw.kill()
	hud.show_big("Chwilę później…", Color("c8d0d8"), 1.6)
	await get_tree().create_timer(2.6).timeout
	player.riding = false
	if is_instance_valid(player2):
		player2.riding = false
	load_map(boat.target_map, boat.target_cell)
	await hud.fade(0.0, 0.8).finished
	player.frozen = false
	if is_instance_valid(player2):
		player2.frozen = false
	_busy = false


# --- antennas, death, ending ---------------------------------------------------

func _on_antenna_disabled(a: Node) -> void:
	create_tween().tween_property(darkness, "color", level.darkness.lerp(BRIGHT_AFTER, _brightness()), 3.0)
	hud.show_big("CISZA", Color("8fe0a0"), 1.2)
	match a.antenna_id:
		"a1":
			Game.say_line("Mama", "Słyszę cię lepiej! Horda z drogi odchodzi.", true)
			Game.say_line("Mama", "Fasti Farmer na polach ma kable do anten.", true)
			Game.say_line("Johnny", "Ten od folii? Idę.")
		"a2":
			Game.say_line("Mama", "Druga cicho! Horda odchodzi.", true)
			Game.say_line("Mama", "Za drogą szczelina, dalej Trybunał CURN. Ostatnia antena.", true)
			Game.say_line("Mama", "W Trybunale siedzi Donald. Pomoże, jak mu się opłaci.", true)
			Game.say_line("Johnny", "Ostatnia. Brzmi dobrze.")
		"a3":
			Game.say_line("Mama", "Johnny… słyszę cię czysto.", true)
			Game.say_line("Mama", "Jestem w domu za jeziorem. Czekam.", true)
			if not Game.flags.has("trybunal_clear"):
				Game.say_line("Johnny", "Jeszcze mutanci. Braun nie da łódki za pół roboty.")
			else:
				Game.say_line("Johnny", "Braun ma łódkę. Zaraz będę.")


## Death killcam.
func _on_player_died() -> void:
	# Own flag, not _busy: a death during a warp or the boat ride must still respawn.
	# It only stops a second death (co-op: both players down) from running this twice.
	if _dying:
		return
	_dying = true
	hud.show_big("ABONENT NIEDOSTĘPNY", Color("ff4a3a"), 1.4)
	Engine.time_scale = 0.45
	player.drop_cap()
	var cam: Camera2D = player.camera
	cam.create_tween().tween_property(cam, "zoom", Vector2(2.5, 2.5), 0.45) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.6).timeout  # game time: ~1.3 s in slow motion
	Engine.time_scale = 1.0
	await hud.fade(0.9, 0.6).finished
	await get_tree().create_timer(0.8).timeout
	Game.restore_state()
	load_map(Game.respawn_map, Game.respawn_cell)
	cam.zoom = Vector2.ONE
	player.respawn()
	if is_instance_valid(player2):
		player2.respawn()
	hud.fade(0.0, 0.6)
	_dying = false


## Braun's jet: needs silence (all antennas off) and Mama on board.
func try_board_plane() -> void:
	if Game.disabled_count < Game.ALL_ANTENNAS.size():
		Game.say_line("Johnny", "Awionika martwa, póki anteny nadają.", false, true)
		return
	if not Game.flags.has("mama_met"):
		Game.say_line("Johnny", "Bez mamy nie lecę. Dom jest na górce.", false, true)
		return
	go_to_ending()


func go_to_ending() -> void:
	if _ending:
		return
	_ending = true
	Net.send_ending()
	Sfx.set_static(0.0)
	await hud.fade(1.0, 1.2).finished
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


# --- online co-op (net.gd) ------------------------------------------------------------

## Host: what the client needs every frame-ish: players, mutants, drops, bars.
func net_snapshot() -> Dictionary:
	var ps := []
	for p in [player, player2]:
		ps.append(p.net_snapshot() if is_instance_valid(p) else [])
	var es := []
	for e in get_tree().get_nodes_in_group("enemies"):
		var spr: AnimatedSprite2D = null
		for c in e.get_children():
			if c is AnimatedSprite2D:
				spr = c
				break
		if spr == null:
			continue
		es.append([Net.net_id(e), e.global_position, spr.position, spr.animation, spr.flip_h,
			spr.rotation, spr.scale, spr.modulate, bool(e.get("burnt"))])
	var ds := []
	if level:
		for n in level.entities.get_children():
			if n is Area2D and "kind" in n and not n.has_meta("key"):
				ds.append([Net.net_id(n), n.kind, n.global_position])
	var boats := []  # the boat moves during the crossing
	for bt in get_tree().get_nodes_in_group("boats"):
		boats.append([str(bt.get_meta("key", "")), bt.global_position])
	return {"r": Net.map_rev, "p": ps, "e": es, "d": ds, "m": boats, "b": Game.bars, "l": Game.dialog_lock}


## Client: main.tscn just opened with the host's first state.
func _client_start() -> void:
	player.make_puppet()
	if is_instance_valid(player2):
		player2.make_puppet()
	var st: Dictionary = Net.pending_state
	Net.pending_state = {}
	client_apply_state(st)
	Net.flush_pending_dialog(hud.dialog)
	hud.show_hint("Grasz jako P2. Host prowadzi grę i zapisuje.")


## Client: the map is built like on the host, minus what the host simulates.
func _client_map_built() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_puppets.clear()
	_drops.clear()
	if Game.current_map == "world" and Game.flags.has("plane_down"):
		_spawn_wreck(false)


func client_apply_state(st: Dictionary) -> void:
	if st.is_empty():
		return
	var old_gone := Game.gone.duplicate()
	var old_off := Game.disabled_ids.duplicate()
	Game.apply_net_state(st)
	var rev := int(st.get("rev", 0))
	if rev != _net_rev:
		_net_rev = rev
		load_map(str(st.get("map", "home")))
		return
	if level == null:
		return
	# world changes since the last state: taken pickups, cut thickets, silent antennas, the jet
	for n in level.entities.get_children():
		var k: String = str(n.get_meta("key", ""))
		if k != "" and Game.gone.has(k) and not old_gone.has(k) and not n.is_in_group("player"):
			var tw: Tween = n.create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 0.3)
			tw.tween_callback(n.queue_free)
	for a in Game.antennas:
		if is_instance_valid(a) and Game.disabled_ids.has(a.antenna_id) and not old_off.has(a.antenna_id):
			a._set_off()
			Sfx.play("shutdown")
			create_tween().tween_property(darkness, "color", level.darkness.lerp(BRIGHT_AFTER, _brightness()), 3.0)
	if Game.flags.has("plane_down") and Game.current_map == "world" and level.entities.get_node_or_null("Wreck") == null:
		_spawn_wreck(false)  # missed the fall (joined late): just the wreck


## Client: the host's jet is falling right now.
func client_wreck_fall() -> void:
	if Game.current_map != "world" or level == null:
		return
	var old: Node = level.entities.get_node_or_null("Wreck")
	if old != null:
		old.free()
	_spawn_wreck(true)


func client_apply_snap(s: Dictionary) -> void:
	if level == null or int(s.get("r", -1)) != _net_rev:
		return  # snapshot from a map we haven't built yet
	var ps: Array = s.get("p", [])
	if ps.size() > 0 and not ps[0].is_empty():
		player.net_apply(ps[0])
	if ps.size() > 1 and not ps[1].is_empty() and is_instance_valid(player2):
		player2.net_apply(ps[1])
	var seen := {}
	for e in s.get("e", []):
		var id: String = e[0]
		seen[id] = true
		var pup: Node2D = _puppets.get(id)
		if not is_instance_valid(pup):
			pup = NET_PUPPET.new()
			pup.burnt = e[8]
			pup.position = e[1]
			level.entities.add_child(pup)
			_puppets[id] = pup
		pup.net_apply(e)
	for id in _puppets.keys():
		if not seen.has(id):
			var gone_pup: Node2D = _puppets[id]
			_puppets.erase(id)
			if is_instance_valid(gone_pup):
				gone_pup.net_die()
	seen.clear()
	for d in s.get("d", []):
		var did: String = d[0]
		seen[did] = true
		if not is_instance_valid(_drops.get(did)):
			var pk: Node2D = PICKUP_SCN.instantiate()
			pk.kind = d[1]
			pk.position = d[2]
			level.entities.add_child(pk)
			_drops[did] = pk
	for did in _drops.keys():
		if not seen.has(did):
			if is_instance_valid(_drops[did]):
				_drops[did].queue_free()
			_drops.erase(did)
	for bm in s.get("m", []):
		for bt in get_tree().get_nodes_in_group("boats"):
			if str(bt.get_meta("key", "")) == bm[0]:
				bt.global_position = bt.global_position.lerp(bm[1], 0.5) 					if bt.global_position.distance_to(bm[1]) < 64.0 else bm[1]
	var b := int(s.get("b", 0))
	if b != Game.bars:
		Game.bars = b
		Game.bars_changed.emit(b)
	Game.dialog_lock = bool(s.get("l", false))


## Client: a host shot, only to look at (the host's bullet does the damage).
func client_spawn_shot(pos: Vector2, dir: Vector2) -> void:
	if level == null:
		return
	var b := BULLET_SCN.instantiate()
	b.visual = true
	b.direction = dir
	b.global_position = pos
	level.entities.add_child(b)
	Sfx.play("shoot")
