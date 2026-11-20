extends Node2D
## Game scene: loads maps.

const LEVEL := preload("res://scripts/level.gd")
const BRIGHT_AFTER := Color(0.5, 0.5, 0.6)
const INTERIORS := ["home", "stodola", "mama_dom"]
const PARTS_NEEDED := 3

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var darkness: CanvasModulate = $Darkness

var level: Node2D
var _busy := false
var _ending := false
var _objective := ""


func _ready() -> void:
	add_to_group("story")
	Game.new_game()
	Game.player = player  # new_game() runs after the player registered itself
	player.died.connect(_on_player_died)
	player.hp_changed.connect(hud.set_hp)
	Game.antenna_disabled.connect(_on_antenna_disabled)
	add_child(preload("res://scripts/pause_menu.gd").new())
	if not Game.dev.has("autotest"):
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # HUD draws a crosshair instead
	var start: String = str(Game.dev.get("map", "home"))
	load_map(start)
	_intro()
	DevTools.attach(self)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _intro() -> void:
	Game.say_line("Tablet", "Abonent czasowo niedostępny. Prosimy spróbować później.")
	Game.say_line("Johnny", "Później. Jasne.")
	Game.say_line("Mama", "Johnny… nie dzwoń… oni idą za sygnałem… wyłącz… anteny… jestem w domu… za jeziorem…", true)
	Game.say_line("Mama", "…zacznij od… bloku naprzeciwko…", true)


func _brightness() -> float:
	return clampf(0.3 * Game.disabled_count, 0.0, 0.85)


## Builds `map_name` and puts Johnny on `cell` (or the map's P marker).
func load_map(map_name: String, cell := Vector2i(-1, -1)) -> void:
	if level:
		player.reparent(self)
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
	if level.header.has("checkpoint") and cell.x >= 0:
		Game.set_checkpoint(map_name, c)
	var dark: Color = level.darkness
	if not map_name in INTERIORS:
		dark = dark.lerp(BRIGHT_AFTER, _brightness())
	darkness.color = dark
	_fit_camera(level.bounds())
	player.camera.reset_smoothing()
	_on_enter_map(map_name)


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
	await hud.fade(1.0, 0.25).finished
	load_map(map_name, cell)
	await hud.fade(0.0, 0.25).finished
	player.frozen = false
	_busy = false


## Say these lines only the first time `flag` comes up.
func _once(flag: String, lines: Array) -> void:
	if Game.flags.has(flag):
		return
	Game.flags[flag] = true
	for l in lines:
		Game.say_line(l[0], l[1], l.size() > 2)


func _on_enter_map(map_name: String) -> void:
	match map_name:
		"world":
			_once("world_seen", [["Johnny", "Blok naprzeciwko. Czerwone światło na dachu. Tam."]])
		"stodola":
			_once("stodola_seen", [["Johnny", "Ściany obite folią aluminiową. Zero kresek. Klatka Faradaya serio działa."]])
		"szczelina":
			_once("szczelina_seen", [["Johnny", "Szczelina. Ziemia pękła po wybuchu CURNu."],
				["Mama", "Nad szczeliną… jest tyrolka. Uważaj… coś na niej wisi…", true]])
		"trybunal":
			_once("trybunal_seen", [["Johnny", "Trybunał CURN. Ogród pełen mutantów, a na środku placu… facet w garniturze."]])
		"mama":
			_once("mama_shore_seen", [["Johnny", "Brzeg. Dom mamy jest na górce. I… odrzutowiec na pasie?"]])


func objective() -> String:
	var m := Game.current_map
	if not Game.has_pistol:
		return "Weź pistolet taty ze stołu."
	if not Game.is_antenna_off("a1"):
		if m == "home":
			return "Zejdź schodami na osiedle."
		if m == "roof":
			return "Zhakuj panel anteny [E]." if Game.has_cable else "Znajdź kabel (technik na dachu)."
		if not Game.has_sekator:
			return "Znajdź sekator. Może w garażach?" if Game.flags.has("thicket_seen") \
				else "Blok naprzeciwko: czerwone światło."
		return "Przetnij gąszcz, wejdź do bloku."
	if not Game.has_kable:
		if not Game.flags.has("farmer_met"):
			return "Na wschód: stodoła Fast Farmera na polach."
		if Game.parts >= PARTS_NEEDED:
			return "Zanieś części Fast Farmerowi."
		return "Części od spalonych: %d/%d." % [Game.parts, PARTS_NEEDED]
	if not Game.is_antenna_off("a2"):
		return "Plantacja na wschodzie: zhakuj antenę 2."
	if m in ["world", "stodola", "roof", "home"]:
		return "Droga na wschód wolna. Do szczeliny."
	if m == "szczelina":
		return "Przejedź tyrolką na drugą stronę [E]." if not Game.flags.has("zip_across") \
			else "Na wschód, do Trybunału CURN."
	if not Game.flags.has("braun_met"):
		return "Trybunał CURN: porozmawiaj z Braunem."
	var left := _mutants_left()
	if not Game.flags.has("trybunal_clear"):
		return "Oczyść Trybunał z mutantów (%d)." % left if left >= 0 else "Oczyść Trybunał z mutantów."
	if not Game.is_antenna_off("a3"):
		return "Zhakuj antenę 3 w ogrodzie Trybunału."
	if not Game.flags.has("braun_done"):
		return "Wróć do Brauna."
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
	if Game.current_map == "trybunal" and not Game.flags.has("trybunal_clear") and _mutants_left() == 0 and not _busy:
		Game.flags["trybunal_clear"] = true
		hud.show_big("TRYBUNAŁ CZYSTY", Color("8fe0a0"), 1.0)
		if Game.flags.has("braun_met"):
			Game.say_line("Johnny", "Ostatni. Ogród Trybunału czysty.")
			if not Game.is_antenna_off("a3"):
				Game.say_line("Johnny", "Została antena w ogrodzie.")
			else:
				Game.say_line("Johnny", "Wracam do Brauna.")
	var o := objective()
	if o != _objective:
		_objective = o
		hud.set_objective(o)


func on_trigger(id: String) -> void:
	match id:
		"thicket":
			Game.flags["thicket_seen"] = true
			if not Game.has_sekator:
				Game.say_line("Johnny", "Chaszcze zarosły całe przejście. Bez sekatora nie przejdę.")
		"horde":
			if not Game.is_antenna_off("a1"):
				Game.say_line("Johnny", "Horda na drodze. Stoją i nasłuchują sygnału. Nie przebiję się.")
		"barn":
			if not Game.flags.has("farmer_met"):
				_once("barn_seen", [["???", "Stój! Masz telefon? Włączony?!"],
					["Johnny", "Głos ze stodoły. Owiniętej folią aluminiową."]])
		"plantation":
			_once("plantation_seen", [["Johnny", "Palmy? Tutaj? Ktoś się bawił w Cayo Perico."],
				["Mama", "Druga antena… stoi między palmami… pilnują jej spaleni…", true]])
		"crevice":
			pass
		"zip_boss":
			Game.say_line("Johnny", "Coś jedzie z drugiej strony liny!")
			_once("zip_boss_seen", [["Mama", "Tyrolkowy… [szum]… strzelaj, zanim cię zrzuci!", true]])
		"zip_boss_dead":
			hud.show_big("TYROLKOWY MUTANT POKONANY", Color("ffb060"), 1.0)
			Game.say_line("Johnny", "Leć. Daleko leć.")
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


func _talk_farmer() -> void:
	if not Game.flags.has("farmer_met"):
		Game.flags["farmer_met"] = true
		Game.say_line("Farmer", "Stój! Masz telefon? Włączony?")
		Game.say_line("Johnny", "…Już nie.")
		Game.say_line("Farmer", "Dwadzieścia lat im mówiłem, że ta sieć nas kiedyś zje. Śmiali się. No i kto się teraz śmieje?")
		Game.say_line("Johnny", "Na pewno nie oni.")
		Game.say_line("Farmer", "Kable do następnych anten ci dam. Ale przynieś mi trzy części od spalonych.")
		Game.say_line("Farmer", "I nie przyprowadzaj mi ich razem z właścicielami.")
		if Game.parts < PARTS_NEEDED:
			return
	if Game.has_kable:
		Game.say_line("Farmer", "Kable masz. Antena stoi na plantacji za polami. Kiedyś palmy, ochrona, helikoptery. Jak na Cayo Perico.")
		Game.say_line("Farmer", "Teraz tylko spaleni. I niech ci się nie wydaje, że cię nie słyszą.")
		return
	if Game.parts >= PARTS_NEEDED:
		Game.take_parts(PARTS_NEEDED)
		Game.has_kable = true
		Game.stats_changed.emit()
		Sfx.play("pickup")
		hud.show_big("KABLE OD FARMERA", Color("8fe0a0"), 0.8)
		Game.say_line("Farmer", "Trzy. Dobrze. Masz tu kable. Pasują do anten na plantacji i w Trybunale.")
		Game.say_line("Farmer", "Plantacja jest za polami, na wschodzie. Ktoś tam sobie zrobił Cayo Perico. Palmy, plantacja, wszystko.")
		Game.say_line("Johnny", "A teraz?")
		Game.say_line("Farmer", "Teraz rośnie tam tylko sygnał.")
	else:
		Game.say_line("Farmer", "Trzy części od spalonych. Masz %d. Spaleni świecą w ciemności, nie przegapisz." % Game.parts)


func _talk_braun() -> void:
	if Game.current_map == "mama":
		if not Game.flags.has("mama_met"):
			Game.say_line("Braun", "Silniki grzeją się. Proszę najpierw zabrać matkę, panie Walker.")
		else:
			Game.say_line("Braun", "Proszę wsiadać. Lot do Irlandii, bez międzylądowań.")
		return
	if not Game.flags.has("braun_met"):
		Game.flags["braun_met"] = true
		Game.say_line("Braun", "Kto pana upoważnił do przebywania na terenie Trybunału?")
		Game.say_line("Johnny", "Pana ogród jest pełen mutantów.")
		Game.say_line("Braun", "Zauważyłem. Dlatego stoję tu, a nie tam.")
		Game.say_line("Braun", "Proponuję umowę. Pan oczyści Trybunał z mutantów i wyłączy antenę w ogrodzie.")
		Game.say_line("Braun", "Ja mam łódkę na przystani i odrzutowiec po drugiej stronie jeziora. Jest w nim miejsce.")
		Game.say_line("Johnny", "Dom mamy jest po drugiej stronie jeziora.")
		Game.say_line("Braun", "W takim razie mamy wspólny interes. Proszę zaczynać.")
		return
	if Game.flags.has("braun_done"):
		Game.say_line("Braun", "Łódka na przystani. Spotkamy się przy odrzutowcu. Ja dopłynę pontonem.")
		return
	if _trybunal_done():
		Game.flags["braun_done"] = true
		Sfx.play("pickup")
		Game.say_line("Braun", "Cisza. Pierwszy raz od tygodnia. Proszę, kluczyk do łodzi.")
		Game.say_line("Braun", "Odrzutowiec stoi na pasie przy domu pańskiej matki. Ja dopłynę pontonem, mam jeszcze dokumenty do podpisania.")
		Game.say_line("Johnny", "Komu?")
		Game.say_line("Braun", "Sobie. Ktoś musi.")
		return
	var left := _mutants_left()
	if not Game.flags.has("trybunal_clear"):
		Game.say_line("Braun", "Wciąż słyszę ich w ogrodzie. Zostało jeszcze %d." % left if left > 0 else "Wciąż słyszę ich w ogrodzie.")
	else:
		Game.say_line("Braun", "Mutanci załatwieni, ale antena w ogrodzie dalej nadaje. Proszę ją wyłączyć.")


func _talk_mama() -> void:
	if Game.flags.has("mama_met"):
		Game.say_line("Mama", "Braun czeka przy odrzutowcu. Chodź, zanim ktoś znowu włączy zasięg.")
		return
	Game.flags["mama_met"] = true
	hud.show_big("MAMA", Color("ffe08a"), 0.8)
	Game.say_line("Johnny", "Cześć, mamo. Abonent już dostępny?")
	Game.say_line("Mama", "Potem się przytulimy.")
	Game.say_line("Mama", "Słyszałam przez radio, że Braun ma odrzutowiec. Stoi na pasie za domem.")
	Game.say_line("Johnny", "Wiem. Mamy wspólny interes.")


# --- boat -------------------------------------------------------------------------

func board_boat(boat: Node2D, _p: Node) -> void:
	if _busy:
		return
	if Game.current_map == "trybunal" and not Game.flags.has("braun_done"):
		if not Game.flags.has("braun_met"):
			Game.say_line("Johnny", "Łódka na kłódkę. Ciekawe, kto ma kluczyk.")
		else:
			Game.say_line("Johnny", "Łódka Brauna. Kluczyk da mi, jak skończę w Trybunale.")
		return
	_busy = true
	player.frozen = true
	player.riding = true
	Sfx.play("step", 0.1, -4.0)
	var east := 1.0 if Game.current_map == "trybunal" else -1.0
	var from := boat.global_position
	var sail := func(v: Vector2) -> void:
		boat.global_position = v
		player.global_position = v + Vector2(-2, -3)
	var tw := create_tween()
	tw.tween_method(sail, from, from + Vector2(140.0 * east, 24.0), 3.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.8).timeout
	await hud.fade(1.0, 1.0).finished
	tw.kill()
	hud.show_big("Chwilę później…", Color("c8d0d8"), 1.6)
	await get_tree().create_timer(2.6).timeout
	player.riding = false
	load_map(boat.target_map, boat.target_cell)
	await hud.fade(0.0, 0.8).finished
	player.frozen = false
	_busy = false


# --- antennas, death, ending ---------------------------------------------------

func _on_antenna_disabled(a: Node) -> void:
	create_tween().tween_property(darkness, "color", level.darkness.lerp(BRIGHT_AFTER, _brightness()), 3.0)
	hud.show_big("CISZA", Color("8fe0a0"), 1.2)
	match a.antenna_id:
		"a1":
			Game.say_line("Mama", "Johnny? Słyszę cię wyraźniej! Antena padła.", true)
			Game.say_line("Mama", "Horda z drogi na wschód się rozchodzi. Na polach mieszka Fast Farmer. On ma kable do następnych anten.", true)
			Game.say_line("Johnny", "Ten od folii aluminiowej? Już idę.")
		"a2":
			Game.say_line("Mama", "Druga cicho! Druga horda na drodze odchodzi.", true)
			Game.say_line("Mama", "Za drogą jest szczelina, a za nią Trybunał CURN. Tam stoi ostatnia antena.", true)
			Game.say_line("Johnny", "Ostatnia. Brzmi dobrze.")
		"a3":
			Game.say_line("Mama", "Johnny… słyszę cię czysto. Jak przez telefon. Tylko lepiej.", true)
			Game.say_line("Mama", "Jestem w domu, po drugiej stronie jeziora. Czekam.", true)
			if not Game.flags.has("trybunal_clear"):
				Game.say_line("Johnny", "Jeszcze tylko mutanci w Trybunale. Braun nie da łódki za pół roboty.")
			else:
				Game.say_line("Johnny", "Braun ma łódkę. Zaraz będę.")


func _on_player_died() -> void:
	hud.show_big("ABONENT NIEDOSTĘPNY", Color("ff4a3a"), 1.4)
	await hud.fade(0.9, 0.8).finished
	await get_tree().create_timer(1.6).timeout
	if Game.has_pistol:
		Game.ammo = maxi(Game.ammo, 5)
		Game.stats_changed.emit()
	load_map(Game.respawn_map, Game.respawn_cell)
	player.respawn()
	hud.fade(0.0, 0.6)


## Braun's jet: needs silence (all antennas off) and Mama on board.
func try_board_plane() -> void:
	if Game.disabled_count < Game.ALL_ANTENNAS.size():
		Game.say_line("Johnny", "Awionika martwa. Dopóki anteny nadają, nic stąd nie wystartuje.")
		return
	if not Game.flags.has("mama_met"):
		Game.say_line("Johnny", "Bez mamy nigdzie nie lecę. Dom jest na górce.")
		return
	go_to_ending()


func go_to_ending() -> void:
	if _ending:
		return
	_ending = true
	Sfx.set_static(0.0)
	await hud.fade(1.0, 1.2).finished
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
