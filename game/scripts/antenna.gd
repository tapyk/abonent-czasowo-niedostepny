extends Node2D
## LTE antenna on a rooftop: red beacon visible from afar, hackable panel at the base.

var disabled := false
var maze_seed := 1
var _blink := 0.0

@onready var mast: Sprite2D = $Mast
@onready var panel: Sprite2D = $Panel
@onready var beacon: Sprite2D = $Beacon
@onready var beacon_light: PointLight2D = $BeaconLight
@onready var panel_light: PointLight2D = $PanelLight


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("antennas")
	Game.register_antenna(self)
	maze_seed = 1000 + Game.antennas.size()
	var mt := PropArt.antenna_mast()
	mast.texture = mt
	mast.position = Vector2(4, -mt.get_height())
	panel.texture = PropArt.antenna_panel()
	panel.position = Vector2(-4, -panel.texture.get_height() / 2.0)
	beacon.texture = Art.box(Vector2i(3, 3), Color("ff2a2a"))
	beacon.material = Art.unshaded()
	beacon.position = mast.position + Vector2(mt.get_width() / 2.0, 1)
	beacon_light.position = beacon.position
	beacon_light.texture = Art.light_radial(128)
	panel_light.position = panel.position
	panel_light.texture = Art.light_radial(64)


func _process(delta: float) -> void:
	if disabled:
		return
	_blink += delta
	var on := fmod(_blink, 1.2) < 0.7
	beacon.visible = on
	beacon_light.energy = 1.3 if on else 0.35


func can_interact() -> bool:
	return not disabled


func prompt() -> String:
	return "[E] Hakuj panel anteny" if Game.has_cable else "[E] Panel anteny (brak kabla)"


func interact(player: Node) -> void:
	if not Game.has_cable:
		Game.say_line("Johnny", "Bez kabla się nie podłączę. Technik na dachu coś miał.")
		return
	get_tree().call_group("hack_ui", "open", self, player)


func on_hacked() -> void:
	disabled = true
	beacon.visible = false
	beacon_light.enabled = false
	panel_light.color = Color(1, 0.3, 0.2)
	panel_light.energy = 0.2
	Sfx.play("shutdown")
	Game.notify_antenna_disabled(self)
