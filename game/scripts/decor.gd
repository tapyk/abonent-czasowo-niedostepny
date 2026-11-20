extends StaticBody2D
## Solid set dressing: car wrecks.

var kind := "car"


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var s := Sprite2D.new()
	s.texture = PropArt.decor(kind)
	s.position = Vector2(0, -s.texture.get_height() / 2.0 + 2)
	add_child(s)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(s.texture.get_width() - 4, minf(12.0, s.texture.get_height() * 0.6))
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)
