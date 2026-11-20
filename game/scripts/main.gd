extends Node2D
## Game scene: loads maps.

const LEVEL := preload("res://scripts/level.gd")
const BRIGHT_AFTER := Color(0.5, 0.5, 0.6)

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
	player.hp_changed.connect(hud.tablet.set_hp)
	Game.antenna_disabled.connect(_on_antenna_disabled)
	add_child(preload("res://scripts/pause_menu.gd").new())
	var start: String = str(Game.dev.get("map", "home"))
	load_map(start)
	_intro()
	DevTools.attach(self)


func _intro() -> void:
	Game.say_line("Tablet", "Abonent czasowo niedostępny. Prosimy spróbować później.")
	Game.say_line("Johnny", "Później. Jasne.")
	Game.say_line("Mama", "Johnny… nie dzwoń… oni idą za sygnałem… wyłącz… anteny… blok naprzeciwko…", true)


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
	var dark: Color = level.darkness
	if Game.disabled_count > 0 and map_name != "home":
		dark = dark.lerp(BRIGHT_AFTER, 0.6)
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


func _on_enter_map(map_name: String) -> void:
	if map_name == "world" and not Game.flags.has("world_seen"):
		Game.flags["world_seen"] = true
		Game.say_line("Johnny", "Blok naprzeciwko. Czerwone światło na dachu. Tam.")


func objective() -> String:
	if not Game.has_pistol:
		return "Weź pistolet taty ze stołu."
	if Game.disabled_count == 0:
		if Game.current_map == "home":
			return "Zejdź schodami na osiedle."
		if Game.current_map == "roof":
			return "Zhakuj panel anteny [E]." if Game.has_cable else "Znajdź kabel (technik na dachu)."
		if not Game.has_sekator:
			return "Znajdź sekator. Może w garażach?" if Game.flags.has("thicket_seen") \
				else "Blok naprzeciwko: czerwone światło."
		return "Przetnij gąszcz, wejdź do bloku."
	return "Droga na wschód wolna. Lotnisko!"


func _process(_delta: float) -> void:
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
			if Game.disabled_count == 0:
				Game.say_line("Johnny", "Horda na drodze. Stoją i nasłuchują sygnału. Nie przebiję się.")
		"barn":
			Game.say_line("???", "Stój! Masz telefon? Włączony?!")
			Game.say_line("Johnny", "…Już nie. Wrócę później.")
		"airfield":
			Game.say_line("Johnny", "Lotnisko. I samolot. Może jednak ktoś stąd odleci.")
		"roof":
			if not Game.has_cable:
				Game.say_line("Mama", "Panel jest przy maszcie. Bez kabla serwisowego się nie podłączysz.", true)


func _on_antenna_disabled(_a: Node) -> void:
	create_tween().tween_property(darkness, "color", darkness.color.lerp(BRIGHT_AFTER, 0.6), 3.0)
	hud.show_big("CISZA", Color("8fe0a0"), 1.2)
	Game.say_line("Mama", "Johnny? Słyszę cię wyraźniej! Antena padła.", true)
	Game.say_line("Mama", "Horda z drogi na wschód się rozchodzi. Za polami jest lotnisko. Bez sygnału samolot wystartuje.", true)
	Game.say_line("Johnny", "Już idę.")


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


func go_to_ending() -> void:
	if _ending:
		return
	_ending = true
	Sfx.set_static(0.0)
	await hud.fade(1.0, 1.2).finished
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
