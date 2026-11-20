extends StaticBody2D
## Thick thicket: blocks the path until Johnny has garden shears (Cut-style gate).

var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("thickets")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = PropArt.thicket()
	add_child(_sprite)


func can_interact() -> bool:
	return true


func prompt() -> String:
	return "[E] Przetnij gąszcz" if Game.has_sekator else "Gęste krzaki"


func interact(_player: Node) -> void:
	if not Game.has_sekator:
		Game.say_line("Johnny", "Za gęsto. Potrzebny sekator.", false, true)
		return
	Sfx.play("melee")
	# Cut the whole clump (neighbouring thicket tiles) at once.
	for t in get_tree().get_nodes_in_group("thickets"):
		if t != self and t.global_position.distance_to(global_position) < 40.0:
			t.cut()
	cut()


func cut() -> void:
	if not is_in_group("thickets"):
		return
	remove_from_group("thickets")
	Game.mark_gone(get_meta("key", ""))
	remove_from_group("interactable")
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.3, 0.2), 0.2)
	tw.tween_callback(queue_free)
