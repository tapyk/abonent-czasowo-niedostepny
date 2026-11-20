extends Node2D
## Non-interactive set dressing: car wrecks and broken street lamps.

var kind := "car"
var _light: PointLight2D
var _t := 0.0


func _ready() -> void:
	z_index = -1
	var s := Sprite2D.new()
	s.texture = PropArt.decor(kind)
	s.position = Vector2(0, -s.texture.get_height() / 2.0)
	add_child(s)
	if kind == "lamp":
		_light = PointLight2D.new()
		_light.texture = Art.light_radial(96)
		_light.color = Color(1.0, 0.75, 0.45)
		_light.energy = 0.5
		_light.position = Vector2(0, -s.texture.get_height() + 4)
		add_child(_light)
		_t = randf() * 10.0


func _process(delta: float) -> void:
	if _light:
		_t += delta
		# Dying lamp: mostly on, sometimes flickers.
		_light.energy = 0.0 if fmod(_t * 7.3, 11.0) < 0.6 or randf() < 0.02 else 0.5
