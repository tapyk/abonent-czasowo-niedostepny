extends Node2D
## LTE antenna: a signal source with a red beacon visible from afar.

@export var antenna_id := "a1"
@export var hackable := false
@export var minigame := "maze"
@export var need := "cable"

var disabled := false
var maze_seed := 1
var _blink := 0.0

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
	get_tree().call_group("hack_ui", "open", self, player)


func on_hacked() -> void:
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
