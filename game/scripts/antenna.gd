extends Node2D
## LTE antenna: a signal source with a red beacon visible from afar.

@export var antenna_id := "a1"
@export var hackable := false
@export var minigame := "maze"
@export var need := "cable"

const ENEMY_SCN := preload("res://scenes/enemy.tscn")
## Co-op: mutants come at the signal while someone hacks.
const WAVES := {
	"normal": {"first": 4.0, "every": 9.0, "per": 1, "alive": 3, "waves": 4, "burnt": 0.15},
	"hard": {"first": 4.0, "every": 8.0, "per": 2, "alive": 4, "waves": 5, "burnt": 0.25},
}

var disabled := false
var maze_seed := 1
var _blink := 0.0
var _wave_t := 4.0
var _wave_count := 0
var _wave_enemies: Array[Node] = []

@onready var mast: Sprite2D = $Mast
@onready var panel: Sprite2D = $Panel
@onready var beacon: Sprite2D = $Beacon
@onready var beacon_light: PointLight2D = $BeaconLight
@onready var panel_light: PointLight2D = $PanelLight


func _ready() -> void:
	disabled = Game.is_antenna_off(antenna_id)
	add_to_group("antennas")
	Game.register_antenna(self)
	maze_seed = 1000 + hash(antenna_id) % 1000
	var mt := PropArt.antenna_mast()
	mast.texture = mt
	mast.position = Vector2(-mt.get_width() / 2.0, -mt.get_height())
	beacon.texture = Art.box(Vector2i(3, 3), Color("ff2a2a"))
	beacon.material = Art.unshaded()
	beacon.position = Vector2(0, -mt.get_height() + 2)
	beacon_light.position = beacon.position
	beacon_light.texture = Art.light_radial(128)
	panel.visible = hackable
	panel_light.visible = hackable
	if hackable:
		add_to_group("interactable")
		panel.texture = PropArt.antenna_panel()
		panel.position = Vector2(12, -panel.texture.get_height() / 2.0)
		panel_light.position = panel.position
		panel_light.texture = Art.light_radial(64)
	if disabled:
		_set_off()


func _process(delta: float) -> void:
	if disabled:
		return
	_blink += delta
	var on := fmod(_blink, 1.2) < 0.7
	beacon.visible = on
	beacon_light.energy = 1.3 if on else 0.35
	if Game.coop and hackable and not Net.is_client() and _is_being_hacked():
		_tick_coop_waves(delta)


func _is_being_hacked() -> bool:
	if Net.remote_hack_antenna == antenna_id:
		return true  # online Player 2 has this panel open on their screen
	for ui in get_tree().get_nodes_in_group("hack_ui"):
		if ui.visible and "antenna" in ui and ui.antenna == self:
			return true
	return false


func _waves() -> Dictionary:
	return WAVES["hard" if Game.is_hard() else "normal"]


func _tick_coop_waves(delta: float) -> void:
	var w := _waves()
	if _wave_count >= int(w.waves):
		return
	_wave_enemies = _wave_enemies.filter(func(e): return is_instance_valid(e) and e.is_in_group("enemies"))
	if _wave_enemies.size() >= int(w.alive):
		return
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	_wave_t = float(w.every)
	_wave_count += 1
	spawn_defense_wave(int(w.per))
	if _wave_count == 1:
		Game.show_hint("Mutanci idą na sygnał! Osłaniaj hakującego!")
	elif _wave_count == int(w.waves):
		Game.show_hint("Ostatnia fala. Wytrzymaj!")


func spawn_defense_wave(count: int) -> int:
	var ents := get_parent()
	if ents == null:
		return 0
	var lvl := ents.get_parent()
	if lvl == null or not lvl.has_method("nearest_walkable"):
		return 0
	var my_cell: Vector2i = get_meta("cell", lvl.to_cell(global_position))
	# a few tiles out, so the guard sees them coming
	var offsets := [Vector2i(-7, 0), Vector2i(7, 0), Vector2i(0, 6), Vector2i(-6, 4), Vector2i(6, 4), Vector2i(0, -6)]
	var spawned := 0
	for i in count:
		var off: Vector2i = offsets[(_wave_count * 2 + i) % offsets.size()]
		var sc: Vector2i = lvl.nearest_walkable(my_cell + off)
		if sc.x < 0:
			continue
		var e: CharacterBody2D = ENEMY_SCN.instantiate()
		e.burnt = randf() < float(_waves().burnt)
		e.position = lvl.feet(sc.x, sc.y)
		ents.add_child(e)
		e.alert.call_deferred()
		_wave_enemies.append(e)
		spawned += 1
	return spawned


## Interaction point is the panel, not the mast base.
func get_interact_position() -> Vector2:
	return panel.global_position


func can_interact() -> bool:
	return hackable and not disabled


func prompt() -> String:
	return "[E] Hakuj panel anteny" if Game.has(need) else "[E] Panel anteny (brak kabla)"


func interact(player: Node) -> void:
	if not Game.has(need):
		if need == "cable":
			Game.say_line("Johnny", "Bez kabla się nie podłączę. Technik obok coś miał.", false, true)
		else:
			Game.say_line("Johnny", "Inne złącze. Potrzebuję kabli od Fasti Farmera.", false, true)
		return
	if Net.is_host() and player == Game.player2:
		Net.open_remote_hack(antenna_id)  # online Player 2 hacks on their own screen
		return
	get_tree().call_group("hack_ui", "open", self, player)


func on_hacked() -> void:
	if Net.is_client():
		Net.send_hacked(antenna_id)  # the host switches it off and the state comes back
		return
	_set_off()
	Sfx.play("shutdown")
	var c: Vector2i = get_meta("cell", Vector2i.ZERO)
	Game.notify_antenna_disabled(self, c + Vector2i(1, 2))


func _set_off() -> void:
	disabled = true
	beacon.visible = false
	beacon_light.enabled = false
	panel_light.color = Color(1, 0.3, 0.2)
	panel_light.energy = 0.2
