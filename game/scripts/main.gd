extends Node2D
## Game scene: builds the level, wires player/HUD, runs the story beats of the MVP: flat.

const DARK := Color(0.30, 0.30, 0.40)
const DARK_AFTER := Color(0.46, 0.46, 0.56)

@onready var level: Node2D = $Level
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var darkness: CanvasModulate = $Darkness

var _ending := false


func _ready() -> void:
	add_to_group("story")
	Game.new_game()
	level.build()
	player.global_position = level.player_start
	Game.player = player
	Game.respawn_point = level.player_start
	var b: Rect2 = level.bounds()
	var cam: Camera2D = player.camera
	cam.limit_left = int(b.position.x)
	cam.limit_top = int(b.position.y) - 40
	cam.limit_right = int(b.end.x)
	cam.limit_bottom = int(b.end.y) - 16
	cam.reset_smoothing()
	darkness.color = DARK
	player.died.connect(_on_player_died)
	player.hp_changed.connect(hud.tablet.set_hp)
	Game.antenna_disabled.connect(_on_antenna_disabled)
	hud.set_objective("Wyjdź z bloku.")
	_intro()
	DevTools.attach(self)


func _intro() -> void:
	Game.say_line("Tablet", "Abonent czasowo niedostępny. Prosimy spróbować później.")
	Game.say_line("Johnny", "Później. Jasne.")
	Game.say_line("Johnny", "Tata zawsze mówił, że pistolet kiedyś się przyda. Wolałbym, żeby nie miał racji.")
	Game.say_line("Mama", "Johnny… nie dzwoń… oni idą za sygnałem… wyłącz… anteny… dach naprzeciwko…", true)


func on_trigger(id: String) -> void:
	match id:
		"2":
			Game.say_line("Johnny", "Blok naprzeciwko. Czerwone światło na dachu. Tam.")
			hud.set_objective("Wejdź na dach bloku naprzeciwko (czerwone światło).")
		"1":
			if Game.has_cable:
				hud.set_objective("Zhakuj panel anteny [E].")
			else:
				Game.say_line("Mama", "Panel jest u podstawy masztu. Bez kabla serwisowego się nie podłączysz.", true)
				hud.set_objective("Znajdź kabel serwisowy (technik na dachu).")
		"3":
			if Game.disabled_count > 0:
				Game.say_line("Johnny", "Lotnisko. I samolot. Może jednak ktoś stąd odleci.")
			else:
				Game.say_line("Johnny", "Lotnisko. Wszystko stoi. Sygnał zagłusza awionikę.")


func _process(_delta: float) -> void:
	if Game.has_cable and not Game.flags.has("cable_obj"):
		Game.flags["cable_obj"] = true
		hud.set_objective("Zhakuj panel anteny [E]. Mutanci nie poczekają.")


func _on_antenna_disabled(_a: Node) -> void:
	create_tween().tween_property(darkness, "color", DARK_AFTER, 3.0)
	hud.show_big("CISZA", Color("8fe0a0"), 1.2)
	Game.say_line("Mama", "Johnny? Słyszę cię wyraźniej! Antena padła.", true)
	Game.say_line("Mama", "Na wschodzie jest małe lotnisko. Bez sygnału samolot może wystartować. Idź tam.", true)
	Game.say_line("Johnny", "Już idę.")
	hud.set_objective("Idź na wschód, do samolotu na lotnisku.")


func _on_player_died() -> void:
	hud.show_big("ABONENT NIEDOSTĘPNY", Color("ff4a3a"), 1.4)
	hud.fade(0.85, 0.8)
	await get_tree().create_timer(2.4).timeout
	Game.ammo = maxi(Game.ammo, 5)
	Game.stats_changed.emit()
	player.respawn(Game.respawn_point)
	hud.fade(0.0, 0.6)


func go_to_ending() -> void:
	if _ending:
		return
	_ending = true
	Sfx.set_static(0.0)
	await hud.fade(1.0, 1.2).finished
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
